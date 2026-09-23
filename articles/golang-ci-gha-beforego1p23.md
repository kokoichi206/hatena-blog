# Go 1.23 以前での golangci-lint のバージョン管理方法

ローカルと CI で golangci-lint のバージョンを統一する方法についてメモしておきます。

[tool directive](https://go.dev/ref/mod#go-mod-file-tool) が導入される Go 1.24 より前のお話です。

また、golangci v1.60 で動かしていた当時の内容になるため、v2 で動くかは保証できてません。

## 目次

- [tools.go で go.mod に載せる](#toolsgo-で-gomod-に載せる)
- [実行時にバージョン指定せず go run 実行](#実行時にバージョン指定せず-go-run-実行)
- [CI は binary で同じ版のリリースを入れる](#ci-は-binary-で同じ版のリリースを入れる)

<!-- more -->

## tools.go で go.mod に載せる

cli ツールの依存とそのバージョンを `go.mod` で持つファイルを作成します。

ビルドタグで通常のビルドから外し、空インポートするやり方は[こちらの記事](https://christina04.hatenablog.com/entry/go-cmd-tools-versioning)を参照しています。

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


## 実行時にバージョン指定せず go run 実行

go help run によると、

``` sh
$ go help run
...
If the package argument has a version suffix (like @latest or @v1.0.0),
"go run" builds the program in module-aware mode, ignoring the go.mod file in
the current directory or any parent directory, if there is one. This is useful
for running programs without affecting the dependencies of the main module.

If the package argument doesn't have a version suffix, "go run" may run in
module-aware mode or GOPATH mode, depending on the GO111MODULE environment
variable and the presence of a go.mod file. See 'go help modules' for details.
If module-aware mode is enabled, "go run" runs in the context of the main
module.
...
```

`go run` 実行時、`@latest` や `@v1.0.0` のようなバージョン suffix を付けていない場合では、そのモジュールの依存として走ることが分かります。

そこで以下のように Makefile に記載します。

```makefile
.PHONY: lint
lint: ## golangci を使って lint を走らせる。
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run -v
```

このターゲットには `@` を付けていまないため、golangci-lint のバージョンは `go.mod` のものになります。

## CI は binary で同じ版のリリースを入れる

golangci-lint-action は golangci-lint のバージョンを指定する [key があります](https://github.com/golangci/golangci-lint-action/tree/v6.5.2#version)。  
（当時使っていた v6.5 のタグで確認しています。）

そこで、以下のように [`go list -m`](https://pkg.go.dev/cmd/go#hdr-List_packages_or_modules) で取れる go mod からのバージョンを渡してあげることにしました。

```yaml
- name: Extract golangci-lint version
  id: golang_ci_version
  run: |
    version=$(go list -m -f '{{.Version}}' github.com/golangci/golangci-lint)
    echo "version=${version}" >> "$GITHUB_OUTPUT"

- name: Run golangci-lint
  uses: golangci/golangci-lint-action@v6
  with:
    install-mode: binary
    version: ${{ steps.golang_ci_version.outputs.version }}
```
