# マルチモジュールでの compose navigation におけるベストプラクティス（Android DevSummit）

[Compose の nagitaion における multi module 対応](https://developer.android.com/jetpack/compose/navigation?hl=ja)についての内容を youtube で見ました（["Type safe, multi-module best practices with Navigation Compose"](https://www.youtube.com/watch?v=goFpG25uoc8&ab_channel=AndroidDevelopers)）。

この中で 5 つのベストプラクティスが紹介されていたため、簡単に紹介します。

## Compose のスクリーンでは State を入力とし events を出力とせよ

```kotlin
@Composable
fun ColumnWithLine(
    uiState: MemberListUiState,
    onNavigateToParticipantList: (conversationId: String) -> Unit,
) {
    ...
}
```

Screen はデータがどこから来たかを気にするべきではなく、例えば viewmodel であったり、適当な値が入ってようが動くようにするべきである。  
また、誰がイベントを受け取るかも気にするべきではない。

独立性を高めて、テストを容易にするメリットもある。

## navigation graph も分割せよ

画面ごとに `feature` module を分解した際に、`app` module 等で Navigation の設定をするかと思います。  
『その Navigation のグラフ設定も、`feature` module 側に含めよ』ということです。

ルートの設定をするのは、使われる側（モジュール）の役目ということですね。

`feature/settings/navigation/settings.kt`

```kotlin
const val settingsRoute = "settings_route"

// NavGraphBuilder にメソッドを生やす
fun NavGraphBuilder.settingsScreen(
    onThemeChanged: (String) -> Unit,
) {
    composable(route = settingsRoute) {
        SettingsScreen {
            onThemeChanged(it)
        }
    }
}
```

例えば `app` 側で呼び出すには以下のようにします。

```kotlin
@Composable
fun BottomNavHost(
    navHostController: NavHostController,
    onThemeChanged: (String) -> Unit
) {
    NavHost(
        navController = navHostController,
        startDestination = BottomNavItem.Home.route
    ) {
        homeScreen()

        // こんな感じで使える！
        settingsScreen(onThemeChanged)
```

## 必要な Public API のみを公開せよ

Argument の設定等、公開しなくてもいいものは `internal` をつけるなどして、他モジュールに公開しないようにします。

また、[VisibleForTesting annotation](https://developer.android.com/reference/androidx/annotation/VisibleForTesting) を使ってテストように公開することも可能です。

```kotlin
@VisibleForTesting
internal const val authorIdArg = "authorId"

internal class AuthorArgs(val authorId: String) {
    constructor(savedStateHandle: SavedStateHandle, stringDecoder: StringDecoder) :
        this(stringDecoder.decodeString(checkNotNull(savedStateHandle[authorIdArg])))
}
```

## Module 構造と Graph 構造はセットに考えるべき

module を分割しその公開 API を決めることで、Graph 構造も定まるようにするべきです。

特に、module 間で遷移することはやめるべきであり、遷移メソッドを公開し上位メソッドから呼び出すように修正します。

公開する遷移のためのメソッドを `NavController` に生やす。

```kotlin
fun NavController.navigateToMemberDetail(member: Member) {
    this.navigateUp()
    this.navigate(
        memberDetailRoute
                + "/$memberJson=${getJsonFromMember(member)}"
    )
}
```

上位モジュールから呼び出す。

```kotlin
NavHost(
    navController = navHostController,
    startDestination = BottomNavItem.Home.route
) {
    memberListScreen {
        navHostController.navigateToMemberDetail(it)
    }
```

## リソースを随時確認せよ

最後のベストプラクティスは、以下リソースを随時確認しよう、ということです。

- [Documentation: Type safety in Kotlin DSL and Navigation Compose](https://developer.android.com/guide/navigation/navigation-type-safety)
- [NowInAndroid app: sample app](https://github.com/android/nowinandroid)

## おわりに

[NowInAndroid app: sample app](https://github.com/android/nowinandroid) のアプリは非常に完成度高そうなので、積極的に参考にしていきたいです。
