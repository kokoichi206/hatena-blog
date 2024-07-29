# システムコールを元に HTTP サーバーの解像度を上げる (with Go 実装)

HTTP サーバーってどんな仕組みで動いてるのかずっと気になっていたのですが、『ふつうのLinuxプログラミング』に説明 + c での実装があったため、その理解を元に適当に Go でやってみました。

**[目次]**

``` 
* [まとめ](#まとめ)
* [サーバーとは](#サーバーとは)
  * [クライアント側](#クライアント側)
  * [サーバー側](#サーバー側)
* [Go で実装](#go-で実装)
  * [目標](#目標)
  * [標準ライブラリでの実装](#標準ライブラリでの実装)
  * [必要なシステムコールを意識して実装](#必要なシステムコールを意識して実装)
* [おわりに](#おわりに)
```

## まとめ

先に思ったことをつらつらとまとめておきます。
興味があればさらに読み進めてみてください。

- c の実装と比較しながら Go で実装してみて思った部分
  - Go の runtime に任せてる部分がありがたい
    - ヒープ領域のメモリの割り当て
    - gc によるメモリの解放
    - この辺もちゃんと理解しておきたい
  - Go からプロセスを明示的に生成することはできなさそう？
    - → goroutine 実行
    - c 実装の例でいう fork + exec の部分
- ファイルシステムと io パッケージの抽象化の類似
  - ファイルシステムもすごいが io.Writer などのインタフェースによる抽象化もよくできている
  - 『Goならわかるシステムプログラミング』で幾度となく言及されている
- Go の runtime 側での SIGPIPE の捕捉は特殊かも
  - https://pkg.go.dev/os/signal#hdr-SIGPIPE
  - fd 1,2 での broken pipe に対する書き込みなら飛んでくるが、それ以外なら飛んでこない仕様
    - 3 以上であれば `signal.Notify(sigs, syscall.SIGPIPE)` で捕捉可能
- 今回サボったところ
  - パスの正規化
    - ドキュメントルート以外のファイルを見えないようにする
  - サーバーのデーモン化
    - fork + setsid でやるらしい
  - エラーハンドリング
  - 適切なキャンセル処理

## サーバーとは

Linux の世界は、「プロセス」と「ファイルシステム」と「ストリーム」の3つの概念で構成されており、HTTP サーバーはこれらの集大成として考えられます。

ネットワーク越しの通信であっても、結局はストリームを扱っているということは変わりありません。
そして、**ストリームを扱う限りにおいては read, write といった統一されたインタフェース**でやりとりが可能で、ここは特に意識する必要はありません。

一方で、ストリームを開く _open_ の部分に、多少ネットワーク味が出てくるのでそこを念頭においておきます。
その _open_ 部分ですが、**プロセスがストリームを接続するための口ととして用意されているインタフェースを『ソケット』**といい、ネットワーク通信において重要な役割を果たしています。

### クライアント側

クライアントからストリームを _open_ させるには、次の2ステップのシステムコールが必要です。

1. socket(2)
2. connect(2)

socket はその名の通りソケットを作成するシステムコールです。

connect は、ソケットからストリームを伸ばし、対象の IP アドレスに接続します。

### サーバー側

サーバーからソケット接続を待ち受けるには、次の4ステップのシステムコールが必要です。
1-3 はサーバー起動時に1回だけ呼ばれるもので、4 はクライアントからの接続ごとに作られ直すものになります。

1. socket(2)
2. bind(2)
3. listen(2)
4. accept(2)

bind では待ち受けるポートを指定し、ソケットと紐付けます。

listen を呼ぶことで『このソケットはサーバ用のもので、接続を待ち続けるものである』ということをカーネルに伝えます。

最後に accept でクライアントからの接続を待ち、接続が取れたらストリームの fd が取得されます。


## Go で実装

### 目標

以下のように、curl で叩くとファイルの内容が返ってくるサーバーを作ることがゴールです。

サーバーの起動

``` sh
$ go run main.go
```

サーバーにリクエストを送る

``` sh
$ curl http://localhost:9876/go.mod
module go-syscall-server-test

go 1.20

$ curl -I http://localhost:9876/test.jpg
6/test.jpg
HTTP/1.1 200 OK
Date: Sat, 04 Nov 2023 16:40:15 UTC
Server: LittleHTTP/1.0
Connection: close
Content-Length: 402651
Content-Type: image/jpeg
```

### 標準ライブラリでの実装

通常、Go でファイルサーバーを立てるには以下のように2行書くだけで構築できます。

``` go
package main

import (
	"net/http"
)

func main() {
	http.Handle("/", http.FileServer(http.Dir(".")))
	http.ListenAndServe(":9876", nil)
}
```

後ほどの確認により、標準パッケージの偉大さがわかるかと思います。

