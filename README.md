# Nuix Local LLM API

Windows 上の Ollama を使って、Nuix から呼べる OpenAI API 互換のLocal LLM API を構築する最小構成。

## 構成

- API server: Ollama
- OpenAI互換 URL: `http://localhost:11434/v1`
- 初期確認モデル: `qwen3:8b`
- Qwen3-32b: `qwen3:32b`
- モデル設定: `config/ollama-models.json`

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

## 4. OpenAI互換 API の疎通確認

```powershell
.\scripts\test-openai-chat.ps1 -Profile qwen3-8b
```

（プロンプトを指定して確認する場合）:

```powershell
.\scripts\test-openai-chat.ps1 -Profile qwen3-8b -Prompt "Say hello world in one short sentence."
```

内部では次の API を呼びます。

```text
POST http://localhost:11434/v1/chat/completions
model: qwen3:8b
```

## 5. qwen3:32b に切り替える

32B はモデルサイズが大きいため、まだ動作未確認

```powershell
.\scripts\setup-ollama.ps1 -Profile qwen3-32b
.\scripts\load-model.ps1 -Profile qwen3-32b
.\scripts\test-openai-chat.ps1 -Profile qwen3-32b
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
