param()

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig
$gpus = @(Get-NvidiaGpuInventory)

if ($gpus.Count -eq 0) {
    Write-Host "No NVIDIA GPU was detected (nvidia-smi is unavailable or returned nothing)."
    Write-Host "Ollama will fall back to whatever device it finds, or to CPU."
    exit 0
}

$gpuSelection = Resolve-GpuSelection `
    -CudaVisibleDevices $modelConfig.CudaVisibleDevices `
    -PreferredGpuNamePattern $modelConfig.PreferredGpuNamePattern

$selectedIds = @()
if ($null -ne $gpuSelection.Gpu) {
    $selectedIds = @($gpuSelection.Gpu.Uuid)
}
elseif (-not [string]::IsNullOrWhiteSpace($gpuSelection.Value)) {
    $selectedIds = @($gpuSelection.Value -split "," | ForEach-Object { $_.Trim() })
}

$rows = foreach ($gpu in ($gpus | Sort-Object -Property Index)) {
    $inUse = ($selectedIds -contains $gpu.Uuid) -or ($selectedIds -contains [string]$gpu.Index)
    $marker = ""
    if ($inUse) {
        $marker = "*"
    }

    [PSCustomObject]@{
        Use = $marker
        Index = $gpu.Index
        Name = $gpu.Name
        VRAM_GB = [math]::Round($gpu.MemoryTotalMiB / 1024, 1)
        Uuid = $gpu.Uuid
    }
}

Write-Host "Detected GPUs ('*' is the one Ollama will be pinned to):"
$rows | Format-Table -AutoSize | Out-Host

Write-Host "cudaVisibleDevices:      '$($modelConfig.CudaVisibleDevices)'"
Write-Host "preferredGpuNamePattern: '$($modelConfig.PreferredGpuNamePattern)'"
Write-Host $gpuSelection.Description
if (-not [string]::IsNullOrWhiteSpace($gpuSelection.Value)) {
    Write-Host "CUDA_VISIBLE_DEVICES that start-ollama-server.ps1 will set: $($gpuSelection.Value)"
}
else {
    Write-Host "start-ollama-server.ps1 will not set CUDA_VISIBLE_DEVICES (all GPUs are used)."
}
