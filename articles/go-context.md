# Go で HTTP 呼び出し時に Context のキャンセルが TCP コネクションに伝播されるまで

go 1.7 で追加された Context には『key, value 形式による情報の伝搬』と『Goroutine の適切なキャンセル』の主に2つの役割があります。

後者の『Goroutine の適切なキャンセル』が便利で、[公式ブログでも並行処理パターンとして紹介されている](https://go.dev/blog/context)ように、各ライブラリで context を引数に取るような実装がなされています。

特に I/O 待ちを伴うものには（準）標準ライブラリにも導入されており、使い方が参考になりそうです。  
（[sql パッケージの DB.QueryContext](https://pkg.go.dev/database/sql#DB.QueryContext) や [net/http パッケージの NewRequestWithContext](https://pkg.go.dev/net/http#NewRequestWithContext) メソッドなど）

今回はこの『Goroutine の適切なキャンセル』の終端ではどのような処理が行われているのか気になったため、`net/http` の [Request](https://pkg.go.dev/net/http#Request) 内の `ctx`（unexported な変数のため godoc には表示されていません）に着目してソースコードを追ってみました！

**結論**

長くなりそうなので先に結論です。

```
- IO 待ちが発生しそうな部分は goroutine 実行させる
- 結果は channel を通してやり取りする
- 結果の channel の受信と ctx.Done の select を並べて書く
  - `readLoop` の最後で、HTTP レスポンスと ctx.Done で select している
    - defer で `pc.close(closeErr)` が呼ばれ、コネクション（FD）も close される
- 必要に応じて、各ステップの最初に `ctx.Done()` の select を書く
  - それ以外は default で通す
- I/O 待ちが発生する関数には context を渡したいよね
```

一般的なことしてるだけでしたが、追ってくのくそしんどかったっす。。。  
早くこんなの作れるようにならなきゃ。

**[目次]**

- 環境
- client.Do を遡る
  - NewRequestWithContext
  - client.Do からひたすら遡る
  - DefaultTransport.RoundTrip
  - getConn: 接続を確立する
    - queueForDial
  - pconn.roundTrip
- キャンセルされると何が起こるのか
  - Conn が close されること
  - evict
  - decref
    - fd.pd.close()
- Context をキャンセルさせてみる
- Links
- おわりに

## 環境

基本的に以下環境のラズパイで動かしました。

``` sh
$ go version
go version go1.20.7 linux/arm64

$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

## client.Do を遡る

出発点として、次のような最も簡単な HTTP の呼び出しを考えます。

``` go
package main
import (
	"context"
	"fmt"
	"net/http"
	"time"
)
func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 829*time.Millisecond)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http:localhost:21829", nil)
	if err != nil {
		log.Fatal(err)
	}

	client := http.DefaultClient

	resp, err := client.Do(req)
	fmt.Printf("err: %v\n", err)
	if err != nil {
		log.Fatal(err)
	}

	defer resp.Body.Close()
}
```

### NewRequestWithContext

まず、今回着目してる context がどこに渡されているか、から確認します。

`http.Request` につめられているようです。

``` go
func NewRequestWithContext(ctx context.Context, method, url string, body io.Reader) (*Request, error) {
	...
	req := &Request{
		ctx:        ctx,
		...
	}
	...
	return req, nil
}
```

### client.Do からひたすら遡る

まずは実際に HTTP 通信をしているところから、何かしらのシステムコールまで追っていきたいです。

``` go
func (c *Client) Do(req *Request) (*Response, error) {
	return c.do(req)
}

func (c *Client) do(req *Request) (retres *Response, reterr error) {
	...
	for {
		if len(reqs) > 0 {
			...
		}

		...
		if resp, didTimeout, err = c.send(req, deadline); err != nil {
			// c.send() always closes req.Body
			reqBodyClosed = true
			if !deadline.IsZero() && didTimeout() {
				err = &httpError{
					err:     err.Error() + " (Client.Timeout exceeded while awaiting headers)",
					timeout: true,
				}
			}
			return nil, uerr(err)
		}

		...
	}
}
```

途中 timeout など気になる箇所はありましたが、`c.send` が怪しそうです。

``` go
func (c *Client) send(req *Request, deadline time.Time) (resp *Response, didTimeout func() bool, err error) {
	...
	resp, didTimeout, err = send(req, c.transport(), deadline)
	...
	return resp, nil, nil
}

func send(ireq *Request, rt RoundTripper, deadline time.Time) (resp *Response, didTimeout func() bool, err error) {
	...
	resp, err = rt.RoundTrip(req)
	...
	return resp, nil, nil
}
```

HTTP リクエストの事前処理や事後処理をする時はお世話になる、RoundTrip メソッドに辿り着きました。

正しい方向に進んでそうです！

ここからは RoundTripper の具体的な実装に依存する部分になるため、例として `http.DefaultTransport` を参考に遡ってみます。

``` go
var DefaultTransport RoundTripper = &Transport{
	Proxy: ProxyFromEnvironment,
	DialContext: defaultTransportDialContext(&net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
	}),
	ForceAttemptHTTP2:     true,
	MaxIdleConns:          100,
	IdleConnTimeout:       90 * time.Second,
	TLSHandshakeTimeout:   10 * time.Second,
	ExpectContinueTimeout: 1 * time.Second,
}
```

### DefaultTransport.RoundTrip

``` go
func (t *Transport) RoundTrip(req *Request) (*Response, error) {
	return t.roundTrip(req)
}

