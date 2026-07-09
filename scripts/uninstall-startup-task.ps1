param(
    [string]$TaskName = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\OllamaConfig.ps1"

Import-Module ScheduledTasks -ErrorAction Stop

$runtimeConfig = Get-OllamaRuntimeConfig
$effectiveTaskName = if ([string]::IsNullOrWhiteSpace($TaskName)) {
    $runtimeConfig.TaskName
}
else {
    $TaskName
}

$task = Get-ScheduledTask -TaskName $effectiveTaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    Write-Host "Scheduled task '$effectiveTaskName' is not installed."
    exit 0
}

if ($task.State -eq "Running") {
    Write-Host "Stopping scheduled task '$effectiveTaskName'..."
    Stop-ScheduledTask -TaskName $effectiveTaskName
    Start-Sleep -Seconds 2
}

Unregister-ScheduledTask -TaskName $effectiveTaskName -Confirm:$false
Write-Host "Removed scheduled task '$effectiveTaskName'."
