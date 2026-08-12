param(
    [int]$StopTimeoutSeconds = 30
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig
$serviceName = "Ollama"
$stoppedSomething = $false

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($null -ne $service) {
    if ($service.Status -eq "Stopped") {
        Write-Host "Service '$serviceName' is already stopped."
    }
    else {
        Write-Host "Stopping service '$serviceName'..."
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
        }
        catch {
            throw "Failed to stop service '$serviceName'. Run PowerShell as Administrator and try again. $_"
        }
        $stoppedSomething = $true
    }
}

# The tray app restarts the server process, so stop it first.
foreach ($processName in @("ollama app", "ollama", "ollama_llama_server")) {
    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($null -eq $processes) {
        continue
    }

    $processIds = ($processes | ForEach-Object { $_.Id }) -join ", "
    Write-Host "Stopping process '$processName' (PID: $processIds)..."
    $processes | Stop-Process -Force -ErrorAction SilentlyContinue
    $stoppedSomething = $true
}

if (-not $stoppedSomething) {
    Write-Host "Ollama is not running."
    exit 0
}

$deadline = (Get-Date).AddSeconds($StopTimeoutSeconds)
do {
    Start-Sleep -Seconds 1
    $remaining = Get-Process -Name "ollama*" -ErrorAction SilentlyContinue
    if ($null -eq $remaining -and -not (Test-OllamaServer -OllamaHost $modelConfig.OllamaHost)) {
        Write-Host "Ollama stopped. $($modelConfig.OllamaHost) is no longer responding."
        exit 0
    }
} while ((Get-Date) -lt $deadline)

throw "Ollama did not stop within $StopTimeoutSeconds seconds. Check remaining processes with: Get-Process ollama*"
