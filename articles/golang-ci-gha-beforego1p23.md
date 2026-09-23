# Go 1.23 以前での golangci-lint のバージョン管理方法

golangci-lint の版がローカルと CI で揃っていませんでした。Makefile のインストール指定は `v1.59.1`、同じ Makefile の実行は `@latest`、GitHub Actions は `v1.60.3` です。見る場所で linter が違います。

版の置き場所は、`go.mod` の require です。Go 1.23 には `tool` ディレクティブが無いので、`//go:build tools` の空インポートでそこに載せます。ローカルの `go run` は版を付けず、メインモジュールが選んでいる版を使います。CI は `install-mode: binary` にして、`go list -m` で取った同じ版のリリースバイナリを入れます。

Go 1.24 以降は `tool` ディレクティブで、この空インポート用のファイルは要らなくなります。`uses:` が指す action の ref と、実際に走る golangci-lint 本体の版は別です。ここでは本体の話だけです。

## 目次

- [環境](#環境)
- [tools.go で go.mod に載せる](#toolsgo-で-gomod-に載せる)
- [版を付けない go run はメインモジュールを使う](#版を付けない-go-run-はメインモジュールを使う)
- [CI は binary で同じ版のリリースを入れる](#ci-は-binary-で同じ版のリリースを入れる)
- [Go 1.24 以降は tool ディレクティブ](#go-124-以降は-tool-ディレクティブ)
- [おわりに](#おわりに)

<!-- more -->

## 環境

コードは非公開のリポジトリです。要点だけ抜きます。日付は、その変更を入れたコミットのものです。

| 対象 | バージョン |
| --- | --- |
| Go | 1.23（`toolchain` は `go1.23.3`） |
| golangci-lint | v1.62.0（`go.mod` に載せた時点） |
| golangci-lint-action | v6 |
| actions/setup-go | v5 |

action の `@v6` は浮動タグです。ソースを見たタグは、本文のリンク先に書いています。

## tools.go で go.mod に載せる

2024-11-22 に、コマンドラインツールの版を `go.mod` で持つファイルを足しました。ビルドタグで通常のビルドから外し、空インポートするやり方は [christina04.hatenablog.com の記事](https://christina04.hatenablog.com/entry/go-cmd-tools-versioning)を参照しています。

```go
//go:build tools

package tools

// コマンドラインツールをgo.modでバージョン管理するためのファイル
// ref: https://christina04.hatenablog.com/entry/go-cmd-tools-versioning

import (
	_ "github.com/air-verse/air"
	_ "github.com/golangci/golangci-lint/cmd/golangci-lint"
)
```

[`go mod tidy` は `ignore` 以外のビルドタグを有効にした扱い](https://go.dev/ref/mod#go-mod-tidy)でパッケージを見ます。`//go:build tools` のインポートも依存に残ります。test ジョブの `go mod tidy -diff` は、`tools.go` を残したまま require だけ消すと差分になります。

この変更のあと、`go.mod` は `go 1.23`、`toolchain go1.23.3`、golangci-lint は `v1.62.0` になりました。linter の推移的依存も、同じ `go.mod` に入ります。アプリケーションの依存と混ざります。

## 版を付けない go run はメインモジュールを使う

`go help run` では、パッケージ引数に版の接尾辞（`@latest` や `@v1.0.0`）があると、カレントディレクトリとその親にある `go.mod` を無視します。接尾辞が無いときは、`go.mod` があればモジュールモードになり、メインモジュールの文脈で実行します。

```makefile
.PHONY: lint
lint: ## golangci を使って lint を走らせる。
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run -v
```

`@` を付けていません。この `go run` が使う golangci-lint の版は、メインモジュールのビルドリストにある版、つまり `go.mod` で選ばれている版です。`@v1.62.0` や `@latest` を付けると、その `go.mod` は使われません。

説明の原文は [`go help run`](https://pkg.go.dev/cmd/go#hdr-Compile_and_run_Go_program) です。空インポートが無いと、`go mod tidy` が require を消し、この `go run` はパッケージを解決できなくなります。`tools.go` はそのためのファイルです。

## CI は binary で同じ版のリリースを入れる

[action の README](https://github.com/golangci/golangci-lint-action#install-mode) では、`install-mode` は `binary`、`goinstall`、`none` です。既定は `binary` です。`goinstall` は非推奨で、[ソースからのインストール](https://golangci-lint.run/docs/welcome/install/local/#install-from-sources)を指しています。

`binary` は、GitHub Releases のアーカイブをダウンロードします。[`v6.5.0` の `src/install.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.5.0/src/install.ts) が、`version` からその URL を組み立てます。`goinstall` は次を実行します。

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@${version}
```

[`v6.2.0` の `src/version.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.2.0/src/version.ts)では、`goinstall` の分岐が `go.mod` を読む処理より前に return します。`version` が空なら `@latest` です。[`go install` も、引数に版が付くとカレントの `go.mod` を無視します](https://pkg.go.dev/cmd/go#hdr-Compile_and_install_packages_and_dependencies)。

2024-12-03 に、workflow から `version: v1.61.0` を外しました。コミットメッセージは「don't select lint version in backend-ci」です。`goinstall` のまま外すと、CI は `@latest` になります。ローカルの版なし `go run` は `go.mod` の版なので、ここでも揃いません。

CI 側は `binary` にします。渡す版は [`go list -m`](https://pkg.go.dev/cmd/go#hdr-List_packages_or_modules) で取ります。ジョブの `working-directory` は `./backend` で、このステップは `actions/setup-go` のあとです。

```yaml
- name: Check golangci-lint version
  id: golang_ci_version
  run: |
    version=$(go list -m -f '{{.Version}}' github.com/golangci/golangci-lint)
    echo "version=${version}" >> "$GITHUB_OUTPUT"

- name: golangci-lint
  uses: golangci/golangci-lint-action@v6
  with:
    working-directory: ./backend
    install-mode: binary
    version: ${{ steps.golang_ci_version.outputs.version }}
```

`go list -m` は、今のモジュールが選んでいる版を出します。`-f '{{.Version}}'` なので、出るのは `v1.62.0` だけです。`// indirect` は付きません。引数はコマンドのパッケージパスではなく、モジュールパスです。そのモジュールが `go.mod` に無いと、このステップは失敗します。

`binary` で patch まで指定すると、action はその版をそのまま使います。`v1.62` のように minor だけだと、実行時に最新の patch を引きにいきます。`go list -m` の出力は patch まで含むので、リリースはその版に固定されます。

揃うのは版番号です。CI はその版のリリースバイナリを実行し、ローカルの `go run` は同じモジュール版をその場でコンパイルします。実行ファイルの中身まで同じとは限りません。公式がインストール方法として保証しているのは、リリースバイナリの方です。

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

ここまでが楽になる部分です。`tools.go` と空インポートが消え、実行コマンドが `go tool` になります。CI の `go list -m` と `install-mode: binary` はそのままです。

`go list -m` は `tool` 行を読みません。require にあるモジュールの選択版を出すので、Go 1.24 でも同じコマンドで足ります。v2 にするときは、引数を `github.com/golangci/golangci-lint/v2` に変えます。行の 2 列目を版にする取り方は、`tool` 行の 2 列目がパッケージパスなので壊れます。

`version` を空にした `binary` は、v6 だと作業ディレクトリの `go.mod` を正規表現で読みます。`tool` 行の `/cmd/...` には一致しません。[v6.3.3](https://github.com/golangci/golangci-lint-action/commit/88d0254d16e98fa768899db08fed21af161ff2cc)より前の `v.+` は、行末の `// indirect` まで版の一部にしてパースに失敗します。`v\S+` に直ったあとでも、[action v9.3.0](https://github.com/golangci/golangci-lint-action/blob/v9.3.0/src/version.ts)が探すのは `github.com/golangci/golangci-lint/v2` だけです。v1 の require には一致しません。`version-file` が読むのは `.golangci-lint-version` と `.tool-versions` で、`binary` のときだけです。`tool` 行は読みません。だから、action の自動検出には任せません。

## おわりに

課題は、ローカルと CI で golangci-lint の版が揃っていないことです。Go 1.23 以前は `tools.go` で require を残します。`go help run` のとおり、版を付けない `go run` はメインモジュールの版を使います。CI は `install-mode: binary` にして、`go list -m` の版を渡します。`goinstall` は非推奨で、`version` が空だと `@latest` になります。

Go 1.24 以降は `tool` ディレクティブで `tools.go` を消せます。実行は `go tool` です。版の取り出しと CI の `binary` は同じです。golangci-lint の作者は、今もリリースバイナリと版の固定を勧めています。
