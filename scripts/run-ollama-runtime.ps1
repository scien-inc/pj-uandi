param(
    [string]$Profile = "",
    [string]$KeepAlive = "",
    [int]$StartupTimeoutSeconds = 0,
    [int]$CheckIntervalSeconds = 0,
    [string]$LogDirectory = "",
    [switch]$Pull,
    [switch]$SkipModelLoad,
    [switch]$SkipChatCheck,
    [switch]$Watch
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$runtimeConfig = Get-OllamaRuntimeConfig
$modelConfig = Get-OllamaModelConfig -Profile $Profile

$effectiveStartupTimeoutSeconds = if ($StartupTimeoutSeconds -gt 0) {
    $StartupTimeoutSeconds
}
else {
    $runtimeConfig.StartupTimeoutSeconds
}

$effectiveCheckIntervalSeconds = if ($CheckIntervalSeconds -gt 0) {
    $CheckIntervalSeconds
}
else {
    $runtimeConfig.WatchIntervalSeconds
}

$effectiveLogDirectory = if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
    $runtimeConfig.LogDirectory
}
else {
    $LogDirectory
}

if (-not [System.IO.Path]::IsPathRooted($effectiveLogDirectory)) {
    $effectiveLogDirectory = Join-Path $runtimeConfig.RepoRoot $effectiveLogDirectory
}

$effectiveKeepAlive = if (-not [string]::IsNullOrWhiteSpace($KeepAlive)) {
    $KeepAlive
}
elseif (-not [string]::IsNullOrWhiteSpace($runtimeConfig.KeepAlive)) {
    $runtimeConfig.KeepAlive
}
else {
    $modelConfig.KeepAlive
}

New-Item -ItemType Directory -Force -Path $effectiveLogDirectory | Out-Null

$profileLogName = $modelConfig.Profile -replace "[^A-Za-z0-9._-]", "_"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$modeName = if ($Watch) { "watch" } else { "once" }
$logPath = Join-Path $effectiveLogDirectory "ollama-runtime-$profileLogName-$modeName-$timestamp.log"
$transcriptStarted = $false
$script:PullCompleted = $false

function Invoke-RuntimeCheck {
    Write-Host ""
    Write-Host "Runtime check started: $(Get-Date -Format o)"
    Write-Host "Repo:    $($runtimeConfig.RepoRoot)"
    Write-Host "Profile: $($modelConfig.Profile)"
    Write-Host "Model:   $($modelConfig.Model)"
    Write-Host "Host:    $($modelConfig.OllamaHost)"
    Write-Host "OpenAI:  $($modelConfig.OpenAiBaseUrl)"
    Write-Host "Log:     $logPath"

    Assert-OllamaCommand | Out-Null

    if ($Pull -and -not $script:PullCompleted) {
        Write-Host "Pulling $($modelConfig.Model)..."
        & ollama pull $modelConfig.Model
        if ($LASTEXITCODE -ne 0) {
            throw "ollama pull failed for $($modelConfig.Model)."
        }

        $script:PullCompleted = $true
    }

    $serverStatus = Start-OllamaServerIfNeeded `
        -OllamaHost $modelConfig.OllamaHost `
        -StartupTimeoutSeconds $effectiveStartupTimeoutSeconds
    Write-Host "Ollama server status: $serverStatus"

    if (-not $SkipModelLoad) {
        Write-Host "Loading $($modelConfig.Model) with keep_alive=$effectiveKeepAlive..."
        Invoke-OllamaModelLoad `
            -OllamaHost $modelConfig.OllamaHost `
            -Model $modelConfig.Model `
            -KeepAlive $effectiveKeepAlive | Out-Null
        Write-Host "Model load request completed."
    }
    else {
        Write-Host "Skipping model load."
    }

    Write-Host "Checking OpenAI-compatible models endpoint..."
    Get-OllamaOpenAiModels -OpenAiBaseUrl $modelConfig.OpenAiBaseUrl | Out-Null
    Write-Host "Models endpoint OK."

    if (-not $SkipChatCheck) {
        Write-Host "Checking OpenAI-compatible chat endpoint..."
        Test-OllamaOpenAiChat -OpenAiBaseUrl $modelConfig.OpenAiBaseUrl -Model $modelConfig.Model | Out-Null
        Write-Host "Chat endpoint OK."
    }
    else {
        Write-Host "Skipping chat check."
    }

    Write-Host "Loaded Ollama models:"
    & ollama ps

    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($null -ne $nvidiaSmi) {
        Write-Host "NVIDIA GPU status:"
        & nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv
    }
    else {
        Write-Host "nvidia-smi was not found. Skipping GPU status."
    }

    Write-Host "Runtime check completed: $(Get-Date -Format o)"
}

try {
    try {
        Start-Transcript -Path $logPath -Append | Out-Null
        $transcriptStarted = $true
    }
    catch {
        Write-Warning "Failed to start transcript logging at $logPath. $($_.Exception.Message)"
    }

    Write-Host "Local LLM runtime startup"
    Write-Host "Mode: $modeName"
    Write-Host "Watch interval seconds: $effectiveCheckIntervalSeconds"

    if ($Watch) {
        while ($true) {
            try {
                Invoke-RuntimeCheck
            }
            catch {
                Write-Error $_
            }

            Write-Host "Sleeping for $effectiveCheckIntervalSeconds seconds."
            Start-Sleep -Seconds $effectiveCheckIntervalSeconds
        }
    }

    Invoke-RuntimeCheck
    Write-Host "Local LLM runtime is ready."
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
