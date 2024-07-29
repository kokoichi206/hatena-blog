# Golang で Multi-stage builds すると『version `GLIBC_2.34' not found』のエラー

Golang で Dockerfile を Multi-stage builds で作成した際に、  
docker run すると『version `GLIBC_2.34' not found』のエラーが出ることがありました。

今回はその原因と解決策について共有します。

## 事象

**環境**

- Host
  - mac m2
- Docker
  - v24.0.7
- Dockerfile
  - build 用 base image: golang:1.21
  - deploy 用 base image: gcr.io/distroless/static

**実行時エラー**

``` sh
$ docker run golang-bff:latest

/api: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.32' not found (required by /api)
/api: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by /api)
```

**Dockerfile**

``` Dockerfile
# syntax=docker/dockerfile:1

# 1. build
FROM golang:1.21 AS build

WORKDIR /app

COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY *.go ./

RUN go build -o /api

# 2. deploy
FROM gcr.io/distroless/static
WORKDIR /
COPY --from=build /api /api

EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/api"]
```

## 原因

Go 言語でビルドされたバイナリは、通常 GLIBC などに依存しない「**静的リンク**」バイナリとなります。  
これは、Go のランタイムとアプリケーションコードが**単一の**実行可能ファイルに**全て**含まれており、**外部の共有ライブラリに依存しない**ことを意味しています。

今回はこれが何かの拍子で無効になっており、**動的リンクを使うようなビルドをされていた**ものと思われます。  
そのため、実行時に deploy image の中から外部パッケージの依存性を探しに行ったが見つからなかったのではないかと。

ただし、Go のプログラムが C 言語のコードやライブラリを使用している場合（Cgo）、  
ビルドされたバイナリは共有ライブラリに依存する可能性があります。

## 対策

静的リンクになるよう、[`CGO_ENABLED` の設定を](https://pkg.go.dev/cmd/cgo)します。

また、ついでに GOOS も強制させておきます。

``` diff
# syntax=docker/dockerfile:1

# 1. build
FROM golang:1.21 AS build

WORKDIR /app

COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY *.go ./

- RUN go build -o /api
+ RUN CGO_ENABLED=0 GOOS=linux go build -o /api

# 2. deploy
FROM gcr.io/distroless/static
WORKDIR /
COPY --from=build /api /api

EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/api"]
```
