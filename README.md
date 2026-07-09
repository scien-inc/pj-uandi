# Local LLM API

Windows 上の Ollama を使って、OpenAI API 互換の Local LLM API を構築します。

## 構成

- API server: Ollama
- 既定モデル: `qwen3-vl:32b-instruct-q4_K_M` (`qwen3-vl-32b-q4_K_M`)
- デフォルト:
  - `qwen3-vl:32b-instruct-q4_K_M`
- 参考:
  - `gpt-oss:20b`: 安定して強い。chat-based のforensics benchmark で好成績。textのみ。
  - `qwen3.6:27b-q4_K_M`: より新しいQwen系列のモデル。text, image両対応。
- モデル設定: `config/ollama-models.json`
```text
OpenAI互換: POST http://localhost:11434/v1/chat/completions
Ollama protocol: POST http://localhost:11434/api/chat
```

## 前提

- Windows 11
- NVIDIA GPU
- Ollama for Windows がインストール済み
  -  `irm https://ollama.com/install.ps1 | iex`
- PowerShell でこのリポジトリ内に移動

## 1. Ollama を起動

```powershell
.\scripts\start-ollama-server.ps1
```

## 2. モデルを取得

プロファイル未指定の場合、デフォルトのモデル `qwen3-vl-32b-q4_K_M` を使います。

```powershell
.\scripts\setup-ollama.ps1
```

参考に示したような、デフォルト以外のモデルを指定して取得する場合は、以下のように指定します。

```powershell
.\scripts\setup-ollama.ps1 -Profile gpt-oss-20b
.\scripts\setup-ollama.ps1 -Profile qwen3.6-27b-q4_K_M
```

## 3. モデルをロード

プロファイル未指定の場合、 `config/ollama-models.json` の `defaultProfile`、つまり `qwen3-vl-32b-q4_K_M` を使います。

```powershell
.\scripts\load-model.ps1
```

## 4. API の疎通確認

```powershell
.\scripts\test-chat.ps1
```

（プロンプトを指定して確認する場合）:

```powershell
.\scripts\test-chat.ps1 -Prompt "Say hello world in one short sentence."
```

## 5. モデルを切り替える
gpt-oss に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile gpt-oss-20b
.\scripts\test-chat.ps1 -Profile gpt-oss-20b
```

Qwen3.6-27b に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile qwen3.6-27b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3.6-27b-q4_K_M

Qwen3-32b-VL に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-32b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3-vl-32b-q4_K_M
```

## Windows ログオン時に常時起動する

Ollama for Windows はユーザー環境にインストールされることが多いため、このリポジトリでは Windows Task Scheduler の「ユーザーログオン時」タスクを標準にします。

まず、常時稼働用の起動処理を手動で確認します。

```powershell
.\scripts\run-ollama-runtime.ps1
```

このスクリプトは以下を実行します。

- Ollama server を `http://localhost:11434` で起動または確認
- 指定 profile のモデルをロード
- `GET /v1/models` と `POST /v1/chat/completions` を確認
- 実行ログを `logs\` 配下に保存
- `ollama ps` と、利用可能な場合は `nvidia-smi` の結果を表示

ログオン時の自動起動タスクを登録します。

```powershell
.\scripts\install-startup-task.ps1 -StartNow
```

登録されたタスクはウォッチモードで常駐し、既定では 5分ごとに Ollama server、モデルロード、OpenAI互換 API を確認します。落ちている場合は再起動または再ロードを試みます。

既定のタスク名は `LocalLlmOllamaRuntime` です。設定値は `config/ollama-models.json` の `runtime` で管理します。

状態確認:

```powershell
.\scripts\status-startup-task.ps1
```

ログ確認:

```powershell
Get-ChildItem .\logs\ollama-runtime-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 120
```

自動起動タスクを削除する場合:

```powershell
.\scripts\uninstall-startup-task.ps1
```

常時稼働時の既定 `keep_alive` は `24h` です。変更する場合は `config/ollama-models.json` の `runtime.keepAlive` を変更するか、登録時に次のように指定します。

```powershell
.\scripts\install-startup-task.ps1 -KeepAlive 8h -StartNow
```

監視間隔を変える場合:

```powershell
.\scripts\install-startup-task.ps1 -CheckIntervalSeconds 600 -StartNow
```

ウォッチモードを使わず、ログオン時に一度だけ起動処理を実行する場合:

```powershell
.\scripts\install-startup-task.ps1 -NoWatch -StartNow
```

Nuix Neo など OpenAI 互換クライアント側には、次を設定します。

```text
Base URL: http://localhost:11434/v1
Chat endpoint: http://localhost:11434/v1/chat/completions
Model: qwen3-vl:32b-instruct-q4_K_M
```

## モデルをメモリから下ろす

```powershell
.\scripts\unload-model.ps1 -Profile qwen3-vl-32b-q4_K_M
.\scripts\unload-model.ps1 -Profile gpt-oss-20b
.\scripts\unload-model.ps1 -Profile qwen3.6-27b-q4_K_M
```
