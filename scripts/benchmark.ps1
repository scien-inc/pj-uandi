param(
    [string[]]$Profile = @(),
    [string]$PromptFile = "",
    [string]$MailFile = "",
    [int]$NumCtx = 0,
    [int]$NumPredict = 512,
    [double]$Temperature = 0.2,
    [int]$Runs = 1,
    [int]$TimeoutSec = 1800,
    [switch]$Pull,
    [switch]$SkipWarmup,
    [switch]$KeepLoaded,
    [switch]$SaveResponse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\OllamaConfig.ps1"

function Get-Metric {
    param(
        [object]$Response,
        [string]$Name
    )

    $property = $Response.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return [double]0
    }

    return [double]$property.Value
}

Assert-OllamaCommand | Out-Null
$baseConfig = Get-OllamaModelConfig -Profile ""
Assert-OllamaServer -OllamaHost $baseConfig.OllamaHost

$repoRoot = $baseConfig.RepoRoot
if ([string]::IsNullOrWhiteSpace($PromptFile)) {
    $PromptFile = Join-Path $repoRoot "benchmarks\forensic-prompt-ja.txt"
}
if ([string]::IsNullOrWhiteSpace($MailFile)) {
    $MailFile = Join-Path $repoRoot "benchmarks\sample-mail-ja.txt"
}

foreach ($path in @($PromptFile, $MailFile)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path"
    }
}

$instruction = Get-Content -LiteralPath $PromptFile -Raw -Encoding UTF8
$mail = Get-Content -LiteralPath $MailFile -Raw -Encoding UTF8
$basePrompt = "$instruction`n$mail"

$effectiveNumCtx = if ($NumCtx -gt 0) { $NumCtx } elseif ($baseConfig.ContextLength -gt 0) { $baseConfig.ContextLength } else { 49152 }

$profiles = if ($null -eq $Profile -or $Profile.Count -eq 0) { @($baseConfig.Profile) } else { $Profile }

Write-Host "Prompt file: $PromptFile"
Write-Host "Mail file:   $MailFile ($($mail.Length) chars)"
Write-Host "Prompt size: $($basePrompt.Length) chars"
Write-Host "num_ctx:     $effectiveNumCtx"
Write-Host "num_predict: $NumPredict"
Write-Host "Runs:        $Runs per profile"
Write-Host ""

$results = @()

foreach ($profileName in $profiles) {
    $modelConfig = Get-OllamaModelConfig -Profile $profileName
    $generateUri = "$($modelConfig.OllamaHost)/api/generate"

    Write-Host "=== $($modelConfig.Profile) / $($modelConfig.Model) ===" -ForegroundColor Cyan

    if ($Pull) {
        Write-Host "  pulling..."
        # ollama pull writes progress to stderr; relax the preference so that
        # does not surface as a terminating error.
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & ollama pull $modelConfig.Model
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($LASTEXITCODE -ne 0) {
            throw "ollama pull failed for $($modelConfig.Model)."
        }
    }

    # Load the weights with a throwaway prompt so the measured run does not
    # include load_duration. A short prompt is used on purpose: reusing the
    # benchmark prompt would populate the prefix cache and zero out prefill.
    if (-not $SkipWarmup) {
        Write-Host "  warm-up..."
        $warmupBody = @{
            model = $modelConfig.Model
            prompt = "ping"
            stream = $false
            keep_alive = $modelConfig.KeepAlive
            options = @{
                num_ctx = $effectiveNumCtx
                num_predict = 8
                temperature = $Temperature
            }
        }
        Invoke-OllamaJson -Method Post -Uri $generateUri -Body $warmupBody -TimeoutSec $TimeoutSec | Out-Null
    }

    for ($run = 1; $run -le $Runs; $run++) {
        # The run marker sits at the very start so each run re-runs prefill in
        # full instead of hitting Ollama's prefix cache.
        $prompt = "# 計測実行 $run`n$basePrompt"

        Write-Host "  run $run/$Runs ..."
        $body = @{
            model = $modelConfig.Model
            prompt = $prompt
            stream = $false
            keep_alive = $modelConfig.KeepAlive
            options = @{
                num_ctx = $effectiveNumCtx
                num_predict = $NumPredict
                temperature = $Temperature
            }
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-OllamaJson -Method Post -Uri $generateUri -Body $body -TimeoutSec $TimeoutSec
        $stopwatch.Stop()

        $promptTokens = Get-Metric -Response $response -Name "prompt_eval_count"
        $promptNs = Get-Metric -Response $response -Name "prompt_eval_duration"
        $evalTokens = Get-Metric -Response $response -Name "eval_count"
        $evalNs = Get-Metric -Response $response -Name "eval_duration"
        $loadNs = Get-Metric -Response $response -Name "load_duration"
        $totalNs = Get-Metric -Response $response -Name "total_duration"

        $promptRate = $null
        if ($promptNs -gt 0) {
            $promptRate = [math]::Round($promptTokens / ($promptNs / 1e9), 1)
        }

        $evalRate = $null
        if ($evalNs -gt 0) {
            $evalRate = [math]::Round($evalTokens / ($evalNs / 1e9), 1)
        }

        if ($promptTokens -le 0) {
            Write-Warning "    prompt_eval_count is 0. The prefix cache was hit, so the prefill rate is not meaningful."
        }
        if (($promptTokens + $evalTokens) -ge ($effectiveNumCtx - 64)) {
            Write-Warning "    prompt + output ($([int]($promptTokens + $evalTokens)) tokens) nearly fills num_ctx ($effectiveNumCtx). The prompt may have been truncated. Raise -NumCtx."
        }

        $results += [PSCustomObject]@{
            Profile = $modelConfig.Profile
            Run = $run
            PromptTokens = [int]$promptTokens
            PrefillTps = $promptRate
            OutTokens = [int]$evalTokens
            GenTps = $evalRate
            LoadSec = [math]::Round($loadNs / 1e9, 2)
            ServerSec = [math]::Round($totalNs / 1e9, 2)
            WallSec = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        }

        if ($SaveResponse) {
            $resultDirectory = Join-Path $repoRoot "benchmarks\results"
            New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
            $outputPath = Join-Path $resultDirectory "$($modelConfig.Profile)-run$run.txt"
            $responseProperty = $response.PSObject.Properties["response"]
            $responseText = if ($null -ne $responseProperty) { [string]$responseProperty.Value } else { "" }
            $responseText | Out-File -LiteralPath $outputPath -Encoding UTF8
            Write-Host "    response saved: $outputPath"
        }
    }

    if (-not $KeepLoaded) {
        $unloadBody = @{
            model = $modelConfig.Model
            prompt = ""
            keep_alive = 0
            stream = $false
        }
        Invoke-OllamaJson -Method Post -Uri $generateUri -Body $unloadBody -TimeoutSec 120 | Out-Null
        Write-Host "  unloaded."
    }

    Write-Host ""
}

Write-Host "Results (GenTps is the generation speed users feel):" -ForegroundColor Green
$results | Format-Table -AutoSize | Out-Host
