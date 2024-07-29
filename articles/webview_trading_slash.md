# ”正しいはず”の URL が WebView で開けない
ブラウザで開ける”正しいはず”の URL が WebView で開けない症状に遭遇しました。

結論としては「渡した URL に最後のスラッシュが抜けていた」という単純なものでしたが、今まで意識したことがなかったので発見が遅れてしまいました。

[目次]

[:contents]

## 環境
```
- jvmTarget = '1.8'
- kotlinCompilerVersion '1.5.21'
- webView: versionName=95.0.4638.74
```

## 忙しい人まとめ
```
- URL の最後の "/" はブラウザが勝手に補完することがある
- WebView では補完してくれないので、完全なものを渡す必要がある
```

## トレイリング スラッシュ (Trailing Slash)

### トレイリング スラッシュ (Trailing Slash) とは
URL の最後につく "/" のことを「トレイリング スラッシュ」と呼ぶそうです。

"/" がつく URL はフォルダへのアクセスを表し、"/" がつかない URL は特定のファイルへのアクセスを表します。

### "/" を忘れるとどうなる？
実は "/" をつけ忘れた場合でも、ブラウザもしくはサイトが気を利かせて、うまくルーティングしてくれることがほとんどです。

例えば、次のような最後にスラッシュのない URL にアクセスした場合でも、きちんとサイトが表示でき、さらにアドレスバーの URL には "/" が補完されていることがわかります！

> https://www.nogizaka46.com/schedule

今回はこのブラウザの機能により URL が間違っていたことが隠蔽され、URL 自体を疑うのに時間がかかってしまいました。

### WebView ではどうか
（おそらく）WebView は trading slash を自動で補ってくれないため、渡す URL にはその辺も注意する必要があります。

## 今回の自分の WebView の実装
念のため今回の webview の実装方法を記述しておきます。

```kotlin
@Composable
fun WebViewWidget(
    contentUrl: String
) {
    AndroidView(
        factory = {
            WebView(it)
        },
        update = { webView ->
            webView.webViewClient = WebViewClient()
            webView.loadUrl(contentUrl)
        }
    )
}
```

### エラー内容
webView に渡した "正しいはず" の URL が開けず、次のようなエラーに遭遇しました。

```
Not Found
The requested URL /... was not found on this server
```

WebView に渡された URL を Log で出力し chrome で開いてみたところ普通に開けていたので、原因の調査に時間がかかってしまいました。


## 解決方法
汎用的な方法は分かっておりませんが、自分は渡す URL に正しいもの（"/" が必要なものはきちんとつける）を渡すことで対応しました。

汎用的にやろうとするなら、表示させる前に "/" の有り無しで status code を調べるのはありかな、とも思いました。

## おわりに
URL がブラウザで開けるからといって、それが正しいものではない可能性があることを学びました。

正しいはずの URL が WebView などで表示できない時は、トレイディングスラッシュの可能性を１回疑ってみるのはありだと思います。