func (t *Transport) roundTrip(req *Request) (*Response, error) {
	t.nextProtoOnce.Do(t.onceSetNextProtoDefaults)
	ctx := req.Context()
	trace := httptrace.ContextClientTrace(ctx)

	...

	for {
		select {
		// 手始めに ctx.Done を確認。
		// 問題なければ default で通す。
		case <-ctx.Done():
			req.closeBody()
			return nil, ctx.Err()
		default:
		}

		...
		pconn, err := t.getConn(treq, cm)
		if err != nil {
			t.setReqCanceler(cancelKey, nil)
			req.closeBody()
			return nil, err
		}

		var resp *Response
		if pconn.alt != nil {
			// HTTP/2 path.
			t.setReqCanceler(cancelKey, nil) // not cancelable with CancelRequest
			resp, err = pconn.alt.RoundTrip(req)
		} else {
			resp, err = pconn.roundTrip(treq)
		}
		...
	}
}
```

まず `Request` の中の Context を確認していますね。

待ちが発生するたびに、ことあるごとに context がキャンセルされてないかを確認してます。  
（`case <-ctx.Done():` の部分。）

ここからは、コネクションを接続する部分 `t.getConn` と、通信する部分 `pconn.roundTrip` を分けてみていきます！

### getConn: 接続を確立する

``` go
func (t *Transport) getConn(treq *transportRequest, cm connectMethod) (pc *persistConn, err error) {
	req := treq.Request
	trace := treq.trace
	ctx := req.Context()
	if trace != nil && trace.GetConn != nil {
		trace.GetConn(cm.addr())
	}

	w := &wantConn{
		cm:         cm,
		key:        cm.key(),
		ctx:        ctx,
		ready:      make(chan struct{}, 1),
		beforeDial: testHookPrePendingDial,
		afterDial:  testHookPostPendingDial,
	}
	...

	// Queue for permission to dial.
	t.queueForDial(w)

	// レスポンスが来るかキャンセルされるまで待っている！
	select {
	// wantConn が接続され、通信の準備が整っている状態（後述）。
	case <-w.ready:
		if w.pc != nil && w.pc.alt == nil && trace != nil && trace.GotConn != nil {
			trace.GotConn(httptrace.GotConnInfo{Conn: w.pc.conn, Reused: w.pc.isReused()})
		}
		if w.err != nil {
			// 細かく context がキャンセルされてないか確認している！！
			select {
			case <-req.Cancel:
				return nil, errRequestCanceledConn
			case <-req.Context().Done():
				return nil, req.Context().Err()
			case err := <-cancelc:
				if err == errRequestCanceled {
					err = errRequestCanceledConn
				}
				return nil, err
			default:
				// return below
			}
		}
		return w.pc, w.err
	case <-req.Cancel:
		return nil, errRequestCanceledConn
	case <-req.Context().Done():
		return nil, req.Context().Err()
	case err := <-cancelc:
		if err == errRequestCanceled {
			err = errRequestCanceledConn
		}
		return nil, err
	}
}
```

select 句が来る前の `t.queueForDial` が肝みたいです。

#### queueForDial

``` go
// queueForDial queues w to wait for permission to begin dialing.
// Once w receives permission to dial, it will do so in a separate goroutine.
func (t *Transport) queueForDial(w *wantConn) {
	w.beforeDial()
	if t.MaxConnsPerHost <= 0 {
		go t.dialConnFor(w)
		return
	}

	...

	if n := t.connsPerHost[w.key]; n < t.MaxConnsPerHost {
		....
		t.connsPerHost[w.key] = n + 1
		go t.dialConnFor(w)
		return
	}
	...
}
```

**別 goroutine** で `dialConnFor` を呼び出しています。

``` go
func (t *Transport) dialConnFor(w *wantConn) {

	pc, err := t.dialConn(w.ctx, w.cm)
	delivered := w.tryDeliver(pc, err)
	...
}
```

dialConn も tryDeliver も大事なのでみていきます。

``` go
func (t *Transport) dialConn(ctx context.Context, cm connectMethod) (pconn *persistConn, err error) {
	// reqch は後から出てくる。
	pconn = &persistConn{
		t:             t,
		cacheKey:      cm.key(),
		reqch:         make(chan requestAndChan, 1),
		...
	}
	...
	if cm.scheme() == "https" && t.hasCustomTLSDialer() {
		// TLS の時は手順がちょっと増える。
	} else {
		conn, err := t.dial(ctx, "tcp", cm.addr())
		if err != nil {
			return nil, wrapErr(err)
		}
		pconn.conn = conn
		...
	}

	go pconn.readLoop()
	go pconn.writeLoop()
	return pconn, nil
}
```

さらにさらに**別 goroutine** として **read, write loop** を走らせています！！  
(dial も気になるところですが、それはまた別の機会に)

``` go
func (pc *persistConn) readLoop() {
	...
	alive := true
	for alive {

		// roundtrip で投げられた pc.reqch を受け取り、
		rc := <-pc.reqch
		trace := httptrace.ContextClientTrace(rc.req.Context())

		...

		if !hasBody || bodyWritable {
			replaced := pc.t.replaceReqCanceler(rc.cancelKey, nil)
			...

			select {
			case rc.ch <- responseAndError{res: resp}:
			case <-rc.callerGone:
				return
			}

			...
		}

		// 結果があれば requestAndChan.ch に送信している！
		select {
		case rc.ch <- responseAndError{res: resp}:
		case <-rc.callerGone:
			return
		}

		select {
		// レスポンスがきちんと受け取れた時！
		case bodyEOF := <-waitForBodyRead:
			replaced := pc.t.replaceReqCanceler(rc.cancelKey, nil) // before pc might return to idle pool
			alive = alive &&
				bodyEOF &&
				!pc.sawEOF &&
				pc.wroteRequest() &&
				replaced && tryPutIdleConn(trace)
			if bodyEOF {
				eofc <- struct{}{}
			}
		case <-rc.req.Cancel:
			alive = false
			pc.t.CancelRequest(rc.req)
		// キャンセルされた時！
		case <-rc.req.Context().Done():
			alive = false
			pc.t.cancelRequest(rc.cancelKey, rc.req.Context().Err())
		case <-pc.closech:
			alive = false
		}
	}
}
```

readLoop では `persistConn.req` からチャネルを受け取ったら、それに応じた処理を行い、結果（レスポンスかエラー）があれば `persistConn.req.ch` に送信していることが分かりました。

続いて `dialConnFor` の中で呼びだしていたもう1つのメソッド `tryDeliver` です。

``` go
// tryDeliver attempts to deliver pc, err to w and reports whether it succeeded.
func (w *wantConn) tryDeliver(pc *persistConn, err error) bool {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.pc != nil || w.err != nil {
		return false
	}

	w.pc = pc
	w.err = err
	if w.pc == nil && w.err == nil {
		panic("net/http: internal error: misuse of tryDeliver")
	}
	close(w.ready)
	return true
}
```

正常に persistConn が整っていれば、`w.ready` のチャネルが close され、`w.ready` 待ちが発生していた各所に通知が飛ぶことになります！

これでようやく connection の確立ができ、長かった `getConn` のメソッドを抜けることができました。  
（read, write loop は goroutine 実行されたままであることに注意）

### pconn.roundTrip

``` go
func (pc *persistConn) roundTrip(req *transportRequest) (resp *Response, err error) {
	// ごちゃごちゃと準備している。
	...

	resc := make(chan responseAndError)
	// 先ほど別 goroutine で起動した readLoop で受信される！
	// ch に readLoop からの受信結果が格納されることを思い出す！！
	pc.reqch <- requestAndChan{
		req:        req.Request,
		cancelKey:  req.cancelKey,
		ch:         resc,
		addedGzip:  requestedGzip,
		continueCh: continueCh,
		callerGone: gone,
	}

	// 色々と例外処理があるが、一番欲しいのは readLoop から resc にデータが渡された時。
	for {
		select {
		...
		// readLoop から送信されるチャネルを受け取る。
		case re := <-resc:
			if (re.res == nil) == (re.err == nil) {
				panic(fmt.Sprintf("internal error: exactly one of res or err should be set; nil=%v", re.res == nil))
			}
			if debugRoundTrip {
				req.logf("resc recv: %p, %T/%#v", re.res, re.err, re.err)
			}
			if re.err != nil {
				return nil, pc.mapRoundTripError(req, startBytesWritten, re.err)
			}
			return re.res, nil
		...
		}
	}
}
```

これで http.RoundTrip から結果が返されるところまで追うことができました。

## キャンセルされると何が起こるのか

『終端ではどのような処理が行われているのか気になったため』と言っておきながら、その確認を何もしてませんでした、すみません。

野生の勘が、`dialConn` で goroutine 実行した `go pconn.readLoop()` が怪しいと言ってるので、再度確認してみます。

``` go
func (pc *persistConn) readLoop() {
	defer func() {
		pc.close(closeErr)
		pc.t.removeIdleConn(pc)
	}()

    ...
	alive := true
	for alive {
		...

		select {
		case rc.ch <- responseAndError{res: resp}:
		case <-rc.callerGone:
			return
		}

		// Before looping back to the top of this function and peeking on
		// the bufio.Reader, wait for the caller goroutine to finish
		// reading the response body. (or for cancellation or death)
		select {
		case bodyEOF := <-waitForBodyRead:
			replaced := pc.t.replaceReqCanceler(rc.cancelKey, nil) // before pc might return to idle pool
			alive = alive &&
				bodyEOF &&
				!pc.sawEOF &&
				pc.wroteRequest() &&
				replaced && tryPutIdleConn(trace)
			if bodyEOF {
				eofc <- struct{}{}
			}
		case <-rc.req.Cancel:
			alive = false
			pc.t.CancelRequest(rc.req)
		case <-rc.req.Context().Done():
			alive = false
			pc.t.cancelRequest(rc.cancelKey, rc.req.Context().Err())
		case <-pc.closech:
			alive = false
		}

		testHookReadLoopBeforeNextRead()
	}
}
```

`pc.t.cancelRequest` が怪しいですが、結論だけ言うとこれは今回大したことなさそうです。

それよりも `readLoop` を抜けた時に実行される `pc.close(closeErr)` に着目してみます。

``` go
func (pc *persistConn) close(err error) {
	pc.mu.Lock()
	defer pc.mu.Unlock()
	pc.closeLocked(err)
}

