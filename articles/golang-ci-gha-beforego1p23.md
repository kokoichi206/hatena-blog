# Go 1.23 以前での golangci-lint のバージョン管理方法

ローカルの `make lint` と GitHub Actions で、golangci-lint の版が違っていました。Makefile ではインストールが `v1.59.1`、実行が `@latest`、Actions では `v1.60.3` を指定していました。

Go 1.23 では `tool` ディレクティブが無いので、`tools.go` の空インポートで `go.mod` に版を載せました。ローカルは版を付けない `go run` です。CI は `install-mode: binary` で、`go list -m` が返す同じ版のリリースを入れています。Go 1.24 からは `tool` ディレクティブがあり、`tools.go` は要りません。

## 目次

- [tools.go で go.mod に載せる](#toolsgo-で-gomod-に載せる)
- [版を付けない go run はメインモジュールを使う](#版を付けない-go-run-はメインモジュールを使う)
- [CI は binary で同じ版のリリースを入れる](#ci-は-binary-で同じ版のリリースを入れる)
- [Go 1.24 以降は tool ディレクティブ](#go-124-以降は-tool-ディレクティブ)

<!-- more -->

## tools.go で go.mod に載せる

コマンドラインツールの版を `go.mod` で持つファイルを足しました。ビルドタグで通常のビルドから外し、空インポートするやり方は [christina04.hatenablog.com の記事](https://christina04.hatenablog.com/entry/go-cmd-tools-versioning)を参照しています。

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

[`go mod tidy` は `ignore` 以外のビルドタグを有効にして](https://go.dev/ref/mod#go-mod-tidy)パッケージを見ます。このインポートが無いと、require ごと消えます。

linter の推移的な依存も同じ `go.mod` に入るので、アプリケーションの依存と混ざります。

## 版を付けない go run はメインモジュールを使う

`go help run` では、`@latest` や `@v1.0.0` のように版を付けると、今いるディレクトリとその親の `go.mod` を無視します。版を付けなければ、そのモジュールの依存として走ります。

```makefile
.PHONY: lint
lint: ## golangci を使って lint を走らせる。
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run -v
```

このターゲットには `@` を付けていません。golangci-lint の版は `go.mod` のものです。

## CI は binary で同じ版のリリースを入れる

`install-mode` は `binary`、`goinstall`、`none` です。既定の `binary` はリリースのアーカイブを落とします。[README](https://github.com/golangci/golangci-lint-action#install-mode) は `goinstall` を非推奨にしています。`goinstall` は `version` が空だと `@latest` になり、`go.mod` を見ません。ローカルの `go run` とずれます。

CI では `binary` にして、[`go list -m`](https://pkg.go.dev/cmd/go#hdr-List_packages_or_modules) の版を渡します。`go list` は Go のセットアップのあとです。

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

`{{.Version}}` は選択された版だけです。`v1.62.0` のようになり、`// indirect` は付きません。引数はモジュールパスです。

`v1.62.0` のように patch まで渡すと、そのリリースを使います。`v1.62` だけだと、実行時に新しい patch を取りにいきます。

CI が実行するのはリリースバイナリです。ローカルの `go run` は同じ版をコンパイルします。版は揃っても、バイナリの中身まで同じとは限りません。

## Go 1.24 以降は tool ディレクティブ

[Go 1.24](https://go.dev/doc/go1.24#tools) から `tool` ディレクティブがあります。`tools.go` は要りません。

```bash
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint@v1.62.0
```

`go.mod` にはパッケージパスだけの行が足されます。版は require に残ります。

```text
tool github.com/golangci/golangci-lint/cmd/golangci-lint
```

実行は `go tool` です。名前がぶつかるときはフルパスを渡します。手順は [依存関係のドキュメント](https://go.dev/doc/modules/managing-dependencies#tools)にあります。

```bash
go tool golangci-lint run
```

v2 のモジュールパスは `github.com/golangci/golangci-lint/v2` です。`go list -m` は `tool` 行を見ないので、CI へ渡す版の取り方は 1.23 のときと同じです。
