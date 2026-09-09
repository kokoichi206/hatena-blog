# uv run --with の使い方：単発の Python スクリプトに依存を追加する

PDF を扱う短い Python スクリプトを動かしたとき、`ModuleNotFoundError: No module named 'pypdf'` で止まりました。

そのときに使ったのが `uv run --with` です。実行時に必要なライブラリを指定できるので、PDF のページ数を調べるような単発の処理で使っています。

<!-- more -->

## まず動かすなら、このコマンド

`pypdf` を使う `count_pages.py` は、次のように実行できます。末尾の `sample.pdf` はスクリプトに渡す引数です。

```bash
uv run --no-project --with pypdf python count_pages.py sample.pdf
```

`--with pypdf` で、この実行に必要な依存を追加します。`--no-project` は、作業フォルダにある別の Python プロジェクトの依存を読み込まないために付けています。

以下の例は uv 0.11.2、Python 3.13.1、pypdf 6.18.0 で動作を確認しました。uv はインストール済みの前提です。未導入なら [公式のインストール手順](https://docs.astral.sh/uv/getting-started/installation/)を参照してください。

## PDF のページ数を数える例

`count_pages.py` に、次のコードを書きます。

```python
import sys

from pypdf import PdfReader

reader = PdfReader(sys.argv[1])
print(f"{len(reader.pages)} pages")
```

`pypdf` が入っていない Python 環境で実行すると、import の時点で止まります。

```bash
python count_pages.py sample.pdf
```

```text
ModuleNotFoundError: No module named 'pypdf'
```

同じファイルを `uv run --with` 経由で動かします。

```bash
uv run --no-project --with pypdf python count_pages.py sample.pdf
```

手元で用意した 2 ページの PDF では、次の結果になりました。

```text
2 pages
```

uv が依存を用意した環境で Python を起動するため、事前に仮想環境を作ったり、activate したりする手順を省けます。普段使っている Python に `pip install` する必要もありません。

試す PDF がなければ、次の `make_sample.py` で空白の 2 ページを作れます。実行先に `sample.pdf` を書き出します。

```python
from pypdf import PdfWriter

writer = PdfWriter()
writer.add_blank_page(width=200, height=200)
writer.add_blank_page(width=200, height=200)
writer.write("sample.pdf")
```

```bash
uv run --no-project --with pypdf python make_sample.py
```

## ライブラリが複数あるとき・バージョンを指定したいとき

PDF の生成に `reportlab`、読み取りに `pypdf` を使う場合は、`--with` を繰り返します。これは実際の PDF 作業でも使った組み合わせです。

```bash
uv run --no-project --with pypdf --with reportlab python your_script.py
```

`your_script.py` は、自分のスクリプト名に置き換えます。動作を確認したバージョンに固定する場合は、パッケージ名の後ろに `==` を付けます。

```bash
uv run --no-project --with 'pypdf==6.18.0' python count_pages.py sample.pdf
```

バージョン指定や複数の依存を渡す書式は、[uv のスクリプト実行ガイド](https://docs.astral.sh/uv/guides/scripts/#running-a-script-with-dependencies)にも載っています。

## pyproject.toml がある場所では --no-project を付ける

`uv run` は通常、見つかったプロジェクトの環境を使います。プロジェクト内で `--with pypdf` を指定した場合、そのプロジェクトの依存に加えて `pypdf` を使うことになります。

別のリポジトリで作業中に、PDF を調べるスクリプトだけ動かすこともあります。その用途では `--no-project` を付け、プロジェクトのセットアップを切り離しています。

実際に、無関係な依存を書いた `pyproject.toml` のあるフォルダでも試しました。`--no-project` を付けたコマンドは PDF を読み取れ、そのフォルダに `.venv` や `uv.lock` は作られませんでした。

## 繰り返し使うなら、依存をスクリプトに書く

何度も使うファイルでは、実行するたびに `--with` を指定するより、必要な依存をファイルに残した方が扱いやすいです。

`count_pages.py` の先頭に、次のコメントを追加します。この書式は PEP 723 のインラインメタデータです。

```python
# /// script
# requires-python = ">=3.9"
# dependencies = ["pypdf==6.18.0"]
# ///

import sys

from pypdf import PdfReader

reader = PdfReader(sys.argv[1])
print(f"{len(reader.pages)} pages")
```

以降は `--with` を省いて実行できます。

```bash
uv run count_pages.py sample.pdf
```

この書き方でも `2 pages` と出力されました。通常の Python にはコメントとして扱われるため、依存の準備まで任せるときは `python count_pages.py` ではなく `uv run count_pages.py` で起動します。

[インラインメタデータを使う場合](https://docs.astral.sh/uv/guides/scripts/#declaring-script-dependencies)は、プロジェクトの依存が使われないため `--no-project` も不要です。手元でも、同じフォルダにある `pyproject.toml` の依存を読み込まず実行できました。

## VSCode の補完・定義ジャンプは別に設定する

ここで解決したのは、スクリプトを実行する環境の依存不足です。`uv run --with` で実行できても、VSCode が解析に使う Python まで同じになるわけではありません。

実行はできるのに import に警告が出る、ライブラリの定義にジャンプできない場合は、VSCode で選んでいるインタープリターを確認します。こちらは [Python の定義ジャンプができないときの記事](https://koko206.hatenablog.com/entry/2023/11/16/022040)にまとめています。

一度動かすなら `--with` だけで済みます。後からスクリプトを見返したときにも依存が分かるようにしておくなら、PEP 723 でファイルに残せます。
