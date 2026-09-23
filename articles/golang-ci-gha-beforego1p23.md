# Go 1.23 以前での Golangci-lint のバージョン管理方法

業務の Go バックエンドで、ローカルと GitHub Actions の golangci-lint の版が別々に書いてありました。Makefile は `v1.59.1` と `@latest`、workflow は `v1.60.3` です。同じリポジトリなのに、見る場所で linter が違います。

Go 1.23 には `tool` ディレクティブがありません。`//go:build tools` の空インポートで `go.mod` に載せました。CI では、その版を action へ渡します。Go 1.24 以降は `tool` ディレクティブで、この空インポート用のファイルは要らなくなります。

<!-- more -->

## 目次

- [環境](#環境)
- [この記事で伝えたいこと](#この記事で伝えたいこと)
- [ずれていたところ](#ずれていたところ)
- [tools.go で go.mod に載せる](#toolsgo-で-gomod-に載せる)
- [ローカルは版を付けずに go run する](#ローカルは版を付けずに-go-run-する)
- [CI の goinstall は go.mod を見ない](#ci-の-goinstall-は-gomod-を見ない)
- [Go 1.24 以降は tool ディレクティブ](#go-124-以降は-tool-ディレクティブ)
- [公式はリリースバイナリを推奨している](#公式はリリースバイナリを推奨している)
- [おわりに](#おわりに)

## 環境

コードは非公開のリポジトリです。要点だけ抜きます。日付は、その変更を入れたコミットのものです。

| 対象 | バージョン |
| --- | --- |
| Go | 1.23（`toolchain` は `go1.23.3`） |
| golangci-lint | v1.62.0（`go.mod` に載せた時点） |
| golangci-lint-action | v6 |
| actions/setup-go | v5 |

action の `@v6` は浮動タグです。ソースを見たタグは、本文のリンク先に書いています。

## この記事で伝えたいこと

版の置き場所は、`go.mod` の require です。ローカルの `go run` はそこを使い、CI には同じ版を渡します。

`uses:` が指す action の ref と、実際に走る lint 本体の版は別です。ここでは本体の話だけです。

## ずれていたところ

Makefile には、インストール用の固定版と、実行用の `@latest` が両方ありました。

```makefile
EXTERNAL_TOOLS := \
	github.com/golangci/golangci-lint/cmd/golangci-lint@v1.59.1 \
	github.com/air-verse/air@latest

define golangci
	go run github.com/golangci/golangci-lint/cmd/golangci-lint@latest
endef
```

workflow はまた別の版です。

```yaml
- uses: golangci/golangci-lint-action@v6
  with:
    working-directory: ./backend
    version: v1.60.3
```

`@latest` は、実行のたびに変わり得ます。直書きの版は、直した人しか更新しません。

## tools.go で go.mod に載せる

[Go の依存関係のドキュメント](https://go.dev/doc/modules/managing-dependencies#tools)は、1.24 より前のやり方として、ビルドタグで通常のビルドから外したファイルに空インポートを書く、と説明しています。2024-11-22 に、それを足しました。

```go
//go:build tools

package tools

import (
	_ "github.com/air-verse/air"
	_ "github.com/golangci/golangci-lint/cmd/golangci-lint"
)
```

[`go mod tidy` は `ignore` 以外のビルドタグを有効にした扱い](https://go.dev/ref/mod#go-mod-tidy)でパッケージを見ます。`//go:build tools` のインポートも依存に残ります。test ジョブの `go mod tidy -diff` は、`tools.go` を残したまま require だけ消すと差分になります。

この変更のあと、`go.mod` は `go 1.23`、`toolchain go1.23.3`、golangci-lint は `v1.62.0` になりました。linter の推移的依存も、同じ `go.mod` に入ります。アプリケーションの依存と混ざります。

## ローカルは版を付けずに go run する

[`go run` に `@v1.62.0` や `@latest` を付けると、カレントの `go.mod` を使わず、その版を別モジュールとして取ります](https://pkg.go.dev/cmd/go#hdr-Compile_and_run_Go_program)。付けなければ、今のモジュールの require が使われます。

```makefile
.PHONY: lint
lint: ## golangci を使って lint を走らせる。
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run -v
```

空インポートが無いと、`go mod tidy` が require を消し、この `go run` はパッケージを解決できなくなります。`tools.go` はそのためのファイルです。

## CI の goinstall は go.mod を見ない

`tools.go` を入れたコミットで、action は `install-mode: goinstall` に変えました。このモードは次を実行します。

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@${version}
```

[`v6.2.0` の `src/version.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.2.0/src/version.ts)では、`goinstall` の分岐が `go.mod` を読む処理より前に return します。`version` が空なら `@latest` です。[`v6.5.0` の `src/install.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.5.0/src/install.ts)が、その版を `@` の後ろに付けています。

[`go install` も、引数に版が付くとカレントの `go.mod` を無視します](https://pkg.go.dev/cmd/go#hdr-Compile_and_install_packages_and_dependencies)。

binary（既定）で `version` を空にすると、作業ディレクトリの `go.mod` から `github.com/golangci/golangci-lint` の直後の版を読みます。同じ v6.2.0 にその処理はあります。`goinstall` を選んでいる間は使われません。

2024-12-03 に、workflow から `version: v1.61.0` を外しました。コミットメッセージは「don't select lint version in backend-ci」です。外したままだと、上の実装では CI が `@latest` になります。ローカルの `go run` は `go.mod` の版です。

2025-01-02 に、コミットメッセージ「ci で使う golangci のバージョンを local のものと合わせる」で、`go.mod` から取り出して渡すようにしました。ジョブの `working-directory` は `./backend` なので、読むのはそこにある `go.mod` です。

```yaml
- name: Check golangci-lint version
  id: golang_ci_version
  run: |
    version=$(cat go.mod | grep 'github.com/golangci/golangci-lint' | awk '{print $2}')
    echo "version=${version}" >> $GITHUB_OUTPUT

- name: golangci-lint
  uses: golangci/golangci-lint-action@v6
  with:
    working-directory: ./backend
    install-mode: goinstall
    version: ${{ steps.golang_ci_version.outputs.version }}
```

grep は、その文字列を含む行を全部拾います。require が 1 行なら、2 列目が `v1.62.0` です。行が 2 つあると、出力が改行を含んで `version` として壊れます。

揃うのは golangci-lint のモジュール版です。ローカルの `go run`（版なし）は今のモジュールの依存解決を使い、CI の `go install @版` はその版のモジュールを単独でビルドします。依存の選択や、成果物のバイナリそのものは一致しません。

## Go 1.24 以降は tool ディレクティブ

[Go 1.24](https://go.dev/doc/go1.24#tools)で `tool` ディレクティブが入りました。`tools.go` は要りません。

```bash
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint@v1.62.0
```

`go.mod` にはパッケージパスだけの行が足されます。版は require に残ります。

```text
tool github.com/golangci/golangci-lint/cmd/golangci-lint
```

実行は次です。名前が他のツールや、Go に同梱のツールとぶつかるときは、フルパスを渡します。

```bash
go tool golangci-lint run
```

手順は [依存関係のドキュメント](https://go.dev/doc/modules/managing-dependencies#tools)にあります。上のパッケージパスは、当時使っていた v1 です。v2 のモジュールパスは `github.com/golangci/golangci-lint/v2` で、コマンドのパッケージはその下の `cmd/golangci-lint` です。

ここまでが楽になる部分です。`tools.go` と空インポートが消え、実行コマンドが `go tool` になります。

CI の grep をそのまま使うと、`tool` 行にも一致します。`tool github.com/golangci/golangci-lint/cmd/golangci-lint` の 2 列目は版ではありません。require の、`v` で始まる列だけを取る必要があります。

action に任せるなら、binary で `version` を空にします。v6 はそのとき `go.mod` の require を見ます。正規表現は、モジュールパスの直後が空白と `v` で始まる版、という形です。`tool` 行の `/cmd/...` には一致しません。[v6.3.3](https://github.com/golangci/golangci-lint-action/commit/88d0254d16e98fa768899db08fed21af161ff2cc)で、`// indirect` まで巻き込まないよう `v\S+` に直っています。それより前の `v.+` は、行末のコメントまで版の一部にしてパースに失敗します。

[action v9.3.0 の `src/version.ts`](https://github.com/golangci/golangci-lint-action/blob/v9.3.0/src/version.ts)が探すのは `github.com/golangci/golangci-lint/v2` です。v1 の require には一致しません。`version-file` が読むのは `.golangci-lint-version` と `.tool-versions` で、`install-mode: binary` のときだけです。`tool` 行は読みません。`goinstall` は v9 でも、`version` 入力か `latest` です。

## 公式はリリースバイナリを推奨している

2026-09-23 時点の [ローカルインストールのドキュメント](https://golangci-lint.run/docs/welcome/install/local/#install-from-sources)は、`go install`、tools.go、`tool` を保証しない、と書いています。理由は次です。

- ローカルの Go でコンパイルされる
- 依存を手動で上げると、テストされていないバイナリになる
- 他のツールや、プロジェクトの依存を書き換えうる
- main ブランチを入れられる
- バイナリより遅い

action の `install-mode: goinstall` も非推奨で、同じページを指しています。

どうしても `go tool` を使うなら、専用の module ファイルに隔離し、依存を手動で上げないこと、とあります。今回の `tools.go` は本体の `go.mod` に入れているので、この隔離にはなっていません。

[CI のドキュメント](https://golangci-lint.run/docs/welcome/install/ci/)は、特定のリリースを固定することを強く勧めています。同梱 linter の更新だけで、既存のビルドがまとめて落ちることがあるためです。

## おわりに

Go 1.23 以前に版を 1 箇所へ寄せるなら、`tools.go` で require を残し、ローカルは版なしの `go run`、CI の `goinstall` にはその版を渡す、が今回の形です。`goinstall` は `go.mod` を自分で読まないので、grep が必要でした。

Go 1.24 以降は `tool` ディレクティブで `tools.go` を消せます。実行は `go tool` です。CI の grep は `tool` 行と衝突するので、取り出し方は残ります。golangci-lint の作者は、今もリリースバイナリと版の固定を勧めています。
