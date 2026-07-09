param(
    [string]$Profile = ""
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

Assert-OllamaCommand | Out-Null
$modelConfig = Get-OllamaModelConfig -Profile $Profile
Assert-OllamaServer -OllamaHost $modelConfig.OllamaHost

Write-Host "Unloading model $($modelConfig.Model)..."
$body = @{
    model = $modelConfig.Model
    prompt = ""
    keep_alive = 0
    stream = $false
}

Invoke-OllamaJson -Method Post -Uri "$($modelConfig.OllamaHost)/api/generate" -Body $body | Out-Null
Write-Host "Unload request sent for $($modelConfig.Model)."
& ollama ps
