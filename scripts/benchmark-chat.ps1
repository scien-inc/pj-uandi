param(
    [string]$Profile = "qwen3-8b",
    [int]$Runs = 3,
    [string]$OutFile = "benchmarks\ollama-chat-results.csv"
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig -Profile $Profile
Assert-OllamaServer -OllamaHost $modelConfig.OllamaHost

$prompt = "For a forensic review, classify a case where the receipt amount does not match the reimbursement claim. Return JSON with risk_score, violation_type, and summary."
$rows = @()

for ($i = 1; $i -le $Runs; $i++) {
    $body = @{
        model = $modelConfig.Model
        stream = $false
        temperature = 0.2
        messages = @(
            @{ role = "system"; content = "Return concise Japanese JSON only." },
            @{ role = "user"; content = $prompt }
        )
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-OllamaJson -Method Post -Uri "$($modelConfig.OpenAiBaseUrl)/chat/completions" -Body $body
    $stopwatch.Stop()

    $completionTokens = $null
    if ($null -ne $result.usage -and $null -ne $result.usage.completion_tokens) {
        $completionTokens = [int]$result.usage.completion_tokens
    }

    $tokensPerSecond = if ($completionTokens -and $stopwatch.Elapsed.TotalSeconds -gt 0) {
        [math]::Round($completionTokens / $stopwatch.Elapsed.TotalSeconds, 2)
    } else {
        $null
    }

    $rows += [PSCustomObject]@{
        timestamp = (Get-Date).ToString("s")
        profile = $modelConfig.Profile
        model = $modelConfig.Model
        run = $i
        elapsed_seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        completion_tokens = $completionTokens
        completion_tokens_per_second = $tokensPerSecond
        response_preview = (($result.choices[0].message.content -replace "`r?`n", " ") -replace ",", " ")
    }

    Write-Host "Run $i/${Runs}: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) sec"
}

$outPath = Join-Path $modelConfig.RepoRoot $OutFile
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (Test-Path -LiteralPath $outPath) {
    $rows | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8 -Append
} else {
    $rows | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Benchmark results saved to $outPath"
