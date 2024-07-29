Apache 2.4 を使ってコンテンツを置いているサーバーで、HTML の `<head>` 内に `<meta charset="UTF-8">` をつけているのに文字化けが発生する現象が発生しました。

これは次のように `content` を指定したら解決しました。

```html
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
```