func (pc *persistConn) closeLocked(err error) {
	if err == nil {
		panic("nil error")
	}
	pc.broken = true
	if pc.closed == nil {
		pc.closed = err
		pc.t.decConnsPerHost(pc.cacheKey)
		// Close HTTP/1 (pc.alt == nil) connection.
		// HTTP/2 closes its connection itself.
		if pc.alt == nil {
			if err != errCallerOwnsConn {
				pc.conn.Close()
			}
			close(pc.closech)
		}
	}
	pc.mutateHeaderFunc = nil
}
```

辿り着きました！  
`pc.conn.Close()` でコネクションがあああああああああああ閉じられてそうです！！

`persistConn.closech` のチャネルが close されるようです。

`Conn` はインタフェースのため、今回は具体的な実装として `net.conn` を調べてみます。

### Conn が close されること

`net.conn` は、net のファイルディスクリプタを唯一のフィールドに持つ構造体です。

``` go
type conn struct {
	fd *netFD
}

// Network file descriptor.
type netFD struct {
	pfd poll.FD

	// immutable until Close
	family      int
	sotype      int
	isConnected bool // handshake completed or use of association with peer
	net         string
	laddr       Addr
	raddr       Addr
}
```

`Close()` メソッドでは、さらに `netFD.Close` を呼んでいます。

``` go
// Close closes the connection.
func (c *conn) Close() error {
	if !c.ok() {
		return syscall.EINVAL
	}
	err := c.fd.Close()
	if err != nil {
		err = &OpError{Op: "close", Net: c.fd.net, Source: c.fd.laddr, Addr: c.fd.raddr, Err: err}
	}
	return err
}
```

やっと syscall 見えてきてそれっぽくなりました。

``` go
func (fd *netFD) Close() error {
	runtime.SetFinalizer(fd, nil)
	return fd.pfd.Close()
}
```

// src/internal/poll package

``` go
// Close closes the FD. The underlying file descriptor is closed by the
// destroy method when there are no remaining references.
func (fd *FD) Close() error {
	if !fd.fdmu.increfAndClose() {
		return errClosing(fd.isFile)
	}

	// Unblock any I/O.  Once it all unblocks and returns,
	// so that it cannot be referring to fd.sysfd anymore,
	// the final decref will close fd.sysfd. This should happen
	// fairly quickly, since all the I/O is non-blocking, and any
	// attempts to block in the pollDesc will return errClosing(fd.isFile).
	fd.pd.evict()

	// The call to decref will call destroy if there are no other
	// references.
	err := fd.decref()

	// Wait until the descriptor is closed. If this was the only
	// reference, it is already closed. Only wait if the file has
	// not been set to blocking mode, as otherwise any current I/O
	// may be blocking, and that would block the Close.
	// No need for an atomic read of isBlocking, increfAndClose means
	// we have exclusive access to fd.
	if fd.isBlocking == 0 {
		runtime_Semacquire(&fd.csema)
	}

	return err
}
```

`evict` で I/O を解放し、`decref` で fd を破棄しているみたいです。

### evict

一旦保留。

### decref

``` go
func (fd *FD) decref() error {
	if fd.fdmu.decref() {
		return fd.destroy()
	}
	return nil
}

