# navigation-compose のパラメータの受け渡し方でハマった話

[目次]

[:contents]

今回は [Compose を使用したナビゲーション](https://developer.android.com/jetpack/compose/navigation?hl=ja)を使用した際に、ルーティングのパラメータの渡し方でハマった話をしようと思います。

## navigation-compose の使い方
[公式]((https://developer.android.com/jetpack/compose/navigation?hl=ja))にある通りですが、簡単に説明します。

### 設定
まず、アプリケーションレベルの build.gradle に以下の依存関係を追加します。

```
dependencies {
    /*...*/
    implementation("androidx.navigation:navigation-compose:2.4.0-alpha09")
}
```

### ルートの登録
さらに、以下のように Composable な関数とパスを紐付けたものを、MainActivity 生成時に登録します。

```kotlin
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {

        super.onCreate(savedInstanceState)

        setContent {
            MyAppTheme {
                Surface(color = MaterialTheme.colors.background) {
                    SakamichiApp(viewModel)
                }
            }
        }
    }
}

@Composable
fun SakamichiApp(viewModel: HomeViewModel) {

    val navController = rememberNavController()

    // Composable な関数とパスを紐付ける
    NavHost(navController, startDestination = "main") {

        composable("main") {  // main というパスに登録
            MainView(navController)   // Composable な関数
        }

        composable("about") {
            About()
        }

        // パラメータの受け取り方
        composable(
            route = "detailed/userName={userName}",
            arguments = listOf(navArgument("userName") { type = NavType.StringType })
        ) { backStackEntry ->
            // 受け取った時の処理を記述
            val userName = backStackEntry.arguments?.getString("userData")

            DetailedView(userName, navController)
        }
    }
}
```

### ルートの呼び出し
呼び出すときは、controller の navigate() メソッドを利用します

```kotlin
@Composable
fun MainView(navController: NavController) {
    /*...*/
    Button(onClick = { navController.navigate("about") }) {
        Text(text = "Navigate about")
    }

    var name = "watashinonamae"
    // パラメータの渡し方
    Button(
        onClick = { 
            val navigate_url = "detailed/userName=" + name
            navController.navigate(navigate_url) 
        }
    ) {
        Text(text = "parameter test")
    }
    /*...*/
}
```

Activity を切り替えてない点が面白いと思いです。


## 今回ハマったところ！
前置きが長くなってしまいましたが、今回はパラメータを渡すときに、特定の文字には気をつけよう！という話をします。

結論としては、URL エンコードをしようという話です。

### パラメータの渡し方
先ほど紹介した例では、route の登録の際に / につづける感じでパラメータを登録しました。

```kotlin
@Composable
fun SakamichiApp(viewModel: HomeViewModel) {
    /* ... */
    NavHost(navController, startDestination = "main") {
        /* ... */
        // パラメータの受け取り方
        composable(
            route = "detailed/userName={userName}",
            arguments = listOf(navArgument("userName") { type = NavType.StringType })
        ) { backStackEntry ->
            // 受け取った時の処理を記述
            val userName = backStackEntry.arguments?.getString("userData")

            DetailedView(userName, navController)
        }
    }
}
```

他にも、URL のパスパラメータやクエリパラメータと全く同じようなノリで、パラメータを与えることができます。

- detailedPage/{name}
- detailedPage/name={name}
- detailedPage?name={name}

### URL などを渡す際の注意
これが今回ハマった点なのですが、次のようなパラメータを含むルートを登録し、使いたい url を渡していました。

```
route = "webView/url={url}"
```

使い方

```kotlin
val url = "https://www.youtube.com/watch?v=1_oWkusqP4Q"
val navigate_url = "webView/url=" + url
navController.navigate(navigate_url) 
```

上の URL のように渡したパラメータ中に **/ や ? など**が含まれると、大量のエラーを吐いてアプリが落ちる現象に遭遇します（日本語をパラメータで渡すのは大丈夫でした）。



### 対応方法
渡されたルーティングに /, ? が含まれると navigation 側がパラメータの指定が始まったと解釈してしまうのが問題でした。

そこで、渡す前に URL エンコーディングを（ /,? にだけ）適応してあげます。今回は 2 文字だけだったので、簡単に文字列の置き換えで対応しました。

```kotlin
NavHost(navController, startDestination = "main") {
    // 受け取り側は変更する必要なし
    composable(
        route = "webView/url={url}",
        arguments = listOf(navArgument("url") { type = NavType.StringType })
    ) { backStackEntry ->
        WebViewWidget(url)
    }
}

val SLASH_ENCODED = "%2F"
val QUESTION_ENCODED = "%3F"

Button(
    onClick = {
        // ?,/ に関しては URL エンコーディングを適応
        val encodedUrl = rawUrl.
            .replace("/", SLASH_ENCODED)
            .replace("?", QUESTION_ENCODED),
        val WEB_VIEW_URL = "webView" + "/url=$encodedUrl"
        navController.navigate(WEB_VIEW_URL)
    }
) {
    Text(text = "助けて...")
}
```

## おわりに
今回は、jetpack compose navigation の簡単な紹介と、その際パラメータのやり取りでハマった話をしました。Compose の UI の宣言の仕方や今回のルーティングの方法など、Vue とかなり近い部分を感じ、簡単に記述できて感激です！

次回以降も Jetpack 関連についての記事を書くかもしれません。

