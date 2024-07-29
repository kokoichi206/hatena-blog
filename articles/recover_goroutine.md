# panic と recover は goroutine 単位

```
* [go での panic recover 基礎](#go-での-panic-recover-基礎)
* [gin のケース](#gin-のケース)
* [goroutine 実行の考慮](#goroutine-実行の考慮)
* [おわりに](#おわりに)
```

## go での panic recover 基礎

Go では『存在しない配列の index アクセスをした場合』や『nil pointer に対する実体参照を行なった場合』などに panic が発生します。

``` go
func main() {
	arr := []int{1, 2, 3}
	fmt.Println(arr[5])
	fmt.Println("finished")
}
```

例えば、上記のコードを実行した場合、以下のようなエラーとともにプログラムが以上終了します。

``` sh
$ go run main.go
panic: runtime error: index out of range [5] with length 3

goroutine 1 [running]:
main.main()
        ...
exit status 2
make: *** [run] Error 1
```

**panic が発生した場合はプログラムが終了してしまう**ので、サーバーなどで停止させたくない場合は [builtin 関数の recover](https://pkg.go.dev/builtin#recover) を使います。

``` go
func main() {
	defer func() {
		if err := recover(); err != nil {
			fmt.Printf("err: %v\n", err)
		}
	}()
	arr := []int{1, 2, 3}
	fmt.Println(arr[5])
}
```

``` sh
$ go run main.go
err: runtime error: index out of range [5] with length 3
```

## gin のケース

web フレームワークの1つである gin には、デフォルトで [Recovery()](https://pkg.go.dev/github.com/gin-gonic/gin#Recovery) という middleware が用意されており（[内部実装](https://github.com/gin-gonic/gin/blob/v1.9.1/recovery.go#L57-L101)）、これを挟むことで『**実装ミスにより panic が発生してもサーバーが落ちることはなくなり**』ます。

例えば、下記のコードで `http://localhost:21829/calc` にアクセスしても、大量のメッセージは出ますがサーバーが止まることはありません。

``` go
import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	engine := gin.New()
	// Recovery は gin.Default() にも含まれる。
	engine.Use(gin.Recovery())
	engine.Handle(http.MethodGet, "/calc", func(context *gin.Context) {
		a := 3
		b := 0
		res := a / b
		context.JSON(http.StatusOK, gin.H{
			"results": res,
		})
	})

	srv := &http.Server{
		Addr:    ":21829",
		Handler: engine,
	}

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("listen: %s\n", err)
	}
}
```

## goroutine 実行の考慮

さてこれで一安心かと思いきや、実はそうではありません。

**独自で生成した goroutine は別途 recover してあげる必要があります！**

どういうことかというと、以下の実装のまま `http://localhost:21829/goroutine` にアクセスすると **gin は panic を recover せずに終了してしまいます**。

``` go
// 別 goroutine で実行させたい対象の関数。
func heavyCalc(wg *sync.WaitGroup) {
	a := 3
	b := 0
	res := a / b
	log.Println(res)
	wg.Done()
}

func main() {
	engine := gin.New()
	engine.Use(gin.Recovery())

	engine.Handle(http.MethodGet, "/goroutine", func(context *gin.Context) {
		var wg sync.WaitGroup
		wg.Add(3)
		for i := 0; i < 3; i++ {
			go heavyCalc(&wg)
		}
		wg.Wait()
	})

	srv := &http.Server{
		Addr:    ":21829",
		Handler: engine,
	}

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("listen: %s\n", err)
	}
}
```

``` sh
$ go run main.go
panic: runtime error: integer divide by zero

goroutine 22 [running]:
main.heavyCalc(0x0?)
        /...
        /panic/main.go:14 +0x1c
created by main.main.func2 in goroutine 35
```

これは panic や recover は goroutine を跨ぐことがないことが原因で、heavyCalc 関数での panic も recover させたければ [gin での実装](https://github.com/gin-gonic/gin/blob/v1.9.1/recovery.go#L57-L101)を参考に、以下のように変更すれば良さそうです。

``` go
	engine.Handle(http.MethodGet, "/goroutine", func(context *gin.Context) {
		var wg sync.WaitGroup
		wg.Add(3)
		for i := 0; i < 3; i++ {
			go func() {
				defer func() {
					if err := recover(); err != nil {
						// 何かしらの処理。
						fmt.Printf("err: %v\n", err)
					}
				}()
				heavyCalc(&wg)
			}()
		}
		wg.Wait()
	})
```

``` sh
$ go run main.go
...
err: runtime error: integer divide by zero
err: runtime error: integer divide by zero
err: runtime error: integer divide by zero
```

goroutine を跨いだ挙動については [panic](https://pkg.go.dev/builtin#panic) や [recover](https://pkg.go.dev/builtin#recover) のドキュメントにも記載があり、以下のようにあくまで現在の goroutine までに関することですよ〜ってなってます。

> func panic
>
> The panic built-in function stops normal execution of the current **goroutine**. ...
> 
> func recover
> 
> The recover built-in function allows a program to manage behavior of a panicking **goroutine**. ...

## おわりに

k8s でマネージドされてるアプリは落ちても大したダメージはないかもしれないですが、こうした挙動を1つ1つ理解していきたいです。
