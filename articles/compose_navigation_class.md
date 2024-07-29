# navController でクラスインスタンスを扱う（Jetpack Compose）

こんにちは、kokoichi です。

前回の記事では Navigation を使った簡単な composable の構成方法について紹介しました。


[https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/edit?entry=13574176438016197569:embed:cite]


その際データオブジェクトを引数として渡す方法について苦しめられたので、今回はその方法についてまとめます。


## Navigation 内の Composable の引数にクラスオブジェクトを使用したい
ここでは、以下のようなデータクラスを渡すことを考えてみます。

```kotlin
data class MemberProps(
    val name: String = "name",
    val name_ja: String = "名前",
    val group: String = "グループA",
    val height: String? = null
)
```

### class の型を変更する
前回の記事でもお話ししましたが、カスタムしたオブジェクトを navController の中の type として指定することはできません。

そこで方針としては、文字列の情報として渡してあげることとします。

今回は Gson を用いて Json と変換しました。


### 必要なコード

```kotlin
// 設定側
NavHost(navController, startDestination = "main") {

    composable("main") { MainView(navController) }

    // userData は Member クラスを Json オブジェクトにして渡してあげる
    composable(
        route = "detailed/userData={userData}",
        arguments = listOf(navArgument("userData") { type = NavType.StringType })
    ) { backStackEntry ->
        // 受け取った時の処理を記述、
        // Json が渡ってくるので、それをオブジェクトに変換する
        Log.d(TAG, "Received: " + backStackEntry.arguments.toString())

        val userJson = backStackEntry.arguments?.getString("userData")

        Log.d(TAG, userJson.toString())
        val memberProps = Gson().fromJson<MemberProps>(userJson, MemberProps::class.java)
        DetailedView(memberProps, navController)
    }
}

// 呼び出し側
@Composable
fun OnePerson(navController: NavHostController, groupName: String) {
    Column(
        modifier = Modifier.clickable {
            Log.d(TAG, person.name_ja + " clicked")

            // FIXME: 以下の理由で、MemberProps を作っている。URL に注意
            // Props で渡すときに、URL は JSON デコードがなんか上手くできなかった
            val userProps = MemberProps(
                name = "name"
                name_ja = "お名前を",
                group = "ほげ",
                heigt = "179cm"
            )

            // Gson を使って カスタムしたオブジェクトを Json に変更する！
            val jsonUser = Gson().toJson(userProps)
            val ROUTE_MEMBER_DETAILS = "detailed" + "/userData=" + jsonUser
            // ビューを呼び出す
            navController.navigate(ROUTE_MEMBER_DETAILS)
        }
    ) {
        if (person.imgUrl == null) {
            Image(
                painter = painterResource(id = R.drawable.profile_picture),
                contentDescription = 
```


## 参考にしたサイト
[Navigation を使った時の Composable の大枠の配置方法](https://qiita.com/Nabe1216/items/f329e981f0da76c1d221)

[NavHost において Json 変換を行う](https://stackoverflow.com/questions/67121433/how-to-pass-object-in-navigation-in-jetpack-compose)

[Gson と Moshi の比較（どちらも kotlin で Json を扱うもの）](https://qiita.com/m-coder/items/d3eabbd2e6f12522434b)

## おわりに
今回は Compose を使ったナビゲーションにおいて、文字列以外を受け渡しする方法について紹介しました。

まだまだ Compose について勉強しているので、その関連の記事を書けたらと思っています。
