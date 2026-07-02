param(
    [string]$Profile = "qwen3-8b",
    [string]$Prompt = "Say hello world in one short sentence.",
    [double]$Temperature = 0.2
)

. "$PSScriptRoot\lib\OllamaConfig.ps1"

$modelConfig = Get-OllamaModelConfig -Profile $Profile
Assert-OllamaServer -OllamaHost $modelConfig.OllamaHost

$body = @{
    model = $modelConfig.Model
    stream = $false
    temperature = $Temperature
    messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant. Keep the response short."
        },
        @{
            role = "user"
            content = $Prompt
        }
    )
}

Write-Host "POST $($modelConfig.OpenAiBaseUrl)/chat/completions"
Write-Host "model=$($modelConfig.Model)"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$result = Invoke-OllamaJson -Method Post -Uri "$($modelConfig.OpenAiBaseUrl)/chat/completions" -Body $body
$stopwatch.Stop()

Write-Host ""
Write-Host "Elapsed: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) sec"
Write-Host "Response:"
$result.choices[0].message.content
