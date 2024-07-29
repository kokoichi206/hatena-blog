# JetPack Compose の文脈で Action Bar を変更する
JetPack Compose を使い簡単にアクションバーを変更する方法があったのでその紹介です。

## 環境
```
- compose_version = '1.0.1'
- targetSdk 31
- kotlinCompilerVersion '1.5.21'
```

## 実装

### Action Bar
アクションバーとは、端末上部の時間などが表示されている部分のことを指します。

[f:id:kokoichi206:20211106032140p:plain]


### Accompanist
今回は google の出している [Accompanist](https://github.com/google/accompanist) というライブラリを使いました。

> Utils for Jetpack Compose

とあるように、Permissions, Pager, Placeholder, Navigation などなど様々な便利なものを用意してくれてるようです。

今回はそのうちの [System UI Controller](https://github.com/google/accompanist/tree/main/systemuicontroller) を使っています。

### 依存関係の追加
applicatoin レベルの build.gradle の dependencies に、以下の一行を追加します。

```
implementation "com.google.accompanist:accompanist-systemuicontroller:0.17.0"
```

### コード変更箇所
以下のように Composable 関数内で systemUiController を読んであげることで、それ以降（MainView() 以降）では Action bar の変更が適応されます。

```kotlin
@Composable
fun TestScreen() {
    // Change color of ActionBar using systemuicontroller.
    val systemUiController = rememberSystemUiController()
    systemUiController.setSystemBarsColor(
        color = Color.White,
        // color = Color.Transparent // For dark mode ?
    )
    
    CustomTheme() {
        MainView()
    }
}
```

## 参考サイト
- [Accompanist Github
](https://github.com/google/accompanist)
- [how to change statusbar color in jetpack compose? (Stack overflow)](https://stackoverflow.com/questions/65610216/how-to-change-statusbar-color-in-jetpack-compose)

## おわりに
今回はライブラリを使って簡単にアクションバーを変更する方法を紹介しました。

今後も jetpack compose に関する記事を書いていくつもりでいます。
