# Local LLM API

Windows 上の Ollama を使って、OpenAI API 互換の Local LLM API を構築します。

## 構成

- API server: Ollama
- 既定モデル: `qwen3-vl:32b-instruct-q4_K_M` (`qwen3-vl-32b-q4_K_M`)
- デフォルト:
  - `qwen3-vl:32b-instruct-q4_K_M`
- 参考:
  - `gpt-oss:20b`: chat-based の forensic benchmark で好成績。text のみ。
  - `qwen3.6:27b-q4_K_M`: より新しい Qwen 系列のモデル。text / image 両対応。
- モデル設定: `config/ollama-models.json`

- OpenAI互換
```text
Base URL: http://localhost:11434/v1
Chat endpoint: http://localhost:11434/v1/chat/completions
Model: qwen3-vl:32b-instruct-q4_K_M
```

- Ollama protocol
```text
Base URL: http://localhost:11434
Chat endpoint: http://localhost:11434/api/chat
Model: qwen3-vl:32b-instruct-q4_K_M
```

## 前提

- Windows 11
- NVIDIA GPU
- Ollama for Windows がインストール済み
  - `irm https://ollama.com/install.ps1 | iex`
- PowerShell でこのリポジトリ内に移動

## 1. Ollama を起動

```powershell
.\scripts\start-ollama-server.ps1
```

## 2. モデル設定ファイル

モデル設定は `config/ollama-models.json` で管理します。

主な項目は以下です。

- `ollamaHost`: Ollama native API の接続先
- `openAiBaseUrl`: OpenAI互換 API の接続先
- `defaultProfile`: プロファイル未指定時に使う profile 名
- `profiles`: 利用可能なモデル profile の一覧

各 profile には以下を設定します。

- `model`: Ollama に渡す実際のモデル名
- `purpose`: その profile の用途説明
- `keepAlive`: モデルをメモリに保持する時間。`-1m` は自動アンロードしない指定
- `notes`: 補足説明

デフォルトモデルを変更する場合は、`defaultProfile` を変更します。値には `profiles` 配下に存在する profile 名を指定します。

- gpt-oss-20b に変更する場合
```json
{
  "defaultProfile": "gpt-oss-20b"
}
```

モデルを追加する場合は、`profiles` に新しい profile を追加します。profile 名はスクリプトで指定する名前、`model` は Ollama のモデル名です。

```json
{
  "profiles": {
    "new-model-profile": {
      "model": "ollama-model-name:tag",
      "purpose": "short purpose",
      "keepAlive": "-1m",
      "notes": "optional notes"
    }
  }
}
```

追加したモデルを取得・ロードする場合:

```powershell
.\scripts\setup-ollama.ps1 -Profile new-model-profile
.\scripts\load-model.ps1 -Profile new-model-profile
```

## 3. モデルを取得

プロファイル未指定の場合、デフォルトの `qwen3-vl-32b-q4_K_M` を取得します。

```powershell
.\scripts\setup-ollama.ps1
```

デフォルト以外のモデルを取得する場合は、必要なモデルだけを個別に指定します。

```powershell
.\scripts\setup-ollama.ps1 -Profile gpt-oss-20b
.\scripts\setup-ollama.ps1 -Profile qwen3.6-27b-q4_K_M
```

## 4. モデルをロードして保持

プロファイル未指定の場合、`config/ollama-models.json` の `defaultProfile`、つまり `qwen3-vl-32b-q4_K_M` を使います。

```powershell
.\scripts\load-model.ps1
```

プロファイルを指定するとき、
```powershell
.\scripts\load-model.ps1 -Profile gpt-oss-20b
.\scripts\load-model.ps1 -Profile qwen3.6-27b-q4_K_M
```

各プロファイルの `keepAlive` は `-1m` です。Ollama の `keep_alive` に負の値を渡すことで、Ollama がモデルを自動アンロードしないようにします。

一時的に保持時間を変える場合:

```powershell
.\scripts\load-model.ps1 -KeepAlive 30m
```

Windows 再起動、Ollama 終了、GPU メモリ不足、手動アンロード時にはモデルはメモリから外れます。

## 5. API の疎通確認

```powershell
.\scripts\test-chat.ps1
```

プロンプトを指定して確認する場合:

```powershell
.\scripts\test-chat.ps1 -Prompt "Say hello world in one short sentence."
```

## 6. モデルを切り替える

gpt-oss に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile gpt-oss-20b
.\scripts\test-chat.ps1 -Profile gpt-oss-20b
```

Qwen3.6-27b に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile qwen3.6-27b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3.6-27b-q4_K_M
```

Qwen3-32b-VL に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-32b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3-vl-32b-q4_K_M
```

## モデルをメモリから下ろす

```powershell
.\scripts\unload-model.ps1 -Profile qwen3-vl-32b-q4_K_M
.\scripts\unload-model.ps1 -Profile gpt-oss-20b
.\scripts\unload-model.ps1 -Profile qwen3.6-27b-q4_K_M
```
