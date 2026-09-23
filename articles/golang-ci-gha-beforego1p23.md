# Go 1.23 以前での golangci-lint のバージョン管理方法

ローカルの `make lint` と GitHub Actions で、golangci-lint の版が違っていました。Makefile ではインストールが `v1.59.1`、実行が `@latest`、Actions では `v1.60.3` を指定していました。

Go 1.23 では `tool` ディレクティブが無いので、`tools.go` の空インポートで `go.mod` に版を載せました。ローカルは版を付けない `go run` です。CI は `install-mode: binary` で、`go list -m` が返す同じ版のリリースを入れています。Go 1.24 からは `tool` ディレクティブがあり、`tools.go` は要りません。

## 目次

- [環境](#環境)
- [tools.go で go.mod に載せる](#toolsgo-で-gomod-に載せる)
- [版を付けない go run はメインモジュールを使う](#版を付けない-go-run-はメインモジュールを使う)
- [CI は binary で同じ版のリリースを入れる](#ci-は-binary-で同じ版のリリースを入れる)
- [Go 1.24 以降は tool ディレクティブ](#go-124-以降は-tool-ディレクティブ)

<!-- more -->

## 環境

公開していないリポジトリから抜粋しています。日付は、その変更のコミット日です。

| 対象 | バージョン |
| --- | --- |
| Go | 1.23（`toolchain` は `go1.23.3`） |
| golangci-lint | v1.62.0（`go.mod` に載せた時点） |
| golangci-lint-action | v6 |
| actions/setup-go | v5 |

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

[`go mod tidy` は `ignore` 以外のビルドタグを有効にして](https://go.dev/ref/mod#go-mod-tidy)パッケージを見ます。`//go:build tools` のインポートも依存に残ります。test ジョブの `go mod tidy -diff` は、`tools.go` を残したまま require だけ消すと差分になります。

このあと `go.mod` は `go 1.23`、`toolchain go1.23.3`、golangci-lint は `v1.62.0` になりました。linter の推移的な依存も同じ `go.mod` に入るので、アプリケーションの依存と混ざります。

## 版を付けない go run はメインモジュールを使う

`go help run` では、`@latest` や `@v1.0.0` のように版を付けると、今いるディレクトリとその親の `go.mod` を無視します。版を付けず、`go.mod` がある場所で実行すると、そのモジュールの依存として走ります。

```makefile
.PHONY: lint
lint: ## golangci を使って lint を走らせる。
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run -v
```

このターゲットには `@` を付けていません。golangci-lint の版は `go.mod` のものです。`@v1.62.0` や `@latest` にすると、この `go.mod` は使われません。詳しくは [`go help run`](https://pkg.go.dev/cmd/go#hdr-Compile_and_run_Go_program) です。

`tools.go` の空インポートが無いと、`go mod tidy` が require を消します。その状態では、上の `go run` はパッケージを見つけられません。

## CI は binary で同じ版のリリースを入れる

`golangci-lint-action` の `install-mode` は `binary`、`goinstall`、`none` です。既定は `binary` で、[README](https://github.com/golangci/golangci-lint-action#install-mode) は `goinstall` を非推奨にしています。注意点は [ソースから入れる場合の説明](https://golangci-lint.run/docs/welcome/install/local/#install-from-sources)にあります。

`binary` はリリースのアーカイブをダウンロードします。[`v6.5.0` の `install.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.5.0/src/install.ts) が、指定した版の URL を作っています。`goinstall` のときは、次の `go install` です。

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@${version}
```

[`v6.2.0` の `version.ts`](https://github.com/golangci/golangci-lint-action/blob/v6.2.0/src/version.ts)では、`goinstall` は `version` が空だと `@latest` になり、`go.mod` を見ません。[`go install` に版を付けると、今の `go.mod` は無視されます](https://pkg.go.dev/cmd/go#hdr-Compile_and_install_packages_and_dependencies)。

2024-12-03 に、workflow から `version: v1.61.0` を外しました。コミットメッセージは「don't select lint version in backend-ci」です。`goinstall` のまま外すと、CI は `@latest` のままです。ローカルの `go run` は `go.mod` の版なので、またずれます。

CI では `binary` にしています。版は [`go list -m`](https://pkg.go.dev/cmd/go#hdr-List_packages_or_modules) で取り、`actions/setup-go` のあとに実行します。ジョブの作業ディレクトリは `./backend` です。

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

`go list -m -f '{{.Version}}'` は、そのモジュールの選択版だけを出します。`v1.62.0` のようになり、`// indirect` は付きません。引数は `cmd/golangci-lint` ではなくモジュールパスです。`go.mod` に無いモジュールだと、このステップで失敗します。

patch まで渡すと、action はその版のリリースを使います。`v1.62` だけだと、実行のときに新しい patch を取りにいきます。`go list -m` は patch まで出すので、ここではその版に固定されます。

CI が実行するのはリリースバイナリです。ローカルの `go run` は同じ版をその場でコンパイルします。版は同じでも、バイナリの中身まで一致するとは限りません。

## Go 1.24 以降は tool ディレクティブ

[Go 1.24](https://go.dev/doc/go1.24#tools) から `tool` ディレクティブがあります。`tools.go` は要りません。

```bash
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint@v1.62.0
```

`go.mod` にはパッケージパスだけの行が足されます。版は require に残ります。

```text
tool github.com/golangci/golangci-lint/cmd/golangci-lint
```

名前が他のツールや、Go に同梱のツールとぶつかるときは、フルパスを渡します。

```bash
go tool golangci-lint run
```

手順は [依存関係のドキュメント](https://go.dev/doc/modules/managing-dependencies#tools)にあります。上のパスは当時の v1 です。v2 のモジュールは `github.com/golangci/golangci-lint/v2` で、コマンドは末尾に `cmd/golangci-lint` が付きます。

実行は `go tool` です。CI の `go list -m` と `install-mode: binary` は、1.23 のときと同じにしています。

`go list -m` は `tool` 行を見ません。版は require の方を出します。v2 にするときは、引数を `github.com/golangci/golangci-lint/v2` に変えます。行を空白で切って 2 列目を版にすると、`tool` 行ではパッケージパスになって壊れます。

`version` を空にして、action に `go.mod` を読ませることもできます。v6 の `binary` は正規表現で require を見ます。`tool` 行の `/cmd/...` には一致しません。ただし [v6.3.3 より前](https://github.com/golangci/golangci-lint-action/commit/88d0254d16e98fa768899db08fed21af161ff2cc)の `v.+` は、行末の `// indirect` まで版に含めて失敗します。直ったあとの [v9.3.0](https://github.com/golangci/golangci-lint-action/blob/v9.3.0/src/version.ts) は `github.com/golangci/golangci-lint/v2` しか見ないので、v1 の require は通りません。`version-file` が読むのは `.golangci-lint-version` と `.tool-versions` で、`binary` のときだけです。`tool` 行は読まないので、この記事では `go list -m` で渡しています。
