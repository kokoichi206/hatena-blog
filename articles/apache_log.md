# apache access_log 中の User-Agent まとめ

現在 apache のアクセスログの解析を自分でやってみようと進めております。アクセスログの中には UserAgent の欄が存在し、UserAgent には Scraping の際に苦しめられた思い出があります（以下記事）。

そこで今回は、自分の所有する色々な端末からどのようにログとして見られるかまとめてみようと思います。

[https://koko206.hatenablog.com/entry/2021/10/26/204256:embed:cite]

[目次]

[:contents]

## 環境
```
- Apache/2.4.41 (Ubuntu)
```

## Apache Access log 中の UserAgent
apache のアクセスログは以下のようになっており、今回はそのうちの最終行（UserAgent）に注目します。

```
111.11.111.111 - - [17/Nov/2021:12:06:06 +0000] "GET / HTTP/1.1" 200 5393 "-" \
"Mozilla/5.0 (iPhone; CPU iPhone OS 14_8_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari Line/11.19.2"
```

以下、User-Agent に欄は、長いので改行している場合があります。

### iPhone X: Safari
```
Mozilla/5.0 (iPhone; CPU iPhone OS 14_8_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari Line/11.19.2
```

### Line 上でのプレビュー
```
facebookexternalhit/1.1;line-poker/1.0
```

ライン上のプレビューに関してもアクセスが出るようで驚きました。

### Pixel 3: Chrome
**Linux**; Android って書いてあるの少しワクワクしますね！？

```
Mozilla/5.0 (Linux; Android 12; Pixel 3) 
AppleWebKit/537.36 (KHTML, like Gecko) 
Chrome/95.0.4638.74 Mobile Safari/537.36
```

### Pixel 3: Brave
後半は全く Chrome の時と同じなんですね。

つまりどういうことでしょう？？

```
Mozilla/5.0 (Linux; Android 12) 
AppleWebKit/537.36 (KHTML, like Gecko) 
Chrome/95.0.4638.69 Mobile Safari/537.36
```

### Mac : Chrome
Safari の記述があるのには驚きました。

```
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) 
AppleWebKit/537.36 (KHTML, like Gecko) 
Chrome/95.0.4638.69 Safari/537.36
```

### Mac: Safari
```
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) 
AppleWebKit/605.1.15 (KHTML, like Gecko) 
Version/14.1.2 Safari/605.1.15
```

### Win10 (Dell latitude): Chrome
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) 
AppleWebKit/537.36 (KHTML, like Gecko) 
Chrome/95.0.4638.69 Safari/537.36
```

### Win10 (Dell latitude): Edge
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) 
AppleWebKit/537.36 (KHTML, like Gecko) 
Chrome/95.0.4638.69 Safari/537.36 Edg/95.0.1020.53
```

### Win10 (Dell latitude): IE
N 年ぶりに IE 開きました。今までより幾分かシンプルです。

```
Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0)
 like Gecko
```

### Golang からスクレイピング (agent 指定なし)
golang のコード

```go
req, _ := http.NewRequest("GET", BaseUrl, nil)

client := &http.Client{}
resp,_ := client.Do(req)
```

User-Agent

```
Go-http-client/1.1
```

### Golang からスクレイピング (agent 指定あり)
golang のコード

```go
req, _ := http.NewRequest("GET", BaseUrl, nil)

client := &http.Client{}
resp,_ := client.Do(req)
req.Header.Add("User-Agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1")
```

User-Agent

```
Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) 
AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 
Mobile/13B143 Safari/601.1
```

ちょっと長いですが、指定した User-Agent がそのまま入っていることがわかります

### python requests (agent 指定なし)
python のコード

```
import requests

BaseUrl = "xxx.yyy.zzz"
res = requests.get(BaseUrl).content
```

User-Agent

```
python-requests/2.26.0
```

### python requests (agent 指定あり)
python のコード

```
import requests

BaseUrl = "xxx.yyy.zzz"
headers = {"User-Agent": "Mozilla/5.0"}
res = requests.get(BaseUrl, headers=headers).content
```

User-Agent

```
Mozilla/5.0
```


## おわりに
自分がサーバーの管理者だったとして、`Go-http-client/1.1, python-requests/`のようなアクセスはあんまり嬉しくないなぁと思いました。

一方で、こんなに簡単に偽造（？）できる User-Agent にどれだけの意味があるんだろう、と疑問に思いました。

何はともあれ、引き続き apache のアクセスログ解析を進めていきます。
