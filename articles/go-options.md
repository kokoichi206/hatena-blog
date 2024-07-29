# Go で是非とも使いたいオプション一覧

Go のコマンドには様々なオプションが存在します。

今回は、現時点でつけておいて損がないのではないかと思ってるフラグを紹介させてもらいます。

**[目次]**

```
* [まとめ](#まとめ)
* [環境](#環境)
* [リリースビルド時](#リリースビルド時)
  * [[CGO_ENABLED=0](https://pkg.go.dev/cmd/cgo)](#[cgo_enabled=0](https://pkg.go.dev/cmd/cgo))
  * [`-ldflags="-s -w"`](#`-ldflags="-s--w"`)
  * [`-trimpath`](#`-trimpath`)
* [テスト実行時](#テスト実行時)
  * [-race](#-race)
  * [-cover](#-cover)
  * [-shuffle=on](#-shuffle=on)
  * [-v](#-v)
* [ローカル実行時](#ローカル実行時)
  * [-race](#-race)
* [おわりに](#おわりに)
```

## まとめ

``` sh
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -trimpath -o ./api2 ./app

go test -race -cover -shuffle=on ./... -v

go run -race app/*
```

## 環境

``` sh
$ go version
go version go1.21.2 darwin/arm64
```

## リリースビルド時

こんな感じでビルドするのがいいと思ってます。

``` sh
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -trimpath -o ./api2 ./app
```

### [CGO_ENABLED=0](https://pkg.go.dev/cmd/cgo)

**GLIBC などに依存しない「静的リンク」の**バイナリとして確実にビルドするためのオプションです。

### -ldflags="-s -w"

``` sh
$ go help build
...
-ldflags '[pattern=]arg list'
        arguments to pass on each go tool link invocation.
```

リンク作成時のオプションを指定しています。

オプションの詳細は `go tool link --help` で確認できます。

``` sh
$ go tool link --help
usage: link [options] main.o
  ...
  -s    disable symbol table
  ...
  -w    disable DWARF generation
```

`-w` と `-s` をつけることでデバッグの情報を取り除いたりシンボルテーブルを生成しないようにすることができ、結果としてバイナリサイズの削減につながります。

``` sh
# コードによっては生成されるバイナリサイズが
# 28 MB -> 19 MB になるなどのインパクトがある。
$ go build -ldflags="-s -w" -o main-ldflags main.go
$ go build -o main main.go
$ ls -la
-rwxr-xr-x  1 kokoichi  staff  1975970 Feb 22 00:50 main
-rwxr-xr-x  1 kokoichi  staff  1414562 Feb 22 00:50 main-ldflags
```

これらのフラグをつけた場合でも、panic の**スタックトレースなどではファイルパスは表示されたまま**でした。

<details><summary>実験のコード</summary>

``` go
package main

func panipani() {
	panic("pien")
}
func testFunc() {
	panipani()
}
func main() {
	testFunc()
}
```

</details>

<details><summary>通常の実行時</summary>

``` sh
$ go build -o main main.go
$ ./main
panic: pien

goroutine 1 [running]:
main.panipani(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:13
main.testFunc(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:17
main.main()
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:33 +0x34
```

</details>

<details><summary>ldflags の -s, -w を指定したとき</summary>

``` sh
$ go build -ldflags="-s -w" -o main-ldflags main.go
$ ./main-ldflags
panic: pien

goroutine 1 [running]:
main.panipani(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:13
main.testFunc(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:17
main.main()
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:33 +0x34
```

</details>

### -trimpath

``` sh
$ go help build
...
-trimpath
        remove all file system paths from the resulting executable.
        Instead of absolute file system paths, the recorded file names
        will begin either a module path@version (when using modules),
        or a plain import path (when using the standard library, or GOPATH).
```

通常のビルドでは、絶対パスとしてファイルの情報が書き込まれるのですが、これを指定することによりGOPATH からの相対パスになります。

<details><summary>実験のコード</summary>

``` go
package main

import (
	"fmt"
	"sync"
)

type store struct {
	data []string
}
// データ競合を起こすような操作。
func (s *store) add(wg *sync.WaitGroup, d string) {
	defer wg.Done()
	s.data = append(s.data, d)
}

func main() {
	s := store{}
	wg := &sync.WaitGroup{}
	wg.Add(2)

	go s.add(wg, "hi")
	go s.add(wg, "hello")

	wg.Wait()
	fmt.Printf("s.data: %v\n", s.data)
}
```

