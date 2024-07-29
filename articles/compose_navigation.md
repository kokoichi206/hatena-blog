# Jetpack Compose で Navigation を利用した View の切り替え

こんにちは、kokoichi です。

最近は Android 開発において Jetpack Compose を真面目に学んでいます。

今回は Navigation を利用した View の切り替え方法を学んだので、その方法についてまとめまてみます。


## Navigation について
自分の理解は次のようなものです。

- 今まで：Intent を作って StartActivity で Activity を移動していた
- Navigation：Vue の Router っぽく、パス名に対してどの Composable を描画するかを記述する
  - （Activity と Composable は同じものではないが）

大雑把な使い方は、公式のサイトを見るとイメージできると思います。

```kotlin
// Navigation の定義
NavHost(navController = navController, startDestination = "profile") {
  // profile という(いわゆる)パス名に対して、Profile というコンポーザブルを対応させる
  composable("profile") { Profile(/*...*/) }
  composable("friendslist") { FriendsList(/*...*/) }
  /*...*/
}

// コンポーザブルに移動する
@Composable
fun Profile(navController: NavController) {
    /*...*/
    Button(onClick = { navController.navigate("friends") }) {
        Text(text = "Navigate next")
    }
    /*...*/
}
```

[Compose を使用したナビゲーション (公式)](https://developer.android.google.cn/jetpack/compose/navigation?hl=ja#kts)


### 構成例
以下に、自分の考えた構成例を示します。

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            SakamichiAppTheme {
                // A surface container using the 'background' color from the theme
                Surface(color = MaterialTheme.colors.background) {
                    // MainView()
                    App()
                }
            }
        }
    }
}

// Navigation の定義
@Composable
fun App() {
    val navController = rememberNavController()
    NavHost(navController, startDestination = "main") {

        // 使いたい場所まで、引数として渡してあげる必要がある
        composable("main") { MainView(navController) }
        composable("checker") { CheckView() }

        // userData は Member クラスを Json オブジェクトにして渡してあげる
        composable(
            route = "detailed/user={user}",
            arguments = listOf(navArgument("user") { type = NavType.StringType })
        ) { backStackEntry ->  // 受け取った時の処理を記述

            val name = backStackEntry.arguments?.getString("user")

            // Composable を呼び出す
            DetailedView(name.toString())
        }
    }
}

//
// 以下のように、navController を伝播させていく
//
@Composable
fun MainView(navController: NavHostController) {
    Column {
        GroupList()
        MembersList("hoge", navController)
    }
}
// navController を実行させる場所
@Composable
fun MembersList(name: String, navController: NavHostController){
    Column(
        modifier = Modifier.clickable {

            val ROUTE_MEMBER_DETAILS = "detailed" + "/user=" + name
            navController.navigate(ROUTE_MEMBER_DETAILS)
        }
}
```

個人的に、以下の２点には注意する必要があると思いました

- Composable 内部で NavController の定義を行なっているため、グローバル変数などで他の関数と共有できない
  - バケツリレーのように引数に渡し続けることで、トリガーとなる場所まで NavController を渡す必要がある
    - （Vue に似ている）
- composable 定義の部分には、route 内の arguments として String, Int, Boolean などは指定できるが、独自のクラスオブジェクトは指定できない
  - （`NavTyoe.`まで打つと入力補完候補で指定できるタイプが出てきます）
- navigate の無限ループにならないように注意する



## 参考にしたサイト
[Compose を使用したナビゲーション (公式)](https://developer.android.google.cn/jetpack/compose/navigation?hl=ja#kts)

[Navigation を使った時の Composable の大枠の配置方法](https://qiita.com/Nabe1216/items/f329e981f0da76c1d221)


## おわりに
今回は Compose を使ったナビゲーションにについて、基本的な考え方と構成する方法について紹介しました。

まだまだ Compose について勉強しているので今後もその関連の記事を書けたらと思っています。
