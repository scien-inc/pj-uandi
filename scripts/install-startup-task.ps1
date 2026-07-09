param(
    [string]$TaskName = "",
    [string]$Profile = "",
    [string]$KeepAlive = "",
    [int]$CheckIntervalSeconds = 0,
    [switch]$Pull,
    [switch]$StartNow,
    [switch]$NoWatch
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\OllamaConfig.ps1"

Import-Module ScheduledTasks -ErrorAction Stop

$runtimeConfig = Get-OllamaRuntimeConfig
$modelConfig = Get-OllamaModelConfig -Profile $Profile
$effectiveTaskName = if ([string]::IsNullOrWhiteSpace($TaskName)) {
    $runtimeConfig.TaskName
}
else {
    $TaskName
}

$runtimeScript = Join-Path $PSScriptRoot "run-ollama-runtime.ps1"
if (-not (Test-Path -LiteralPath $runtimeScript)) {
    throw "Runtime script not found: $runtimeScript"
}

$effectiveCheckIntervalSeconds = if ($CheckIntervalSeconds -gt 0) {
    $CheckIntervalSeconds
}
else {
    $runtimeConfig.WatchIntervalSeconds
}

$argumentParts = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$runtimeScript`"",
    "-Profile", "`"$($modelConfig.Profile)`""
)

if (-not $NoWatch) {
    $argumentParts += @("-Watch", "-CheckIntervalSeconds", $effectiveCheckIntervalSeconds)
}

if (-not [string]::IsNullOrWhiteSpace($KeepAlive)) {
    $argumentParts += @("-KeepAlive", "`"$KeepAlive`"")
}

if ($Pull) {
    $argumentParts += "-Pull"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument ($argumentParts -join " ") `
    -WorkingDirectory $runtimeConfig.RepoRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited

$description = "Start Ollama and load the configured local LLM profile for OpenAI-compatible API on Windows logon."

Register-ScheduledTask `
    -TaskName $effectiveTaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description $description `
    -Force | Out-Null

Write-Host "Registered scheduled task '$effectiveTaskName'."
Write-Host "Trigger: user logon"
Write-Host "User:    $currentUser"
Write-Host "Profile: $($modelConfig.Profile)"
Write-Host "Model:   $($modelConfig.Model)"
Write-Host "Watch:   $(-not $NoWatch)"
if (-not $NoWatch) {
    Write-Host "Interval: $effectiveCheckIntervalSeconds sec"
}
Write-Host "Action:  powershell.exe $($argumentParts -join ' ')"

if ($StartNow) {
    Write-Host "Starting scheduled task '$effectiveTaskName' now..."
    Start-ScheduledTask -TaskName $effectiveTaskName
}
