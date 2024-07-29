# retrofit を使った compose UI testing で could not find  any node が出た

以下のような状況で compose の UI のテストをしていたら、なかなか希望の node が取れませんでした。

自分の探す方向性が悪くなかなか解決できなかったので、その反省を兼ねて記録しておきます。

- [公式の compose Test 記事](https://developer.android.com/jetpack/compose/testing)を参考に compose の UI テストを進めていた
- retrofit の API 通信に関しては mock を使用
  - 結論から言うと、この retrofit-mock の設定が原因でした

[目次]

[:contents]

## 環境
```
- compose_version = '1.0.1'
- targetSdk 31
- kotlinCompilerVersion '1.5.21'
- retrofit2:retrofit:2.9.0
- retrofit2:retrofit-mock:2.9.0
```

## 失敗した時の androidTest の記述
あるボタンをタップして、その後に指定したテキストが表示されるかのチェックを行おうとしてました。

そして、ボタンを押した際に retrofit で記述した API が走るような構成です。

```kotlin
    @Test
    fun playPage_displayAfterTappingButton() {
        // Arrange

        // Act
        composeRule
            .onNodeWithText("expectedStr")
            .performClick()

        // Assert
        // Check the Logcat (Debug , "TAG")
        composeRule.onRoot().printToLog("TAG")
        composeRule
            .onNodeWithTag(TestTags.PLAY_QUIZ_TITLE)
            .assertExists()
    }
```

### エラー
以下のように、「node が見つからないよ」というエラーが出ました。

```
E/TestRunner: java.lang.AssertionError: Failed: assertExists.
    Reason: Expected exactly '1' node but could not find 
any node that satisfies: (TestTag = 'PLAY_QUIZ_TITLE')
```

compose のテストに慣れていないため、記述の仕方が悪いのかと何度もいろんなところに書き直したりしてました。


## retrofit の mock の記述
ここからは、問題となっていた retrofit の mock の部分です。

retrofit-mock は、通信の振る舞いとして、答時間を設定できるのですが、自分がそこで 100 ms と指定していることを忘れていました。

```kotlin
    fun provideMyApi(): MyApi {
        val retrofit = Retrofit.Builder()
            .baseUrl(Constants.BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()

        // ここから、mock を作成している
        val behavior = NetworkBehavior.create()

        // ここの通信時間が問題となっていた！
        behavior.setDelay(100, TimeUnit.MILLISECONDS)
        behavior.setVariancePercent(0)
        behavior.setFailurePercent(0)
        behavior.setErrorPercent(0)

        val mockRetrofit = MockRetrofit.Builder(retrofit)
            .networkBehavior(behavior)
            .build()

        val delegate = mockRetrofit.create(MyApi::class.java)

        return MockMyApi(delegate)
    }
```

## 解決策
API 通信が終わってから対象が描画されるようになっていたため、通信が終わる前に node を探しても「そんなものはないよ〜」と言われてる状況でした。

### retrofit-mock の応答時間を 0 にする
上記の mock の設定で`behavior.setDelay(100, TimeUnit.MILLISECONDS)`となっていた部分を、単純に`behavior.setDelay(0, TimeUnit.MILLISECONDS)`と置き換えてあげます。

そうすると Node が見つかるようになります。

### retrofit の通信が走った後に sleep を入れてあげる
うまくいくと思っていたのですが成功するかわかりません。

何か別のテストで通信時間を確保しておいた方がいい場合は、以下のように一旦処理を止めてあげて（仮想の）通信が終わるのを待つようにします。

```kotlin
        // 300 ms 処理を止める
        Thread.sleep(300L)
        composeRule
            .onNodeWithTag(TestTags.PLAY_QUIZ_TITLE)
            .assertExists()
```


## おわりに
今回は、エラー解消のために見るべき方向が違ったまま、時間を浪費してしまった話をしました。

論理的に効率よく原因を特定していけるようになりたいです。