### 環境

```
$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

### 必要なシステムコールを意識して実装

**サーバーにとって必要な**システムコールわかるように、雑に Go で書いてみます。
書籍で出てきた c 実装は[こちらの github](https://github.com/aamine/stdlinux2-source/blob/master/httpd2.c) です。

気になったところはコメントもしてあるので、細かい説明は省きます。
改善点・思ったことなどあればコメントください。

``` go
package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	SERVER_NAME    = "LittleHTTP"
	SERVER_VERSION = "1.0"
)

type HTTPHeaderField struct {
	name  string
	value string
	next  *HTTPHeaderField
}

type HTTPRequest struct {
	protocolMinorVersion int
	method               string
	path                 string
	header               *HTTPHeaderField
	body                 *string
	length               int64
}

func logExit(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
	os.Exit(1)
}

func main() {
	sigs := make(chan os.Signal, 1)
	defer func() {
		// シグナルの受付を終了する
		signal.Stop(sigs)
	}()

	installSignalHandlers(sigs)

	sockFd := listenSocket(9876)
	if sockFd == -1 {
		os.Exit(1)
	}
	defer syscall.Close(sockFd)

	// ドキュメントルートをカレントディレクトリに設定。
	go serverMain(sockFd, ".")

	select {
	// シグナルを受け取ったぞ（SIGPIPE は受け取らない！）.
	case sig := <-sigs:
		fmt.Println("Got signal!", sig)
	}
}

func installSignalHandlers(sigs chan<- os.Signal) {
	// fd1, 2 に繋がってるソケットが切断されると SIGPIPE が飛んでくる。
	// https://pkg.go.dev/os/signal#hdr-SIGPIPE
	signal.Notify(sigs, syscall.SIGPIPE, syscall.SIGINT)
}

func listenSocket(port int) int {
	// ================== step 1. socket() ==================
	fd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, syscall.IPPROTO_TCP)
	if err != nil {
		fmt.Printf("err (syscall.Socket): %v\n", err)
		return -1
	}

	// SO_REUSEADDR を設定し 'address already in use' が出ないようにする（TCP の仕様による）。
	if err := syscall.SetsockoptInt(fd, syscall.SOL_SOCKET, syscall.SO_REUSEADDR, 1); err != nil {
		syscall.Close(fd)
		fmt.Printf("err (syscall.SetsockoptInt): %v\n", err)
		return -1
	}

	addr := syscall.SockaddrInet4{
		Port: port,
	}
	// ホスト上の全てのネットワークインターフェース（IPv4）で来る接続を受け入れる。
	copy(addr.Addr[:], []byte{0, 0, 0, 0})

	// ================== step 2. bind() ==================
	if err := syscall.Bind(fd, &addr); err != nil {
		fmt.Printf("err (syscall.Bind): %v\n", err)
		return -1
	}

	// ================== step 3. listen() ==================
	// システムが保持する未処理の接続要求のキューの最大数(BACKLOG)。
	if err := syscall.Listen(fd, 10); err != nil {
		fmt.Printf("err (syscall.Listen): %v\n", err)
		return -1
	}

	return fd
}

func serverMain(sockFd int, docroot string) {
	// accept はプロセスに対し何度も呼ぶ必要がある。
	for {
		// ================== step 4. accept() ==================
		netConnFd, _, err := syscall.Accept(sockFd)
		if err != nil {
			fmt.Printf("err (syscall.Accept): %v\n", err)
			return
		}
		// fork + exec -> goroutine
		go handleConnection(netConnFd, docroot)
	}
}

// 1 リクエストに対する処理。
func handleConnection(connFd int, docroot string) {
	conn := os.NewFile(uintptr(connFd), fmt.Sprintf("connFd: %d", connFd))
	// TODO: conn.Close() は色々やってそうだけど fd の close だけで十分か？
	defer syscall.Close(connFd)

	service(conn, conn, docroot)
}

func service(inFile, outFile *os.File, docroot string) {
	defer func() {
		// エラーハンドリングをサボる代わり。
		if r := recover(); r != nil {
			fmt.Printf("r: %v\n", r)
		}
	}()

	req := readRequest(inFile)
	fmt.Printf("%s: path: %v\n", req.method, req.path)

	writeResponse(req, outFile, docroot)
}

func readRequest(in io.Reader) *HTTPRequest {
	req := &HTTPRequest{}
	h := &HTTPHeaderField{}

	reader := bufio.NewReader(in)
	readRequestLine(req, reader)

	for {
		h = readHeaderField(reader)
		if h == nil {
			break
		}
		// 過去の header を新規 header の next に設定する。
		h.next = req.header
		req.header = h
	}
	req.length = contentLength(req)
	return req
}