</details>

<details><summary>通常の実行時</summary>

``` sh
$ go run -race  main.go
==================
WARNING: DATA RACE
Read at 0x00c0000aa018 by goroutine 6:
  main.(*store).add()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:14 +0x6c
  main.main.func1()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:31 +0x4c

Previous write at 0x00c0000aa018 by goroutine 7:
  main.(*store).add()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:14 +0x11c
  main.main.func2()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:32 +0x4c

Goroutine 6 (running) created at:
  main.main()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:31 +0xdc

Goroutine 7 (finished) created at:
  main.main()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:32 +0x144
==================
==================
WARNING: DATA RACE
Read at 0x00c00008e020 by goroutine 6:
  runtime.growslice()
      /opt/homebrew/Cellar/go/1.21.2/libexec/src/runtime/slice.go:157 +0x0
  main.(*store).add()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:14 +0xa4
  main.main.func1()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:31 +0x4c

Previous write at 0x00c00008e020 by goroutine 7:
  main.(*store).add()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:14 +0xcc
  main.main.func2()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:32 +0x4c

Goroutine 6 (running) created at:
  main.main()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:31 +0xdc

Goroutine 7 (finished) created at:
  main.main()
      /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:32 +0x144
==================
s.data: [hello hi]
panic: pien

goroutine 1 [running]:
main.panipani(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:18
main.testFunc(...)
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:22
main.main()
        /Users/kokoichi/ghq/github.com/kokoichi206/go-expart/standard/options/main.go:38 +0x1e0
exit status 2
```

</details>

<details><summary>trimpath を指定したとき</summary>

``` sh
❯ go run -race -trimpath main.go
==================
WARNING: DATA RACE
Read at 0x00c00000c030 by goroutine 6:
  main.(*store).add()
      main.go:14 +0x6c
  main.main.func1()
      main.go:31 +0x4c

Previous write at 0x00c00000c030 by goroutine 7:
  main.(*store).add()
      main.go:14 +0x11c
  main.main.func2()
      main.go:32 +0x4c

Goroutine 6 (running) created at:
  main.main()
      main.go:31 +0xdc

Goroutine 7 (finished) created at:
  main.main()
      main.go:32 +0x144
==================
==================
WARNING: DATA RACE
Read at 0x00c000010070 by goroutine 6:
  runtime.growslice()
      runtime/slice.go:157 +0x0
  main.(*store).add()
      main.go:14 +0xa4
  main.main.func1()
      main.go:31 +0x4c

Previous write at 0x00c000010070 by goroutine 7:
  main.(*store).add()
      main.go:14 +0xcc
  main.main.func2()
      main.go:32 +0x4c

Goroutine 6 (running) created at:
  main.main()
      main.go:31 +0xdc

Goroutine 7 (finished) created at:
  main.main()
      main.go:32 +0x144
==================
s.data: [hello hi]
panic: pien

goroutine 1 [running]:
main.panipani(...)
        ./main.go:18
main.testFunc(...)
        ./main.go:22
main.main()
        ./main.go:38 +0x1e0
exit status 2
```

</details>

## テスト実行時

こんな感じでテストするのがいいと思ってます。

``` sh
go test -race -cover -shuffle=on ./... -v
```

### -race

競合状態を検知すると実行を失敗してくれます。
動作が重くなったりもするらしいので、本番環境のビルドに入れてません。

### -cover

C0 レベルでのカバー率を出力してくれます。

``` sh
$ go test -cover ./...
ok      github.com/kokoichi206-sandbox/pien/backend/handler  0.341s  coverage: 85.3% of statements
ok      github.com/kokoichi206-sandbox/pien/backend/repository/database      0.742s  coverage: 81.2% of statements
ok      github.com/kokoichi206-sandbox/pien/backend/usecase  0.551s  coverage: 100.0% of statements
...
```

### -shuffle=on

ランダムな順番でテストを実行させます。

テスト同士の依存関係により予期しない結果になってしまうことがあり、それの抑制につながります。

### -v

詳細なログを出力します。

## ローカル実行時

``` sh
go run -race app/*
```

### -race

競合状態を早めに検知するために `-race` フラグをつけて動作確認をするようにします。

## おわりに

もっと便利なオプションもあるかと思うので、何かある方は教えていただけると助かります！
