# GCS の Golang クライアント使用時の注意

[googleapis/google-cloud-go](https://github.com/googleapis/google-cloud-go) を使って GCP に書き込みをするクライアントを作成している時に、メソッド名につられてしまった箇所があったのでその共有です。

## 結論

- Write メソッドが走った段階では実際に GCS へ書き込まれるわけではない
  - バッファされてる
- Close メソッドで実際に書き込みされる
  - 名前がよくない

<!-- more -->

## 問題のあるコード

みなさん、以下のコードがレビューで回ってきた時どう対応するでしょうか？

``` go
package main

import (
	"context"
	"fmt"

	"cloud.google.com/go/storage"
)

func createObject(ctx context.Context, body []byte, bucketName, objectName string) error {
	cli, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create gcs client: %w", err)
	}
	defer cli.Close()

	w := cli.Bucket(bucketName).Object(objectName).NewWriter(ctx)
	defer w.Close()

	if _, err := w.Write(body); err != nil {
		return fmt.Errorf("failed to write: %w", err)
	}

	return nil
}

func main() {
	ctx := context.Background()
	if err := createObject(ctx, []byte("pien"), "pien", "pien"); err != nil {
		log.Fatal(err)
	}
}
```

Closer を実装している構造体に対し、生成直後に defer で Close することはよくあることですし、そこ失敗しないだろって感じでエラーハンドリングを省略することも多いかと思ってます。

これが罠でした。。。

### 騙されポイント

[storage#ObjectHandle.NewWriter](https://pkg.go.dev/cloud.google.com/go/storage#ObjectHandle.NewWriter) の返す構造体の [Close メソッド](https://pkg.go.dev/cloud.google.com/go/storage#Writer.Close)をよくみてみると、以下のような記載があります。

> Close completes the write operation and flushes any buffered data.
> If Close doesn't return an error, metadata about the written object can be retrieved by calling Attrs.

また、よくみると [Write メソッド](https://pkg.go.dev/cloud.google.com/go/storage#Writer.Write)にも以下のような記載があります。

> Since writes happen asynchronously, Write may return a nil error 
> even though the write failed (or will fail). 
> Always use the error returned from Writer.Close to determine if the upload was successful.

どうやら **Write メソッドの段階では buffer に書き込まれるだけ**で、**Close の段階になって初めて GCS へのアクセスが走る**らしいです。

## 修正案

Close メソッドのエラーが実際の書き込みエラーのため、そこをきちんと拾ってあげます。

defer のなかでエラーハンドリングをしたかったため、名前付き戻り値を使いました（メソッドの最後に Close でも可）。

``` go
func createObject(ctx context.Context, body []byte, bucketName, objectName string) (err error) {
	ctx, cancelCause := context.WithCancelCause(ctx)

	cli, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create gcs client: %w", err)
	}
	defer cli.Close()

	w := cli.Bucket(bucketName).Object(objectName).NewWriter(ctx)
	defer func() {
		if err != nil {
			cancelCause(err)

			return
		}

		if writeError := w.Close(); writeError != nil {
			err = fmt.Errorf("failed to write: %w", writeError)

			return
		}
	}()

	if _, err := w.Write(body); err != nil {
		return fmt.Errorf("failed to write: %w", err)
	}

	return nil
}
```

> To stop writing without saving the data, cancel the context.

また、[ObjectHandle.NewWriter](https://pkg.go.dev/cloud.google.com/go/storage#ObjectHandle.NewWriter) の説明に ↑ とあるため、エラー発生時には cancel させるようにしました。

この状態で実行すると、きちんとエラーとして返ってくることがわかります。

``` sh
$ go run *.go

2024/08/01 01:40:42 failed to write: googleapi: Error 404: The specified bucket does not exist., notFound
exit status 1
make: *** [run] Error 1
```

## c.f. os.File はどうか

以下のようなコードを書いて適当に試してみたのですが、Close 前に書き込みはされてるようでした。

``` go
package main

import (
	"os"
	"time"
)

func fileWrite() {
	f, _ := os.Create("testes.txt")
	defer f.Close()

	f.Write([]byte("Hello, World!"))

	time.Sleep(10 * time.Second)
}
```

## 最後に

最近はよく Google Cloud を触っているため、ハマったところがあればまた共有いたします！
