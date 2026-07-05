param(
    [string]$Profile = "",
    [int]$StartupTimeoutSeconds = 30
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig -Profile $Profile
$ollamaExe = Assert-OllamaCommand

if (Test-OllamaServer -OllamaHost $modelConfig.OllamaHost) {
    Write-Host "Ollama server is already responding at $($modelConfig.OllamaHost)."
    exit 0
}

Write-Host "Starting Ollama server at $($modelConfig.OllamaHost)..."
Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden | Out-Null

$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Seconds 1
    if (Test-OllamaServer -OllamaHost $modelConfig.OllamaHost) {
        Write-Host "Ollama server is ready at $($modelConfig.OllamaHost)."
        exit 0
    }
} while ((Get-Date) -lt $deadline)

throw "Ollama server did not become ready within $StartupTimeoutSeconds seconds."
