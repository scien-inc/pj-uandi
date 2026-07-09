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
    }
}

function Get-OllamaRuntimeConfig {
    $repoRoot = Get-RepoRoot
    $config = Get-OllamaRawConfig
    $runtimeProperty = $config.PSObject.Properties["runtime"]
    $runtimeConfig = if ($null -eq $runtimeProperty) { $null } else { $runtimeProperty.Value }

    $taskName = "LocalLlmOllamaRuntime"
    $startupTimeoutSeconds = 60
    $logDirectory = "logs"
    $keepAlive = ""
    $watchIntervalSeconds = 300

    if ($null -ne $runtimeConfig) {
        $taskNameProperty = $runtimeConfig.PSObject.Properties["startupTaskName"]
        if ($null -ne $taskNameProperty -and -not [string]::IsNullOrWhiteSpace($taskNameProperty.Value)) {
            $taskName = $taskNameProperty.Value
        }

        $startupTimeoutProperty = $runtimeConfig.PSObject.Properties["startupTimeoutSeconds"]
        if ($null -ne $startupTimeoutProperty -and $startupTimeoutProperty.Value -gt 0) {
            $startupTimeoutSeconds = [int]$startupTimeoutProperty.Value
        }

        $logDirectoryProperty = $runtimeConfig.PSObject.Properties["logDirectory"]
        if ($null -ne $logDirectoryProperty -and -not [string]::IsNullOrWhiteSpace($logDirectoryProperty.Value)) {
            $logDirectory = $logDirectoryProperty.Value
        }

        $keepAliveProperty = $runtimeConfig.PSObject.Properties["keepAlive"]
        if ($null -ne $keepAliveProperty -and -not [string]::IsNullOrWhiteSpace($keepAliveProperty.Value)) {
            $keepAlive = $keepAliveProperty.Value
        }

        $watchIntervalProperty = $runtimeConfig.PSObject.Properties["watchIntervalSeconds"]
        if ($null -ne $watchIntervalProperty -and $watchIntervalProperty.Value -gt 0) {
            $watchIntervalSeconds = [int]$watchIntervalProperty.Value
        }
    }

    $resolvedLogDirectory = if ([System.IO.Path]::IsPathRooted($logDirectory)) {
        $logDirectory
    }
    else {
        Join-Path $repoRoot $logDirectory
    }

    return [PSCustomObject]@{
        RepoRoot = $repoRoot
        TaskName = $taskName
        StartupTimeoutSeconds = $startupTimeoutSeconds
        LogDirectory = $resolvedLogDirectory
        KeepAlive = $keepAlive
        WatchIntervalSeconds = $watchIntervalSeconds
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

function Start-OllamaServerIfNeeded {
    param(
        [string]$OllamaHost,
        [int]$StartupTimeoutSeconds = 60
    )

    $ollamaExe = Assert-OllamaCommand

    if (Test-OllamaServer -OllamaHost $OllamaHost) {
        return "already-running"
    }

    Write-Host "Starting Ollama server at $OllamaHost..."
    Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden | Out-Null

    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    do {
        Start-Sleep -Seconds 1
        if (Test-OllamaServer -OllamaHost $OllamaHost) {
            return "started"
        }
    } while ((Get-Date) -lt $deadline)

    throw "Ollama server did not become ready within $StartupTimeoutSeconds seconds."
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

function Invoke-OllamaModelLoad {
    param(
        [string]$OllamaHost,
        [string]$Model,
        [string]$KeepAlive
    )

    $body = @{
        model = $Model
        prompt = ""
        keep_alive = $KeepAlive
        stream = $false
    }

    return Invoke-OllamaJson -Method Post -Uri "$($OllamaHost.TrimEnd('/'))/api/generate" -Body $body
}

function Test-OllamaOpenAiChat {
    param(
        [string]$OpenAiBaseUrl,
        [string]$Model
    )

    $body = @{
        model = $Model
        stream = $false
        temperature = 0
        messages = @(
            @{
                role = "system"
                content = "Reply with exactly OK."
            },
            @{
                role = "user"
                content = "Health check."
            }
        )
    }

    $result = Invoke-OllamaJson -Method Post -Uri "$($OpenAiBaseUrl.TrimEnd('/'))/chat/completions" -Body $body
    $choices = @($result.choices)

    if ($choices.Count -eq 0 -or [string]::IsNullOrWhiteSpace($choices[0].message.content)) {
        throw "OpenAI-compatible chat API returned no response content."
    }

    return $result
}

function Get-OllamaOpenAiModels {
    param(
        [string]$OpenAiBaseUrl
    )

    return Invoke-OllamaJson -Method Get -Uri "$($OpenAiBaseUrl.TrimEnd('/'))/models"
}
