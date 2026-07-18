[CmdletBinding()]
param(
    [string]$Profile = "",
    [string]$KeepAlive = "",
    [string]$Prompt = "Say hello world in one short sentence.",
    [switch]$InstallOllama,
    [switch]$SkipPull,
    [switch]$SkipTest,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$powerShellExe = (Get-Command powershell.exe -ErrorAction Stop).Source

function Format-CommandArgument {
    param([string]$Value)

    if ($Value -match '[\s"]') {
        return '"' + $Value.Replace('"', '\"') + '"'
    }

    return $Value
}

function Invoke-ProjectScript {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$ScriptArguments = @()
    )

    $arguments = @(
        "-NoLogo"
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        $ScriptPath
    ) + $ScriptArguments

    $displayArguments = ($arguments | ForEach-Object { Format-CommandArgument -Value $_ }) -join " "
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host "    powershell.exe $displayArguments"

    if ($DryRun) {
        return
    }

    & $powerShellExe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Install-OllamaForWindows {
    Write-Host ""
    Write-Host "==> Install Ollama for Windows" -ForegroundColor Cyan
    Write-Host "    Downloading and running the official installer from https://ollama.com/install.ps1"

    if ($DryRun) {
        return
    }

    $installer = Invoke-RestMethod -Uri "https://ollama.com/install.ps1" -UseBasicParsing
    & ([scriptblock]::Create([string]$installer))

    $ollamaCandidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"),
        (Join-Path $env:LOCALAPPDATA "Ollama\ollama.exe")
    )
    $ollamaExe = $ollamaCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($ollamaExe)) {
        throw "Ollama installation finished, but ollama.exe was not found. Reopen PowerShell and run Quick Setup again."
    }

    $ollamaDirectory = Split-Path -Parent $ollamaExe
    if (($env:Path -split ';') -notcontains $ollamaDirectory) {
        $env:Path = "$ollamaDirectory;$env:Path"
    }

    Write-Host "Ollama installed: $ollamaExe"
}

try {
    Write-Host "Local LLM API quick setup" -ForegroundColor Green
    Write-Host "Repository: $repoRoot"
    if ([string]::IsNullOrWhiteSpace($Profile)) {
        Write-Host "Profile:    default (config/ollama-models.json)"
    }
    else {
        Write-Host "Profile:    $Profile"
    }

    if ($null -eq (Get-Command ollama -ErrorAction SilentlyContinue)) {
        if ($InstallOllama) {
            Install-OllamaForWindows
        }
        elseif (-not $DryRun) {
            throw "Ollama CLI was not found. Run Quick Setup again with -InstallOllama, or install Ollama first: irm https://ollama.com/install.ps1 | iex"
        }
    }

    $profileArguments = if ([string]::IsNullOrWhiteSpace($Profile)) { @() } else { @("-Profile", $Profile) }

    Invoke-ProjectScript `
        -Name "Start Ollama server" `
        -ScriptPath (Join-Path $PSScriptRoot "start-ollama-server.ps1") `
        -ScriptArguments $profileArguments

    $setupArguments = @($profileArguments)
    if ($SkipPull) {
        $setupArguments += "-SkipPull"
    }
    Invoke-ProjectScript `
        -Name "Pull model" `
        -ScriptPath (Join-Path $PSScriptRoot "setup-ollama.ps1") `
        -ScriptArguments $setupArguments

    $loadArguments = @($profileArguments)
    if (-not [string]::IsNullOrWhiteSpace($KeepAlive)) {
        $loadArguments += @("-KeepAlive", $KeepAlive)
    }
    Invoke-ProjectScript `
        -Name "Load model" `
        -ScriptPath (Join-Path $PSScriptRoot "load-model.ps1") `
        -ScriptArguments $loadArguments

    if (-not $SkipTest) {
        $testArguments = @($profileArguments) + @("-Prompt", $Prompt)
        Invoke-ProjectScript `
            -Name "Test OpenAI-compatible API" `
            -ScriptPath (Join-Path $PSScriptRoot "test-openai-chat.ps1") `
            -ScriptArguments $testArguments
    }

    Write-Host ""
    if ($DryRun) {
        Write-Host "Dry run completed. No setup commands were executed." -ForegroundColor Yellow
    }
    else {
        Write-Host "Quick setup completed successfully." -ForegroundColor Green
        Write-Host "OpenAI-compatible base URL: http://localhost:11434/v1"
    }
}
catch {
    Write-Error $_
    exit 1
}
