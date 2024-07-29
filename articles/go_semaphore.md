# context ネイティブ世代の semaphore を使いこなし効率的な流量制御を

典型的な『worker pool』パターンを実装するのに便利な [semaphore](https://pkg.go.dev/golang.org/x/sync/semaphore) の紹介です。

チャネルを使った流量制御のパターンと比べ、**デフォルトで ctx のキャンセルに対応している**ことを実動で確認します。

**[目次]**

```
* [channel パターン](#channel-パターン)
* [sync/semaphore パターン](#sync/semaphore-パターン)
* [おまけ](#おまけ)
  * [errgroup.WithContext でエラーを発生させてみた](#errgroup.withcontext-でエラーを発生させてみた)
* [おわりに](#おわりに)
```

## channel パターン

まず context パッケージがない時代からある、素直に channel を使ったパターンです。

do 関数が並行処理させたい対象とし、何かしらの**制約で同時並行数を絞りたいケース**を考えます（いわゆる流量制限）。
CPU 負荷の考慮や、外部 db, API へのリクエストの兼ね合い等が考えられるでしょうか。

``` go
package main

import (
	"context"
	"fmt"
	"time"

	"golang.org/x/sync/errgroup"
)

const (
	limit = 3
)

// 時間のかかるタスク想定。
func do(input string) {
	time.Sleep(1 * time.Second)
	fmt.Printf("input: %v\n", input)
}

func channelPattern(ctx context.Context, inputs []string) {
	defer func() { fmt.Println("channelPattern done") }()

	pool := make(chan struct{}, limit)

	var eg errgroup.Group

	for _, v := range inputs {
		v := v

		pool <- struct{}{}

		eg.Go(func() error {
			do(v)
			<-pool
			return nil
		})
	}

	if err := eg.Wait(); err != nil {
		fmt.Printf("err eg.Wait(): %v\n", err)
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	inputs := []string{
		// limit=3 ずつ処理されるイメージで、3 つずつの塊に分けている。
		"1", "2", "3",
		"11", "22", "33",
		"111", "222", "333",
		"1111", "2222", "3333",
		"11111", "22222", "33333",
	}

	channelPattern(ctx, inputs)

	// 終わらないための工夫。
	time.Sleep(100 * time.Second)
}
```

上記コードのように、channelPattern 関数に 15 個の inputs を与えた時、流量を limit の3に絞っているため 5 秒ほど処理にかかる見積もりとなります。

しかし、同時に context を 2 秒でタイムアウトさせる設定にしているため、理想を言えば2秒で関数を抜けて欲しいのですが上記コードはそうなっていません。
（タイムアウトとなる設定は、クライアントからのリクエストがキャンセルされたなどのケースも含まれる。）

``` sh
# 上記コードの実行例。
$ go run main.go
input: 1
input: 3
input: 2
input: 33
input: 22
input: 11
input: 111
input: 333
input: 222
input: 2222
input: 3333
input: 1111
input: 11111
input: 33333
input: 22222
channelPattern done
^Csignal: interrupt
```

この問題を解決させるには、以下のように自力で select を書く必要がありますが, **break 箇所を意識**しないといけなかったり、**そもそも書くのを忘れたり**と、難しい課題があります。

``` go
func channelPatternWithCancel(ctx context.Context, inputs []string) {
	defer func() { fmt.Println("channelPatternWithCancel done") }()

	pool := make(chan struct{}, limit)

	// WithContext はエラー発生時に ctx cancel を伝播してくれるが、
	// キャンセル処理自体は自力で書く必要がある。
	// see: https://pkg.go.dev/golang.org/x/sync/errgroup
	eg, ctx := errgroup.WithContext(ctx)

FORLOOP:
	for _, v := range inputs {
		v := v

		select {
		case <-ctx.Done():
			fmt.Printf("ctx.Done() v=%v: %v\n", v, ctx.Err())
			break FORLOOP
		case pool <- struct{}{}:
		}

		eg.Go(func() error {
			do(v)
			<-pool
			return nil
		})
	}

	if err := eg.Wait(); err != nil {
		fmt.Printf("err eg.Wait(): %v\n", err)
	}
}
```

``` sh
# 上記コードの実行例。
$ go run main.go
input: 2
input: 1
input: 3
ctx.Done() v=111: context deadline exceeded
input: 22
input: 11
input: 33
channelPatternWithCancel done
```

## sync/semaphore パターン

そこで今回私がお勧めしたいのが、[sync/semaphore](https://pkg.go.dev/golang.org/x/sync/semaphore) パッケージです。

公式のサンプルにも以下の記載があるように『ワーカーパターンにおいて、**終了時にアイドル状態の worker を終了させる必要がない**』ことがメリットになってるようです。

> This use of a semaphore mimics a typical “worker pool” pattern,
> but without the need to explicitly shut down idle workers when the work is done.

Example に則って先ほどの channel パターンと同じことを書くならば、以下のようになります。
（最後の sem.Acquire は eg.Wait に置き換えてるが、それ以外はほぼ同じ）


``` sh
# まず go get が必要。
go get "golang.org/x/sync/semaphore"
```

``` go
const (
	limit = 3
)

func do(input string) {
	time.Sleep(1 * time.Second)
	fmt.Printf("input: %v\n", input)
}

func weightedPattern(ctx context.Context, inputs []string) {
	defer func() { fmt.Println("weightedPattern done") }()

	sem := semaphore.NewWeighted(limit)

	var eg errgroup.Group

	for _, v := range inputs {
		v := v

		// キャンセルが起きた時などは、ここで sem.Acquire() が失敗する。
		if err := sem.Acquire(ctx, 1); err != nil {
			fmt.Printf("err sem.Acquire(): %v\n", err)
			break
		}

		eg.Go(func() error {
			do(v)
			sem.Release(1)
			return nil
		})
	}

	if err := eg.Wait(); err != nil {
		fmt.Printf("err eg.Wait(): %v\n", err)
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	inputs := []string{
		"1", "2", "3",
		"11", "22", "33",
		"111", "222", "333",
		"1111", "2222", "3333",
		"11111", "22222", "33333",
	}

	weightedPattern(ctx, inputs)

	// 終わらないための工夫。
	time.Sleep(100 * time.Second)
}
```

確かに context のキャンセルが伝播され、いい感じに worker が終了されてることが確認できました！

``` sh
# 上記コードの実行例。
$ go run main.go
input: 1
input: 2
input: 3
err sem.Acquire(): context deadline exceeded
input: 22
input: 11
input: 33
weightedPattern done
```

## おまけ

### errgroup.WithContext でエラーを発生させてみた

``` go
// see: https://pkg.go.dev/golang.org/x/sync/errgroup#WithContext
func channelPatternEGCtx(ctx context.Context, inputs []string) {
	defer func() { fmt.Println("channelPatternEGCtx done") }()

	pool := make(chan struct{}, limit)

	eg, ctx := errgroup.WithContext(ctx)

FORLOOP:
	for _, v := range inputs {
		v := v

		select {
		case <-ctx.Done():
			fmt.Printf("ctx.Done() v=%v: %v\n", v, ctx.Err())
			break FORLOOP
		case pool <- struct{}{}:
		}

		eg.Go(func() error {
			do(v)
			<-pool

			if v == "33" {
				return fmt.Errorf("error: %v", v)
			}
			return nil
		})
	}

	if err := eg.Wait(); err != nil {
		fmt.Printf("err eg.Wait(): %v\n", err)
	}
}
```

エラー発生以後は ctx のキャンセルが伝播されてそうでした。

``` sh
$ go run main.go
input: 1
input: 3
input: 2
input: 11
input: 33
input: 22
cancel:  222
ctx.Done(): context canceled
input: 111
err eg.Wait(): error: 33
channelPatternEGCtx done
```

## おわりに

公式で context に対応してるところは積極的に使っていく。
semaphore の方で問題があるケースが思いつかないため、そちらに統一していきたい。
