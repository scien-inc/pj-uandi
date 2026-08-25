Set-StrictMode -Version Latest

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Get-OllamaRawConfig {
    $repoRoot = Get-RepoRoot
    $configPath = Join-Path $repoRoot "config\ollama-models.json"

    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Config file not found: $configPath"
    }

    return Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-OllamaModelConfig {
    param(
        [string]$Profile
    )

    $repoRoot = Get-RepoRoot
    $configPath = Join-Path $repoRoot "config\ollama-models.json"
    $config = Get-OllamaRawConfig
    $selectedProfile = if ([string]::IsNullOrWhiteSpace($Profile)) { $config.defaultProfile } else { $Profile }
    $profileProperty = $config.profiles.PSObject.Properties[$selectedProfile]

    if ($null -eq $profileProperty) {
        $available = ($config.profiles.PSObject.Properties.Name -join ", ")
        throw "Unknown profile '$selectedProfile'. Available profiles: $available"
    }

    $profileConfig = $profileProperty.Value

    $cudaVisibleDevices = ""
    $cudaProperty = $config.PSObject.Properties["cudaVisibleDevices"]
    if ($null -ne $cudaProperty -and $null -ne $cudaProperty.Value) {
        $cudaVisibleDevices = [string]$cudaProperty.Value
    }

    $preferredGpuNamePattern = ""
    $preferredGpuProperty = $config.PSObject.Properties["preferredGpuNamePattern"]
    if ($null -ne $preferredGpuProperty -and $null -ne $preferredGpuProperty.Value) {
        $preferredGpuNamePattern = [string]$preferredGpuProperty.Value
    }

    return [PSCustomObject]@{
        RepoRoot = $repoRoot
        ConfigPath = $configPath
        Profile = $selectedProfile
        Model = $profileConfig.model
        Purpose = $profileConfig.purpose
        KeepAlive = $profileConfig.keepAlive
        Notes = $profileConfig.notes
        OllamaHost = $config.ollamaHost.TrimEnd("/")
        OpenAiBaseUrl = $config.openAiBaseUrl.TrimEnd("/")
        CudaVisibleDevices = $cudaVisibleDevices
        PreferredGpuNamePattern = $preferredGpuNamePattern
    }
}

function Get-OllamaProfiles {
    $config = Get-OllamaRawConfig
    return $config.profiles.PSObject.Properties.Name
}

function Get-NvidiaGpuInventory {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($null -eq $nvidiaSmi) {
        return @()
    }

    try {
        $rows = & $nvidiaSmi.Source --query-gpu=index,uuid,name,memory.total --format=csv,noheader,nounits 2>$null
    }
    catch {
        return @()
    }

    if ($LASTEXITCODE -ne 0 -or $null -eq $rows) {
        return @()
    }

    $gpus = @()
    foreach ($row in @($rows)) {
        if ([string]::IsNullOrWhiteSpace($row)) {
            continue
        }

        $fields = $row -split ","
        if ($fields.Count -lt 4) {
            continue
        }

        $gpus += [PSCustomObject]@{
            Index = [int]$fields[0].Trim()
            Uuid = $fields[1].Trim()
            Name = $fields[2].Trim()
            MemoryTotalMiB = [int]$fields[3].Trim()
        }
    }

    return $gpus
}

function Select-PreferredGpu {
    param(
        [object[]]$Gpus,
        [string]$PreferredGpuNamePattern
    )

    $candidates = @($Gpus)
    if ($candidates.Count -eq 0) {
        return $null
    }

    # Name match wins, so a rebuilt machine keeps using the intended card even if VRAM ranking changes.
    if (-not [string]::IsNullOrWhiteSpace($PreferredGpuNamePattern)) {
        $matched = @($candidates | Where-Object { $_.Name -match $PreferredGpuNamePattern })
        if ($matched.Count -gt 0) {
            return ($matched | Sort-Object -Property MemoryTotalMiB -Descending | Select-Object -First 1)
        }
    }

    return ($candidates | Sort-Object -Property MemoryTotalMiB -Descending | Select-Object -First 1)
}

function Resolve-GpuSelection {
    param(
        [string]$CudaVisibleDevices,
        [string]$PreferredGpuNamePattern
    )

    $requested = if ($null -eq $CudaVisibleDevices) { "" } else { $CudaVisibleDevices.Trim() }

    if ([string]::IsNullOrWhiteSpace($requested)) {
        return [PSCustomObject]@{
            Value = ""
            Gpu = $null
            Description = "GPU selection: all GPUs (cudaVisibleDevices is empty)."
        }
    }

    if ($requested -ne "auto") {
        return [PSCustomObject]@{
            Value = $requested
            Gpu = $null
            Description = "GPU selection: fixed by config to '$requested'."
        }
    }

    $gpus = @(Get-NvidiaGpuInventory)
    if ($gpus.Count -eq 0) {
        return [PSCustomObject]@{
            Value = ""
            Gpu = $null
            Description = "GPU selection: nvidia-smi is unavailable or reported no GPU. Falling back to all GPUs."
        }
    }

    $selected = Select-PreferredGpu -Gpus $gpus -PreferredGpuNamePattern $PreferredGpuNamePattern
    $memoryGb = [math]::Round($selected.MemoryTotalMiB / 1024, 1)
    $reason = if (-not [string]::IsNullOrWhiteSpace($PreferredGpuNamePattern) -and $selected.Name -match $PreferredGpuNamePattern) {
        "name matches '$PreferredGpuNamePattern'"
    }
    else {
        "largest VRAM"
    }

    # The UUID is used instead of the index so the pinning survives driver or slot changes.
    return [PSCustomObject]@{
        Value = $selected.Uuid
        Gpu = $selected
        Description = "GPU selection: GPU $($selected.Index) $($selected.Name) ($memoryGb GB, $reason)."
    }
}

function Assert-OllamaCommand {
    $command = Get-Command ollama -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Ollama CLI was not found. Install Ollama for Windows first, then reopen PowerShell."
    }
    return $command.Source
}

function Test-OllamaServer {
    param(
        [string]$OllamaHost
    )

    try {
        Invoke-RestMethod -Method Get -Uri "$($OllamaHost.TrimEnd('/'))/api/tags" -TimeoutSec 3 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Assert-OllamaServer {
    param(
        [string]$OllamaHost
    )

    if (-not (Test-OllamaServer -OllamaHost $OllamaHost)) {
        throw "Ollama server is not responding at $OllamaHost. Run scripts\start-ollama-server.ps1 first."
    }
}

function Invoke-OllamaJson {
    param(
        [ValidateSet("Get", "Post")]
        [string]$Method,
        [string]$Uri,
        [hashtable]$Body
    )

    if ($Method -eq "Get") {
        return Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 60
    }

    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Body $json -TimeoutSec 600
}
