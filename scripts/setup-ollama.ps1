param(
    [string[]]$Profile = @(),
    [switch]$SkipPull
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

Assert-OllamaCommand | Out-Null
$baseConfig = Get-OllamaModelConfig -Profile ""
Assert-OllamaServer -OllamaHost $baseConfig.OllamaHost

$profiles = if ($null -eq $Profile -or $Profile.Count -eq 0) {
    @($baseConfig.Profile)
}
else {
    $Profile
}

foreach ($profileName in $profiles) {
    $modelConfig = Get-OllamaModelConfig -Profile $profileName
    Write-Host "Profile: $($modelConfig.Profile)"
    Write-Host "Model:   $($modelConfig.Model)"
    Write-Host "Purpose: $($modelConfig.Purpose)"

    if ($SkipPull) {
        Write-Host "Skipping pull for $($modelConfig.Model)."
        continue
    }

    Write-Host "Pulling $($modelConfig.Model)..."
    & ollama pull $modelConfig.Model
    if ($LASTEXITCODE -ne 0) {
        throw "ollama pull failed for $($modelConfig.Model)."
    }
}

Write-Host "Setup completed."
