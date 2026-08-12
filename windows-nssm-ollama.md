# NSSMによるOllamaのWindowsサービス化

この手順では、NSSM（Non-Sucking Service Manager）を使用してOllamaをWindowsサービスとして登録します。

サービス化すると、Windowsへのログオン前からOllama APIを起動でき、Ollamaが異常終了した場合にも自動的に再起動できます。

```text
Windows Service Control Manager
  -> NSSM: LocalOllama
       -> ollama.exe serve
            -> http://127.0.0.1:11434
            -> OpenAI互換API: http://127.0.0.1:11434/v1
```

> NSSMからは `ollama.exe serve` を直接起動します。`scripts/start-ollama-server.ps1` は別プロセスを起動した後に終了するため、NSSMの監視対象には使用しません。

## 前提条件

- Windows 11またはWindows Server
- 管理者権限を持つWindowsユーザー
- Ollama for Windows
- 使用するモデルを保存できる十分なディスク容量
- GPUを使用する場合は、対応するGPUドライバー

以降のサービス登録操作は、「管理者として実行」したPowerShellで行います。

## 1. NSSMをダウンロードする

[NSSM公式ダウンロードページ](https://www.nssm.cc/download)を開き、Windows 10以降に対応したバージョンをダウンロードします。

公式ページでは、Windows 10 Creators Update以降について、`2.24-101`以降のビルドを使用するよう案内されています。64bit版Windowsでは、ダウンロードしたZIPに含まれる `win64\nssm.exe` を使用します。

Windowsが64bit版かどうかは、PowerShellで確認できます。

```powershell
[System.Environment]::Is64BitOperatingSystem
```

`True` の場合は `win64\nssm.exe` を使用します。

## 2. NSSMを展開する

ダウンロードしたZIPファイルを右クリックし、`すべて展開` を選択します。

展開後の構成例は次のとおりです。

```text
nssm-2.24-101-g897c7ad
|-- win32
|   `-- nssm.exe
`-- win64
    `-- nssm.exe
```

PowerShellで展開する場合は、実際のZIPファイル名に合わせて `$archive` を変更します。

```powershell
$archive = "$env:USERPROFILE\Downloads\nssm-2.24-101-g897c7ad.zip"
$extractDirectory = "$env:TEMP\nssm-install"

Expand-Archive `
  -LiteralPath $archive `
  -DestinationPath $extractDirectory `
  -Force
```

## 3. NSSMを固定ディレクトリへ配置する

サービス登録後に `nssm.exe` を移動または削除すると、サービスを起動できなくなります。ダウンロードフォルダーや一時ディレクトリから直接使用せず、固定された場所へ配置します。

この手順では次の場所を使用します。

```text
C:\Program Files\nssm\win64\nssm.exe
```

管理者PowerShellで、配置先ディレクトリを作成します。

```powershell
$nssmDirectory = "C:\Program Files\nssm\win64"

New-Item `
  -ItemType Directory `
  -Path $nssmDirectory `
  -Force | Out-Null
```

展開した64bit版のファイルを指定します。バージョンと展開先に合わせて変更してください。

```powershell
$sourceNssm = "$env:TEMP\nssm-install\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$destinationNssm = "C:\Program Files\nssm\win64\nssm.exe"

Copy-Item `
  -LiteralPath $sourceNssm `
  -Destination $destinationNssm `
  -Force
```

Windowsによってファイルがブロックされている場合は、ブロックを解除します。

```powershell
Unblock-File -LiteralPath $destinationNssm
```

NSSMを実行して、バージョンを確認します。

```powershell
$nssm = "C:\Program Files\nssm\win64\nssm.exe"

& $nssm version
```


## 4. Ollamaアプリとの二重起動を避ける

Ollamaのデスクトップアプリがすでに起動している場合は、タスクトレイから終了します。

デスクトップアプリとWindowsサービスの両方が起動すると、ポート `11434` が競合する可能性があります。サービス登録後は、NSSM側でOllamaを起動します。

現在のポート使用状況は次のコマンドで確認できます。

```powershell
Get-NetTCPConnection `
  -LocalPort 11434 `
  -ErrorAction SilentlyContinue
```

## 5. ログディレクトリを作成する

管理者PowerShellで実行します。

```powershell
$nssm = "C:\Program Files\nssm\win64\nssm.exe"
$ollama = (Get-Command ollama.exe -ErrorAction Stop).Source
$serviceName = "LocalOllama"
$logDirectory = "C:\ProgramData\LocalOllama\logs"

New-Item `
  -ItemType Directory `
  -Path $logDirectory `
  -Force | Out-Null
```

## 6. OllamaをWindowsサービスとして登録する

NSSMから `ollama.exe serve` を直接起動します。

```powershell
& $nssm install $serviceName $ollama "serve"

& $nssm set $serviceName `
  DisplayName "Local Ollama API"

& $nssm set $serviceName `
  Description "Ollama OpenAI-compatible API on port 11434"

& $nssm set $serviceName `
  AppDirectory (Split-Path $ollama)

& $nssm set $serviceName `
  Start SERVICE_DELAYED_AUTO_START
```



## 7. 接続先とモデル保存先を設定する

同じPC上のアプリケーションからのみ使用する場合は、`127.0.0.1` で待ち受けます。

```powershell
$modelDirectory = Join-Path $env:USERPROFILE ".ollama\models"

& $nssm set $serviceName AppEnvironmentExtra `
  "OLLAMA_HOST=127.0.0.1:11434" `
  "OLLAMA_MODELS=$modelDirectory" `
  "CUDA_DEVICE_ORDER=PCI_BUS_ID" `
  "CUDA_VISIBLE_DEVICES=0"
```

`CUDA_VISIBLE_DEVICES` は使用するGPUの指定です（GPU 0 だけを使う場合は `0`）。`CUDA_DEVICE_ORDER=PCI_BUS_ID` を併せて指定することで、GPU番号が `nvidia-smi` の表示順と一致します。番号の代わりに `nvidia-smi -L` で表示されるUUID（`GPU-xxxxxxxx-...`）を指定すると、GPUの増減や差し替えがあっても対象がずれません。全GPUを使う場合はこの2行を削除します。

設定変更後はサービスの再起動が必要です。

```powershell
Restart-Service $serviceName
```

GPUの割り当ては次で確認できます。`ollama ps` の `PROCESSOR` 列が `100% GPU` であればフルGPU推論、`nvidia-smi` で対象GPUのみメモリが消費されていれば固定が効いています。

```powershell
ollama ps
nvidia-smi
```

接続先は次のとおりです。

```text
Ollama API:    http://127.0.0.1:11434
OpenAI互換API: http://127.0.0.1:11434/v1
```

別のPCから接続させる場合だけ、`OLLAMA_HOST=0.0.0.0:11434` を使用します。Ollama APIには通常の認証機構がないため、外部公開する場合はWindows Firewallで接続元IPを制限してください。

## 8. サービスの実行ユーザーを設定する

Ollama本体とモデルがユーザーディレクトリにある場合、サービスも同じWindowsユーザーで実行します。

NSSMの設定画面を開きます。

```powershell
& $nssm edit $serviceName
```

`Log on` タブで次を設定します。

```text
This account: .\<ユーザー名>
Password: Windowsアカウントのパスワード
```

Windows HelloのPINではなく、Windowsアカウントのパスワードを指定します。

`LocalSystem` で実行すると、ユーザーのモデルディレクトリやOllama実行ファイルを参照できない場合があります。本構成では、OllamaとモデルをセットアップしたWindowsユーザーを指定してください。

## 9. ログ出力を設定する

```powershell
& $nssm set $serviceName `
  AppStdout "$logDirectory\ollama-stdout.log"

& $nssm set $serviceName `
  AppStderr "$logDirectory\ollama-stderr.log"

& $nssm set $serviceName AppRotateFiles 1
& $nssm set $serviceName AppRotateBytes 10485760
& $nssm set $serviceName AppRotateSeconds 86400
```

ログは次の場所へ出力されます。

```text
C:\ProgramData\LocalOllama\logs\ollama-stdout.log
C:\ProgramData\LocalOllama\logs\ollama-stderr.log
```

## 10. 異常終了時の再起動を設定する

Ollamaが終了した場合、NSSMが5秒後に再起動します。

```powershell
& $nssm set $serviceName AppExit Default Restart
& $nssm set $serviceName AppRestartDelay 5000
```

NSSM自体が異常終了した場合に備えて、Windowsサービス側にも回復処理を設定します。

```powershell
sc.exe failure $serviceName `
  reset= 86400 `
  actions= restart/5000/restart/15000/restart/60000

sc.exe failureflag $serviceName 1
```

## 11. サービスを開始する

```powershell
& $nssm start $serviceName
```

状態を確認します。

```powershell
Get-Service $serviceName
& $nssm status $serviceName
```

`Running` または `SERVICE_RUNNING` と表示されれば起動しています。

起動できない場合はログとWindowsイベントログを確認します。

```powershell
Get-Content `
  -LiteralPath "$logDirectory\ollama-stderr.log" `
  -Tail 100

Get-WinEvent `
  -LogName Application `
  -MaxEvents 100 |
  Where-Object ProviderName -Match "nssm|Ollama"
```

## 12. APIを確認する

Ollama APIのバージョンを確認します。

```powershell
Invoke-RestMethod http://127.0.0.1:11434/api/version
```

OpenAI互換APIのモデル一覧を確認します。

```powershell
Invoke-RestMethod http://127.0.0.1:11434/v1/models
```

プロジェクトのテストスクリプトでも確認できます。

```powershell
Set-Location "C:\Users\<ユーザー名>\Desktop\scien-UandI\workspace"
.\scripts\test-chat.ps1
```

## 13. モデルをメモリへロードする

NSSMが永続化するのはOllamaサーバーです。Windows再起動直後は、モデルがGPUメモリへロードされていない場合があります。

デフォルトモデルをロードします。

```powershell
Set-Location "C:\Users\<ユーザー名>\Desktop\scien-UandI\workspace"
.\scripts\load-model.ps1
```

プロファイルを指定する場合は、次のように実行します。

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-32b-q4_K_M
```

ただし、再起動直後にモデルを事前ロードする必要がなければ、最初のAPIリクエスト時にOllamaがモデルをロードします。

## 14. 再起動後の検証

Windowsを再起動し、次を確認します。

```powershell
Get-Service LocalOllama

Invoke-RestMethod http://127.0.0.1:11434/api/version
Invoke-RestMethod http://127.0.0.1:11434/v1/models
```

確認項目は次のとおりです。

- `LocalOllama` が `Running` になっている
- ポート `11434` が応答する
- `/v1/models` がモデル一覧を返す
- `scripts/test-chat.ps1` が正常終了する
- Ollamaが異常終了してもNSSMが再起動する
- `C:\ProgramData\LocalOllama\logs` にログが出力される

## サービス管理コマンド

```powershell
$nssm = "C:\Program Files\nssm\win64\nssm.exe"
$serviceName = "LocalOllama"

# 状態確認
Get-Service $serviceName
& $nssm status $serviceName

# 開始
& $nssm start $serviceName

# 停止
& $nssm stop $serviceName

# 再起動
& $nssm restart $serviceName

# 設定変更
& $nssm edit $serviceName
```

## サービスを削除する

管理者PowerShellで実行します。

```powershell
$nssm = "C:\Program Files\nssm\win64\nssm.exe"
$serviceName = "LocalOllama"

& $nssm stop $serviceName
& $nssm remove $serviceName confirm
```

サービスを削除しても、Ollama本体、モデル、NSSM、ログファイルは削除されません。
