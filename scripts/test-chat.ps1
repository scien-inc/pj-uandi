param(
    [ValidateSet("All", "OpenAI", "Ollama")]
    [string]$Protocol = "All",
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

function Invoke-ChatCheck {
    param(
        [ValidateSet("OpenAI", "Ollama")]
        [string]$TargetProtocol
    )

    if ($TargetProtocol -eq "OpenAI") {
        $uri = "$($modelConfig.OpenAiBaseUrl)/chat/completions"
        Write-Host "POST $uri"
        Write-Host "protocol=OpenAI"
        Write-Host "model=$($modelConfig.Model)"

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-OllamaJson -Method Post -Uri $uri -Body $body
        $stopwatch.Stop()
        $content = $result.choices[0].message.content
    }
    else {
        $uri = "$($modelConfig.OllamaHost)/api/chat"
        Write-Host "POST $uri"
        Write-Host "protocol=Ollama"
        Write-Host "model=$($modelConfig.Model)"

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-OllamaJson -Method Post -Uri $uri -Body $body
        $stopwatch.Stop()
        $content = $result.message.content
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "$TargetProtocol chat API returned no response content."
    }

    Write-Host ""
    Write-Host "Elapsed: $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) sec"
    Write-Host "Response:"
    $content
    Write-Host ""
}

if ($Protocol -eq "All") {
    Invoke-ChatCheck -TargetProtocol OpenAI
    Invoke-ChatCheck -TargetProtocol Ollama
}
else {
    Invoke-ChatCheck -TargetProtocol $Protocol
}
