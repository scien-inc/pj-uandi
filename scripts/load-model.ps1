param(
    [string]$Profile = "qwen3-8b",
    [string]$KeepAlive = "",
    [switch]$Pull
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

Assert-OllamaCommand | Out-Null
$modelConfig = Get-OllamaModelConfig -Profile $Profile
Assert-OllamaServer -OllamaHost $modelConfig.OllamaHost

$effectiveKeepAlive = if ([string]::IsNullOrWhiteSpace($KeepAlive)) { $modelConfig.KeepAlive } else { $KeepAlive }

if ($Pull) {
    Write-Host "Pulling $($modelConfig.Model)..."
    & ollama pull $modelConfig.Model
    if ($LASTEXITCODE -ne 0) {
        throw "ollama pull failed for $($modelConfig.Model)."
    }
}

Write-Host "Loading model $($modelConfig.Model) with keep_alive=$effectiveKeepAlive..."
$body = @{
    model = $modelConfig.Model
    prompt = ""
    keep_alive = $effectiveKeepAlive
    stream = $false
}

Invoke-OllamaJson -Method Post -Uri "$($modelConfig.OllamaHost)/api/generate" -Body $body | Out-Null

Write-Host "Loaded profile '$($modelConfig.Profile)' as model '$($modelConfig.Model)'."
Write-Host "OpenAI-compatible base URL: $($modelConfig.OpenAiBaseUrl)"
Write-Host "Use model name in clients: $($modelConfig.Model)"
& ollama ps