// リクエストライン『GET /go.mod HTTP/1.1\r\n』を読み込む。
func readRequestLine(req *HTTPRequest, reader *bufio.Reader) {
	buf, err := reader.ReadString('\n')
	if err != nil {
		logExit("no request line")
	}

	buf = strings.TrimSpace(buf)
	parts := strings.SplitN(buf, " ", 3)

	req.method = strings.ToUpper(parts[0])
	req.path, _ = url.QueryUnescape(parts[1])

	protoParts := strings.SplitN(parts[2], "/", 2)
	verParts := strings.SplitN(protoParts[1], ".", 2)
	req.protocolMinorVersion, _ = strconv.Atoi(verParts[1])
}

func readHeaderField(reader *bufio.Reader) *HTTPHeaderField {
	buf, err := reader.ReadString('\n')
	if err != nil {
		if err == io.EOF {
			return nil
		}
		logExit("failed to read request header field: %v", err)
	}
	// リクエストの終了を示す空行（= Header Area が終わって body との空行）を検出。
	if buf == "\n" || buf == "\r\n" {
		return nil
	}
	parts := strings.SplitN(buf, ":", 2)
	name := strings.TrimSpace(parts[0])
	value := strings.TrimSpace(parts[1])
	return &HTTPHeaderField{
		name:  name,
		value: value,
	}
}

func contentLength(req *HTTPRequest) int64 {
	val := lookupHeaderFieldValue(req, "Content-Length")
	if val == "" {
		return 0
	}
	len, err := strconv.ParseInt(val, 10, 64)
	if err != nil || len < 0 {
		fmt.Printf("negative Content-Length value or parsing error: %v\n", err)
	}
	return len
}

func lookupHeaderFieldValue(req *HTTPRequest, name string) string {
	for h := req.header; h != nil; h = h.next {
		if strings.EqualFold(h.name, name) {
			return h.value
		}
	}
	return ""
}

func writeResponse(req *HTTPRequest, outFile *os.File, docroot string) {
	w := bufio.NewWriter(outFile)

	switch req.method {
	case "GET":
		doFileResponse(req, w, docroot)
	case "HEAD":
		doFileResponse(req, w, docroot)
		// TODO: method not allowd.
	}
}

// ファイル応答を生成する関数。
func doFileResponse(req *HTTPRequest, w *bufio.Writer, docroot string) {
	// filepath.Join() を通常は使う。
	path := fmt.Sprintf("%s%s", docroot, req.path)

	var fs syscall.Stat_t
	if err := syscall.Stat(path, &fs); err != nil {
		fmt.Printf("err (syscall.Stat): %v\n", err)
		return
	}

	// ============ Header Area ============
	outputCommonHeaderFields(req, w, "200 OK")
	fd, err := syscall.Open(path, os.O_RDONLY, fs.Mode)
	if err != nil {
		fmt.Printf("err (syscall.Open): %v\n", err)
		return
	}
	fmt.Fprintf(w, "Content-Length: %d\r\n", fs.Size)
	fmt.Fprintf(w, "Content-Type: %s\r\n", guessContentType(fd))
	fmt.Fprintf(w, "\r\n")

	// ============ Content Area ============
	if req.method != "HEAD" {
		// TODO: 4096 byte より長い文字が読めないため、適当にループする or go のライブラリ使う。
		buf := make([]byte, 4096)
		n, err := syscall.Read(fd, buf)
		if err != nil {
			fmt.Printf("err (syscall.Read): %v\n", err)
			return
		}

		syscall.Close(fd)
		w.Write(buf[:n])
	}

	// buffer を使ったので Flush が必要。
	w.Flush()
}

func outputCommonHeaderFields(req *HTTPRequest, out *bufio.Writer, status string) {
	// HTTP では常に CR LF の "\r\n" を改行として扱う。
	fmt.Fprintf(out, "HTTP/1.%d %s\r\n", req.protocolMinorVersion, status)
	fmt.Fprintf(out, "Date: %s\r\n", time.Now().UTC().Format(time.RFC1123))
	fmt.Fprintf(out, "Server: %s/%s\r\n", SERVER_NAME, SERVER_VERSION)
	fmt.Fprintf(out, "Connection: close\r\n")
}

func guessContentType(fd int) string {
	buf := make([]byte, 512)
	_, _ = syscall.Read(fd, buf)
	syscall.Seek(fd, 0, io.SeekStart)
	return http.DetectContentType(buf)
}
```

今回のサーバーは色々と穴があり、以下のように『ディレクトリトラバーサル攻撃』することも可能です。
**他にも何かできることあれば教えてください。**

``` sh
# パスの結合方法に問題があるため（filepath パッケージを使いこなす必要がある。）。
$ curl -v http://localhost:9876/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd
root:...
daemon:...
```

## おわりに

圧倒的に基礎力が足りない。
