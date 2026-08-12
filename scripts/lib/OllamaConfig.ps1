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
    }
}

function Get-OllamaProfiles {
    $config = Get-OllamaRawConfig
    return $config.profiles.PSObject.Properties.Name
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
