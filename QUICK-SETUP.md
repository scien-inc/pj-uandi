# Quick Setup

Windows 11 で Ollama for Windows をインストールした後、以下を実行します。

OllamaがまだインストールされていないPCでは、`-InstallOllama` を付けることでインストールできます。

デフォルトのプロファイル（`qwen3-vl-8b-q4_K_M` / `qwen3-vl:8b-instruct-q4_K_M`）を自動選択します。
使用するGPUも自動選択され、VRAM の大きい GPU（RTX 5000 Ada 32GB）に固定されます。

```powershell
.\quick-setup.cmd
```

## オプション

別のモデルプロファイルを選択する場合:

```powershell
.\quick-setup.cmd -Profile qwen3-vl-4b-q4_K_M
.\quick-setup.cmd -Profile gpt-oss-20b
```

選択されるGPUを事前に確認する場合:

```powershell
.\scripts\show-gpus.ps1
```

モデルの再取得を省略する場合:

```powershell
.\quick-setup.cmd -SkipPull
```

API 疎通確認を省略する場合:

```powershell
.\quick-setup.cmd -SkipTest
```
