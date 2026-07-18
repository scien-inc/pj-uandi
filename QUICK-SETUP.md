# Quick Setup

Windows 11 で Ollama for Windows をインストールした後、リポジトリ直下から次のどちらか一方を実行します。

OllamaがまだインストールされていないPCでは、公式インストーラーの実行を含めて次の1コマンドでセットアップできます。

```powershell
.\quick-setup.cmd -InstallOllama
```

## ファイルを実行する

エクスプローラーから `quick-setup.cmd` を実行するか、PowerShell で次を実行します。

```powershell
.\quick-setup.cmd
```

## PowerShell コマンドを1つ実行する

```powershell
.\scripts\quick-setup.ps1
```

Quick Setup は次の処理を順番に実行します。

1. Ollama API サーバーを起動
2. 既定モデルを取得
3. モデルを GPU メモリにロードして保持
4. OpenAI 互換 API (`http://localhost:11434/v1`) の疎通を確認

`-InstallOllama` を指定し、Ollama CLIが見つからない場合は、最初に `https://ollama.com/install.ps1` の公式インストーラーを実行します。既に導入済みの場合、このオプションは何も変更しません。

途中で失敗した場合はその時点で停止し、終了コード `1` を返します。再実行しても、起動済みのサーバーと取得済みのモデルは再利用されます。

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

実行予定のコマンドだけを確認する場合:

```powershell
.\quick-setup.cmd -DryRun
```

`-InstallOllama` を付けずにOllama CLIが見つからない場合は、自動インストールを行わず、実行可能なインストール方法を表示して終了します。
