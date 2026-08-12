param(
    [string]$Profile = "",
    [int]$StartupTimeoutSeconds = 30
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig -Profile $Profile
$ollamaExe = Assert-OllamaCommand

if (Test-OllamaServer -OllamaHost $modelConfig.OllamaHost) {
    Write-Host "Ollama server is already responding at $($modelConfig.OllamaHost)."
    if (-not [string]::IsNullOrWhiteSpace($modelConfig.CudaVisibleDevices)) {
        Write-Host "Note: cudaVisibleDevices in config only applies when this script starts the server. Quit the running Ollama (task tray) and rerun this script to apply GPU selection."
    }
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($modelConfig.CudaVisibleDevices)) {
    $env:CUDA_DEVICE_ORDER = "PCI_BUS_ID"
    $env:CUDA_VISIBLE_DEVICES = $modelConfig.CudaVisibleDevices
    Write-Host "Restricting Ollama to GPU(s): $($modelConfig.CudaVisibleDevices)"
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
