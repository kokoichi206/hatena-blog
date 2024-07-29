# Basic 認証のあれこれ

非常に今更ですが、徳丸本 §3.1 ででてきたため、実際に手を動かして確認してみました。

**目次**

## まとめ

- URL の中に Basic 認証情報を含めることができる
  - **URL を共有する時は注意**
  - ログアウトも
- 暗号化されてない通信では Basic 認証を使わない

## おさらい

### Basic 認証とは

basic 認証とは、サイトにアクセスしたときにたまに表示されるあれです。

![](img/basic_login.png)

簡単な設定で認証機能を実装できますが、使用の際にはいくつか注意点があるので調べておきました。

### 基本的な仕組み

基本的な仕組みは他の記事に任せるとして、押さえておきたいのは次の2点です。

- HTTP リクエストの **Authorization: ヘッダー**に base64 encode されたものが埋め込まれる
  - **可逆**（decode 可能）
- ブラウザでログインした場合は**メモリ領域にキャッシュされ次回以降のアクセスで使いまわされる**
  - 必要に応じてログアウトすること

## Basic 認証の認証情報を URL に埋め込む

基本的には URL に1回アクセスした後に『ユーザー名・パスワード』を打つことになるんですが、以下のようにあらかじめ URL に打ち、ログイン画面を省略することも可能です。

```　sh
# `user:password` とドメインの間を `@` で区別する
http://user:password@example.jp/secret
```

`user:password` とドメインの間を `@` で区別するのですが, user や password の部分に `@` を使いたくなった場合は、[パーセントエンコーディング](https://url.spec.whatwg.org/#percent-encoded-bytes)を使うと回避できます。

[`@` をエンコードすると `%40` になる](https://developer.mozilla.org/ja/docs/Glossary/Percent-encoding)ので、`user` = `hoge@example.com` を打ちたければ以下のようにします。

``` sh
http://hoge%40example.com:password@example.jp/secret
```

![](img/http-basic.png)

ちなみに URL に埋め込む機能は**ブラウザが頑張ってくれている**機能であり、他のクライアント等で期待したらダメかもしれない？と思いました。

また『**URL の中に認証情報が入ることになるので、うっかり URL を不特定多数の人に共有しない**』ことには注意するようにお願いします。

### Go の標準パッケージの場合　

Go の標準パッケージのクライアントでも、URL 内の Basic 認証の情報が、正しく Authorization ヘッダーに変換されるようになっていました。

具体的には、まず**各リクエスト前に URL を解析する部分**で認証情報の解析が行われています。　

``` go
url, _ := url.Parse("http://hoge%40example.com:password@example.jp/secret/")

// url.Scheme: http
fmt.Printf("url.Scheme: %v\n", url.Scheme)
// url.Host: example.jp
fmt.Printf("url.Host: %v\n", url.Host)
// url.User: hoge%40example.com:password
fmt.Printf("url.User: %v\n", url.User)
// url.Path: /secret/
fmt.Printf("url.Path: %v\n", url.Path)
```

[ソースコードはこの辺](https://github.com/golang/go/blob/go1.21.3/src/net/url/url.go#L579-L612)が該当します。


また、request の中の URL フィールドに格納された認証情報は、`client.do` の中の `send()` で[ヘッダー情報に変換されて](https://github.com/golang/go/blob/go1.21.3/src/net/http/client.go#L247-L253)使われています。

``` go
if u := req.URL.User; u != nil && req.Header.Get("Authorization") == "" {
	username := u.Username()
	password, _ := u.Password()
	forkReq()
	req.Header = cloneOrMakeHeader(ireq.Header)
	req.Header.Set("Authorization", "Basic "+basicAuth(username, password))
}
```

## ログイン状態のリセット

URL に user, password を記入できることを説明しましたが、それを利用してログアウトする（認証情報をブラウザから消す）ことも可能です。

``` sh
# わざと間違った認証情報で上書きする。
## Chrome だと上書きされない可能性もあり、ブラウザ依存が大きそう。
http://user:wrong@example.jp/secret
```

もっとも、db 等に保存されてるわけではなさそうなため、再起動をかけると消えるような挙動をしていますが。

**参考**

- [How to clear basic authentication details in chrome](https://stackoverflow.com/questions/5957822/how-to-clear-basic-authentication-details-in-chrome)

## HTTP 通信の時（暗号化されてない時）

暗号化されてない HTTP リクエストで Basic 認証の通信をした場合、その内容が盗聴された場合認証情報が漏れてしまうことになります。

これは、Basic 認証のパスワード等の情報は **HTTP リクエストのヘッダー**に載っているだけであること + **base64 エンコーディングが可逆**であることに起因しています。

実際に wireshark を使ってパケットをキャプチャしてみたのが以下の写真になります。

Authorization ヘッダーにバッチリ情報が載っていることがわかります。

![](img/http_basic.png)

このため、今更ではありますが、**HTTP 通信の時は Basic 認証を使用しない**よう徹底したいです。

### HTTPS ではどう見えるか

では、TLS で暗号化された HTTPS の通信ではどう見えるのでしょうか？

実際にパケットをキャプチャしてみたのが下の画像になります。

![](img/https-basic.png)

HTTP の時に Hypertext Transfer Protocol として見えていた HTTP レイヤーの情報が、**Transport Layer Security に変更され中身が見えなくなっている**ことがわかります。

また、**ESNI**（Encrypted Server Name Indication）対応されたブラウザからであれば、**送り先のドメイン情報も暗号化の対象に入り**ます。

## Apache でベーシック認証設定時

Apache では特定のフォルダ配下を簡単に認証の対象にすることができますが、この時 `SSLRequireSSL` をつけるだけで SSL を必須にすることができます。

``` xml
<Directory /var/www/html/github>
    SSLRequireSSL
    AuthType Basic
    AuthName "Basic Authentication"
    AuthUserFile /etc/apache2/.htpasswd
    require valid-user
</Directory>
```

ちなみに `SSLRequireSSL` がついた状態で HTTP でアクセスすると **403 が返って**きます。