// Destroy closes the file descriptor. This is called when there are
// no remaining references.
func (fd *FD) destroy() error {
	// Poller may want to unregister fd in readiness notification mechanism,
	// so this must be executed before CloseFunc.
	fd.pd.close()

	// We don't use ignoringEINTR here because POSIX does not define
	// whether the descriptor is closed if close returns EINTR.
	// If the descriptor is indeed closed, using a loop would race
	// with some other goroutine opening a new descriptor.
	// (The Linux kernel guarantees that it is closed on an EINTR error.)
	err := CloseFunc(fd.Sysfd)

	fd.Sysfd = -1
	runtime_Semrelease(&fd.csema)
	return err
}
```

#### fd.pd.close()

// internal/poll/fd_poll_runtime.go

``` go
func runtime_pollClose(ctx uintptr)

func (pd *pollDesc) close() {
	if pd.runtimeCtx == 0 {
		return
	}
	runtime_pollClose(pd.runtimeCtx)
	pd.runtimeCtx = 0
}
```


ここからは runtime 固有のコードなので環境差分が出そうです。

以下は `linux/arm64` の例で、`src/runtime/netpoll.go` に記載があります。

``` go
//go:linkname poll_runtime_pollClose internal/poll.runtime_pollClose
func poll_runtime_pollClose(pd *pollDesc) {
	if !pd.closing {
		throw("runtime: close polldesc w/o unblock")
	}
	wg := pd.wg.Load()
	if wg != 0 && wg != pdReady {
		throw("runtime: blocked write on closing polldesc")
	}
	rg := pd.rg.Load()
	if rg != 0 && rg != pdReady {
		throw("runtime: blocked read on closing polldesc")
	}
	netpollclose(pd.fd)
	pollcache.free(pd)
}
```

このうち `netpollclose` に着目してみます。

``` go
func netpollclose(fd uintptr) uintptr {
	var ev syscall.EpollEvent
	return syscall.EpollCtl(epfd, syscall.EPOLL_CTL_DEL, int32(fd), &ev)
}

