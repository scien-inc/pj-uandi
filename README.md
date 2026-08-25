# Local LLM API

Windows 上の Ollama を使って、OpenAI API 互換の Local LLM API を構築します。
quick-setup.cmd で簡単にセットアップできます（何かしらエラーが出る場合、手動セットアップで確認するとよいです）。

## 構成

- API server: Ollama
- 既定モデル: `qwen3-vl:8b-instruct-q4_K_M` (`qwen3-vl-8b-q4_K_M`)
  - 約 6GB。text / image 両対応。32B 版と同じ Qwen3-VL 系列で、動作が大幅に軽量です。
- 参考（軽い順）:
  - `qwen3-vl:4b-instruct-q4_K_M`: 約 3GB。8B でも重い場合や、12GB の GPU で動かす場合に使用します。
  - `gpt-oss:20b`: 約 14GB。chat-based の forensic benchmark で好成績。text のみ。
  - `qwen3-vl:30b-a3b-instruct-q4_K_M`: 約 20GB。MoE（有効パラメータ約 3B）のため、VRAM 使用量の割に応答が速いモデルです。品質を上げたいが速度も欲しい場合に使用します。
  - `qwen3-vl:32b-instruct-q4_K_M`: 約 21GB。以前の既定モデル。品質は最も高いですが dense 32B のため最も遅くなります。
  - `qwen3.6:27b-q4_K_M`: より新しい Qwen 系列のモデル。text / image 両対応。
- モデル設定: `config/ollama-models.json`

- OpenAI互換
```text
Base URL: http://localhost:11434/v1
Chat endpoint: http://localhost:11434/v1/chat/completions
Model: qwen3-vl:8b-instruct-q4_K_M
```

- Ollama protocol
```text
Base URL: http://localhost:11434
Chat endpoint: http://localhost:11434/api/chat
Model: qwen3-vl:8b-instruct-q4_K_M
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
- `cudaVisibleDevices`: 使用するGPUの指定。`"auto"` で自動選択、`"0"` のように番号や UUID を書くと固定、空文字 `""` で全GPU使用
- `preferredGpuNamePattern`: `"auto"` のときに優先するGPU名（部分一致・正規表現）
- `defaultProfile`: プロファイル未指定時に使う profile 名（普段使用するモデルを設定してあげるとよいです）
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

### GPU の指定

GPU が複数ある環境では、VRAM の大きい GPU に固定したほうが安定します。本リポジトリの想定環境は次の 2 枚構成で、**NVIDIA RTX 5000 Ada (32GB)** を優先して使用します。

```text
NVIDIA RTX 5000 Ada Generation  32GB  <- 優先して使用
NVIDIA RTX A2000                12GB
```

既定値は自動選択です。

```json
{
  "cudaVisibleDevices": "auto",
  "preferredGpuNamePattern": "RTX 5000 Ada"
}
```

`"auto"` のとき、`nvidia-smi` で検出した GPU から次の順で 1 枚を選びます。

1. `preferredGpuNamePattern` に名前が一致する GPU（複数一致した場合は VRAM が最大のもの）
2. 一致しない場合は VRAM が最大の GPU

選ばれた GPU は番号ではなく UUID (`GPU-xxxxxxxx-...`) で固定するため、GPU の増設や差し替え、ドライバー更新で番号がずれても対象が変わりません。

どの GPU が選択されるかは、起動前に確認できます。

```powershell
.\scripts\show-gpus.ps1
```

```text
Detected GPUs ('*' is the one Ollama will be pinned to):

Use Index Name                           VRAM_GB Uuid
--- ----- ----                           ------- ----
        0 NVIDIA RTX A2000                  12.0 GPU-xxxxxxxx-...
