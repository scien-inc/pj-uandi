# Quick Setup

Windows 11 で Ollama for Windows をインストールした後、以下を実行します。

OllamaがまだインストールされていないPCでは、`-InstallOllama` を付けることでインストールできます。

デフォルトのプロファイルを自動選択します。

```powershell
.\quick-setup.cmd
```

## オプション

別のモデルプロファイルを選択する場合:

```powershell
.\quick-setup.cmd -Profile gpt-oss-20b
```

モデルの再取得を省略する場合:

```powershell
.\quick-setup.cmd -SkipPull
```

API 疎通確認を省略する場合:

```powershell
.\quick-setup.cmd -SkipTest
```
