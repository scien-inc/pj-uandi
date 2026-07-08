# Local LLM API

Windows 上の Ollama を使って、OpenAI API 互換の Local LLM API を構築します。

## 構成

- API server: Ollama
- 初期確認モデル: `qwen3:8b`
- Qwen3-32b: `qwen3:32b`
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

## 2. qwen3:8b を取得

```powershell
.\scripts\setup-ollama.ps1 -Profile qwen3-8b
```

## 3. qwen3:8b をロード

```powershell
.\scripts\load-model.ps1 -Profile qwen3-8b
```

## 4. API の疎通確認

```powershell
.\scripts\test-chat.ps1 -Profile qwen3-8b
```

（プロンプトを指定して確認する場合）:

```powershell
.\scripts\test-chat.ps1 -Profile qwen3-8b -Prompt "Say hello world in one short sentence."
```

## 5. qwen3:32b に切り替える

```powershell
.\scripts\setup-ollama.ps1 -Profile qwen3-32b
.\scripts\load-model.ps1 -Profile qwen3-32b
.\scripts\test-chat.ps1 -Profile qwen3-32b
```

OpenAI互換 API では、リクエストの `model` を変えるだけでモデルを切り替えます。

```json
{
  "model": "qwen3:32b",
  "messages": [
    { "role": "user", "content": "日本語で短く要約してください。" }
  ]
}
```

## モデルをメモリから下ろす

```powershell
.\scripts\unload-model.ps1 -Profile qwen3-8b
.\scripts\unload-model.ps1 -Profile qwen3-32b
```