// runtime/internal/syscall
type EpollEvent struct {
	Events uint32
	_pad   uint32
	Data   [8]byte // to match amd64
}

func Syscall6(num, a1, a2, a3, a4, a5, a6 uintptr) (r1, r2, errno uintptr)
func EpollCtl(epfd, op, fd int32, event *EpollEvent) (errno uintptr) {
	_, _, e := Syscall6(SYS_EPOLL_CTL, uintptr(epfd), uintptr(op), uintptr(fd), uintptr(unsafe.Pointer(event)), 0, 0)
	return e
}
```

Syscall6 の実態はどこにあるかというと、`src/runtime/internal/syscall/asm_linux_arm64.s` にあります。

``` c
#include "textflag.h"

// func Syscall6(num, a1, a2, a3, a4, a5, a6 uintptr) (r1, r2, errno uintptr)
TEXT ·Syscall6(SB),NOSPLIT,$0-80
	MOVD	num+0(FP), R8	// syscall entry
	MOVD	a1+8(FP), R0
	MOVD	a2+16(FP), R1
	MOVD	a3+24(FP), R2
	MOVD	a4+32(FP), R3
	MOVD	a5+40(FP), R4
	MOVD	a6+48(FP), R5
	SVC
	CMN	$4095, R0
	BCC	ok
	MOVD	$-1, R4
	MOVD	R4, r1+56(FP)
	MOVD	ZR, r2+64(FP)
	NEG	R0, R0
	MOVD	R0, errno+72(FP)
	RET
