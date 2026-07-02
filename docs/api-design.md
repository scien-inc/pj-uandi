# Ollama OpenAI互換 API 設計

## 方針

初期実装では独自 API プロキシを作らず、Ollama の OpenAI互換 API をそのまま Nuix から呼び出す。理由は、要件が `Windows native`、`WSL不使用`、`11434番ポート`、`OpenAI API互換` であり、Ollama がこの境界を最小構成で満たせるため。

## API 境界

- Base URL: `http://localhost:11434/v1`
- API key: `ollama`
  - OpenAI SDK 互換クライアントでは必須項目だが、Ollama 側では実質利用しない。
- Chat endpoint: `POST /v1/chat/completions`
- Model list endpoint: `GET /v1/models`

Nuix が Ollama native API を要求する場合のみ、次も確認対象にする。

- Native chat endpoint: `POST /api/chat`
- Native model preload/unload endpoint: `POST /api/generate`

## モデルプロファイル

| Profile | Ollama model | 目的 |
| --- | --- | --- |
| `qwen3-8b` | `qwen3:8b` | ローカル疎通確認、軽量PoC、速度検証 |
| `qwen3-32b` | `qwen3:32b` | 要件にある32B級モデルの品質検証 |

OpenAI互換 API では、モデル切替はリクエスト body の `model` 値で行う。リポジトリ側では `config/ollama-models.json` の profile を使って、PowerShell スクリプトから同じモデル名を参照する。

## モデルロード

Ollama はモデルを使ったタイミングでロードする。初回応答を安定させたい場合は、事前に native API の `/api/generate` へ空の生成リクエストを送り、`keep_alive` を指定してメモリ上に保持する。

このリポジトリでは以下でロードする。

```powershell
.\scripts\load-model.ps1 -Profile qwen3-8b
.\scripts\load-model.ps1 -Profile qwen3-32b
```

アンロードは以下。

```powershell
.\scripts\unload-model.ps1 -Profile qwen3-8b
.\scripts\unload-model.ps1 -Profile qwen3-32b
```

## Nuix 側設定案

同一 Windows ワークステーション上の Nuix から呼ぶ場合:

- URL / Base URL: `http://localhost:11434/v1`
- Model: `qwen3:8b` または `qwen3:32b`
- API key: `ollama`

別ホストの Nuix から呼ぶ場合:

- URL / Base URL: `http://<LLMサーバーIP>:11434/v1`
- Windows Firewall と Ollama の bind 設定を別途確認する。

## 疎通確認

```powershell
.\scripts\test-openai-chat.ps1 -Profile qwen3-8b
.\scripts\test-openai-chat.ps1 -Profile qwen3-32b
```

成功すれば、hello world 程度の短い回答が返る。
