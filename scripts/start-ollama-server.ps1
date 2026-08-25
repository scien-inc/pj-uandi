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
        Write-Host "Note: GPU selection only applies when this script starts the server. Run scripts\stop-ollama-server.ps1 and rerun this script to apply it."
    }
    exit 0
}

$gpuSelection = Resolve-GpuSelection `
    -CudaVisibleDevices $modelConfig.CudaVisibleDevices `
    -PreferredGpuNamePattern $modelConfig.PreferredGpuNamePattern

Write-Host $gpuSelection.Description
if (-not [string]::IsNullOrWhiteSpace($gpuSelection.Value)) {
    $env:CUDA_DEVICE_ORDER = "PCI_BUS_ID"
    $env:CUDA_VISIBLE_DEVICES = $gpuSelection.Value
    Write-Host "CUDA_VISIBLE_DEVICES=$($gpuSelection.Value)"
}

if ($modelConfig.ContextLength -gt 0) {
    $env:OLLAMA_CONTEXT_LENGTH = [string]$modelConfig.ContextLength
    Write-Host "OLLAMA_CONTEXT_LENGTH=$($modelConfig.ContextLength)"
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