ok:
	MOVD	R0, r1+56(FP)
	MOVD	R1, r2+64(FP)
	MOVD	ZR, errno+72(FP)
	RET
```

6つの引数を受け取っており、1つ目が `SYS_EPOLL_CTL`, 3 つ目が `EPOLL_CTL_DEL` であることまでわかっています。

このコードを読むことは１回諦めますが、無事最深部まで辿り着きました。  
（[EPOLL_CTL_DEL のシステムコール](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/epoll_ctl.2.html)が呼ばれることを strace を使って確認まではしました。）

もっといっぱいシステムコール読んでるので、気になる方は読んでみてください。

## Context をキャンセルさせてみる

コードを追ってくだけだったので、実際に context をキャンセルさせてみたいと思います。

適当に、５秒程度待ってからレスポンスを送るサーバーを起動します。

``` go
package main

import (
	"fmt"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		now := time.Now()

		for {
			select {
			// サーバーとして request のキャンセルを受け取る。
			case <-r.Context().Done():
				fmt.Println("Context DONE!!")

				return
			default:
				time.Sleep(300 * time.Millisecond)

				// 5 秒以上たったらクライアントに送信。
				if time.Now().After(now.Add(5 * time.Second)) {
					w.Write([]byte("hello"))

					return
				}
			}
		}
	})

	http.ListenAndServe(":21829", nil)
}
```

5 秒立つ前にクライアント側からキャンセルさせてみます。


``` go
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"time"
)

// t.dialConnFor(w) と pconn.readLoop() の分の増加が確認できる？
// pconn.writeLoop() に関してはなんで増加されない？
func numGoroutines() {
	// 1 msec とか細かくすると、call done 前に一瞬だけ 5 になるタイミングがある。
	interval := 50 * time.Millisecond

	for range time.Tick(interval) {
		fmt.Printf("runtime.NumGoroutine(): %v\n", runtime.NumGoroutine())
	}
}

func main() {
	ctx, _ := context.WithTimeout(context.Background(), 829*time.Millisecond)

	go numGoroutines()
	time.Sleep(150 * time.Millisecond)

	fmt.Println("make req")
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://localhost:21829", nil)

	client := http.DefaultClient

	fmt.Println("call start")
	resp, err := client.Do(req)
	fmt.Println("call done")

	time.Sleep(300 * time.Millisecond)
	if err != nil {
		fmt.Printf("err: %v\n", err)
		if errors.Is(err, context.Canceled) {
			fmt.Println("canceled error")
		}
		if errors.Is(err, context.DeadlineExceeded) {
			fmt.Println("DeadlineExceeded error")
		}

		return
	}

	defer resp.Body.Close()
}
```

クライアント・サーバーのログから、一定時間でキャンセルされたこと、キャンセルをサーバーで受け取れたことが分かります。

ただ、`t.dialConnFor(w)` と `pconn.readLoop()` と `pconn.writeLoop()` の3つの goroutine が増えるのかと思ったのですが、なぜか2つしか増えませんでした。。。  
何かわかる方は教えてください。

## Links

- [man-pages epoll_ctl](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/epoll_ctl.2.html)
- [man-pages recv](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/recv.2.html)
- [network system calls](https://linasm.sourceforge.net/docs/syscalls/network.php)

## おわりに

Go のコードを読むことができて面白かったです。

個人的には最初、ctx でキャンセルされた場合とそれ以外でコード差分がある（もっといえば呼んでるシステムコールとかも違うのかも？）と思って進めていたので、ほぼ差分がなかったのが意外でした。

今度は address を bind する部分についてもコードをおっていってみたいです。

（epoll とかわかってみたい。）
