param(
    [string]$TaskName = "",
    [string]$Profile = ""
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

$task = Get-ScheduledTask -TaskName $effectiveTaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    Write-Host "Scheduled task '$effectiveTaskName' is not installed."
}
else {
    $info = Get-ScheduledTaskInfo -TaskName $effectiveTaskName

    Write-Host "Scheduled task: $effectiveTaskName"
    Write-Host "State:          $($task.State)"
    Write-Host "Last run:       $($info.LastRunTime)"
    Write-Host "Last result:    $($info.LastTaskResult)"
    Write-Host "Next run:       $($info.NextRunTime)"
}

Write-Host ""
Write-Host "Runtime target:"
Write-Host "Profile: $($modelConfig.Profile)"
Write-Host "Model:   $($modelConfig.Model)"
Write-Host "Host:    $($modelConfig.OllamaHost)"
Write-Host "OpenAI:  $($modelConfig.OpenAiBaseUrl)"
Write-Host "Logs:    $($runtimeConfig.LogDirectory)"

Write-Host ""
if (Test-OllamaServer -OllamaHost $modelConfig.OllamaHost) {
    Write-Host "Ollama server: OK"

    try {
        $models = Get-OllamaOpenAiModels -OpenAiBaseUrl $modelConfig.OpenAiBaseUrl
        $modelCount = @($models.data).Count
        Write-Host "OpenAI /v1/models: OK ($modelCount models)"
    }
    catch {
        Write-Host "OpenAI /v1/models: FAILED"
        Write-Host $_.Exception.Message
    }

    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($null -ne $ollama) {
        Write-Host ""
        Write-Host "ollama ps:"
        & ollama ps
    }
}
else {
    Write-Host "Ollama server: not responding"
}
