Makefile のすすめ

Go は Makefile との親和性が高いみたく、ちょっと使ってみたので今回はその個人的な紹介です。

どの Go の本にも少しは書いてあるので、gopher なら何かしらみんな使ってるものと思ってます。

**目次**

- [Makefile って何よ](#makefile-って何よ)
  - [by Chat-GPT](#by-chat-gpt)
  - [by 詳細 Go 言語 web アプリケーション](#by-詳細-go-言語-web-アプリケーション)
- [Makefile 例](#makefile-例)
  - [hello world](#hello-world)
  - [デフォルトのランナーを設定する](#デフォルトのランナーを設定する)
  - [引数を受け取る](#引数を受け取る)
  - [if 文](#if-文)
  - [エイリアスを作る](#エイリアスを作る)
  - [for 文](#for-文)
  - [help 文](#help-文)
  - [注意点](#注意点)
- [おわりに](#おわりに)

## Makefile って何よ

そもそも Makefile って何よってのがあると思うので、皆さんの説明を聞いてみます。

個人的な理解では『shell script よりも簡単に繰り返しの実行を効率化するもの』です。

### by Chat-GPT

> Makefileは、ソフトウェア開発におけるビルドやコンパイルなどのタスクを自動化するためのスクリプトファイルです。
> Makefileには、ターゲット（ビルドするファイルなど）、依存関係（ビルドするために必要なファイルやライブラリなど）およびコマンド（ビルド手順）が定義されています。

> Go言語でMakefileがよく使われる理由は、Goが静的バイナリの生成に適しているためです。
> 静的バイナリは、依存関係を含めたすべての必要なライブラリを1つのバイナリにまとめることができます。
> そのため、他の環境で実行するときに、ライブラリのインストールや環境設定が必要ありません。
> また、Makefileを使用することで、ビルド手順を自動化し、再現性を高めることができます。


### by 詳細 Go 言語 web アプリケーション

> プログラム言語ごとに使用されるタスクランナーツールがありますが、Goで開発を行う際は Mqkefileを使って各作業を管理することが多いです。
> 本書でもここまで複数のコマンドをオプション引数をつけて実行してきました。
> それぞれのコマンドをMakefileに記載しておことで繰り返しの実行を効率化しておきます。


## Makefile 例

簡単にどんなことができるか紹介します。

### hello world

`Makefile` というファイル名でファイルを作成し、以下内容を記載します。

`.PHONY` は、同じファイル名があった時に優先させるようなものだと思ってます。

``` makefile
.PHONY: hello
hello:
	@echo Hello
```

実行する時は以下のように `make <command>` を打ち込みます。

``` sh
$ make hello
Hello
```

### デフォルトのランナーを設定する

`make <command>` すら打つのだるい時ありますよね？

そんな時は `make` のみで実行できるように、デフォルトのコマンドを登録できます。

``` makefile
.DEFAULT_GOAL: run
hello:
	go run app/*
```

**実行方法**

``` sh
$ make
```

### 引数を受け取る

``` makefile
hello:
	@echo hello $(name)
```

**実行方法**

``` sh
$ make hello name=world
hello world
```

### if 文

``` makefile
if-test:	## 
ifeq ($(name),)	## 引数がない時
	@echo Hello 名無さん
else	## 引数がある時
	@echo Hello $(name)
endif

gen:	## t にブランチ・ハッシュ値を指定する
ifeq ($(t),)
	@echo 引数に指定がないため、現在のブランチで生成を行います。
	generate openapi
else
	@cd submodule/openapi && git fetch && git checkout $(t)
	generate openapi
endif
```

### エイリアスを作る

``` makefile
# v2 の場合は『docker compose』にする
DC = docker-compose

.PHONY: dc-up psql dc-do wn
up:
	$(DC) up

## docker compose exec <container_name> psql -U <user_name> <db_name>
psql:	## docker compose で起動した DB に入る
	$(DC) exec postgres psql -U root postgres

down:
	$(DC) down
```

### for 文

みやすさのために途中で開業したい時は `\` を挟みます。

``` makefile
EXTERNAL_TOOLS := \
	github.com/golangci/golangci-lint/cmd/golangci-lint@v1.51.1 \
	golang.org/x/pkgsite/cmd/pkgsite@latest # latest は go 1.19 以上が必要: https://github.com/golang/pkgsite#requirements

bootstrap: ## 外部ツールをインストールする。
	for t in $(EXTERNAL_TOOLS); do \
		echo "Installing $$t ..." ; \
		go install $$t ; \
	done
```

### help 文

↓ の記事が結構良かったため、よく使わせてもらってます。

``` makefile
.DEFAULT_GOAL: help

help:	## https://postd.cc/auto-documented-makefile/
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

test:	## run all test
	go test -shuffle=on ./... -v
```

``` sh
# help を default 登録してる場合
$ make
...
bootstrap                      外部ツールをインストールする。
gen                            t にブランチ・ハッシュ値を指定する
help                           https://postd.cc/auto-documented-makefile/
if-test                        
psql                           docker compose で起動した DB に入る
test                           run all test
```

### 注意点

- インデントは必ず TAB である必要がある。

``` sh
$ cat .editorconfig
...
[Makefile]
indent_size = 4
indent_style = tab
```

## おわりに

コマンドを打ち間違えてる時間が世界で最も無駄なので、Makefile を使って無くしていきたい。