*       1 NVIDIA RTX 5000 Ada Generation    32.0 GPU-yyyyyyyy-...
```

自動選択を使わず GPU を直接指定する場合は、`cudaVisibleDevices` に番号または UUID を書きます。番号は `nvidia-smi` の表示順です。

```json
{
  "cudaVisibleDevices": "GPU-yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
}
```

全GPUを使用する場合は空文字にします。

```json
{
  "cudaVisibleDevices": ""
}
```

この設定は `start-ollama-server.ps1` がサーバーを起動するときに適用されます。Ollama が既に起動している場合（タスクトレイ常駐など）は反映されないため、一度停止してから起動し直してください。

```powershell
.\scripts\stop-ollama-server.ps1
.\scripts\start-ollama-server.ps1
.\scripts\load-model.ps1
```

GPUの割り当ては次で確認できます。

```powershell
ollama ps      # PROCESSOR 列が「100% GPU」ならフルGPU推論
nvidia-smi     # 対象GPUのみメモリが消費されていれば固定が効いている
```

NSSM サービスとして運用する場合、この設定は使われません。`windows-nssm-ollama.md` の手順でサービスの環境変数として設定します。

## 3. モデルを取得

プロファイル未指定の場合、デフォルトの `qwen3-vl-8b-q4_K_M` を取得します。

```powershell
.\scripts\setup-ollama.ps1
```

デフォルト以外のモデルを取得する場合は、必要なモデルだけを個別に指定します。

```powershell
.\scripts\setup-ollama.ps1 -Profile qwen3-vl-4b-q4_K_M
.\scripts\setup-ollama.ps1 -Profile gpt-oss-20b
.\scripts\setup-ollama.ps1 -Profile qwen3-vl-30b-a3b-q4_K_M
```

## 4. モデルをロードして保持

プロファイル未指定の場合、`config/ollama-models.json` の `defaultProfile`、つまり `qwen3-vl-8b-q4_K_M` を使います。

```powershell
.\scripts\load-model.ps1
```

プロファイルを指定するとき、
```powershell
.\scripts\load-model.ps1 -Profile gpt-oss-20b
.\scripts\load-model.ps1 -Profile qwen3-vl-30b-a3b-q4_K_M
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

さらに軽くしたい場合（Qwen3-VL 4B）:

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-4b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3-vl-4b-q4_K_M
```

gpt-oss に切り替える場合:

```powershell
.\scripts\load-model.ps1 -Profile gpt-oss-20b
.\scripts\test-chat.ps1 -Profile gpt-oss-20b
```

品質を上げたい場合（Qwen3-VL 30B-A3B、MoE のため 32B より高速）:

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-30b-a3b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3-vl-30b-a3b-q4_K_M
```

以前の既定モデル（Qwen3-VL 32B）に戻す場合:

```powershell
.\scripts\load-model.ps1 -Profile qwen3-vl-32b-q4_K_M
.\scripts\test-chat.ps1 -Profile qwen3-vl-32b-q4_K_M
```

複数のモデルを同時にロードすると GPU メモリを取り合うため、切り替える前に使っていないモデルをアンロードしてください。

## モデルをメモリから下ろす

```powershell
.\scripts\unload-model.ps1 -Profile qwen3-vl-8b-q4_K_M
.\scripts\unload-model.ps1 -Profile qwen3-vl-4b-q4_K_M
.\scripts\unload-model.ps1 -Profile gpt-oss-20b
.\scripts\unload-model.ps1 -Profile qwen3-vl-30b-a3b-q4_K_M
.\scripts\unload-model.ps1 -Profile qwen3-vl-32b-q4_K_M
```

サーバーは起動したまま、モデルだけがメモリから外れます。

## Ollama を停止する

```powershell
.\scripts\stop-ollama-server.ps1
```

サーバーごと停止します。Windows サービスとして登録されている場合はサービスを停止し、そうでない場合はプロセス（タスクトレイの `ollama app` とサーバーの `ollama`）を終了します。`cudaVisibleDevices` などサーバー起動時に読まれる設定を変更したときは、このスクリプトで停止してから起動し直してください。

停止できたかどうかは次で確認できます。

```powershell
Get-Process ollama* -ErrorAction SilentlyContinue                    # 何も返らなければ停止済み
Get-NetTCPConnection -LocalPort 11434 -ErrorAction SilentlyContinue  # 11434 が空いているか
```
