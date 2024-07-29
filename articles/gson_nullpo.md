# Retrofit & Gson Converter でぬるぽ

以下のようなセットで API をコールしていた時に、『Non-null と思っていたのにぬるぽが発生する』ということが起きてしまいました。

- HTTP クライアントとして [Retrofit](https://square.github.io/retrofit/)
- JSON to クラスのコンバーターとして [Gson](https://github.com/square/retrofit/tree/master/retrofit-converters/gson)

## 原因

- API サーバーで api-key が無効の時に status-code 200 (期待値は 400) + エラーメッセージを返してきてた
  - これは [cgi について自分の理解が足りてなかったのが原因](https://github.com/android-project-46group/api-server/issues/34)なのですが、その話はまた今度。。。
- ステータス 200 なので Retrofit は通信成功とみなし、converer (Gson) によるデコードを開始する
  - デコードに失敗（**返却値が Null**）しても**エラーは出ずに処理が進み、**どっかでぬるぽ発生

## まとめ

```
- 『JSON ⇒ データクラス』のデコード等では、失敗時にサイレントで null が返ってくるかもしれない
    - return のタイプを Non-null で定義してたのに。。。
  - ライブラリを使う時は注意！
    - 注意しすぎても良さが減るよな。。。
```

## 該当コード

ぬるぽ発生部

```kotlin
// getMembers(groupName).members がぬるのため NullPointerException
// こんぱいら（Android Studio）は無知なので気づいていない！！！
val members = repository.getMembers(groupName).members.map { it.toMember() }
```

Retrofit 定義部

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DataModule {

    // API
    @Provides
    @Singleton
    fun provideSakamichiApi(): SakamichiApi {
        val okHttpClient = OkHttpClient.Builder()
            ...
            .build()
        return Retrofit.Builder()
            .baseUrl(Constants.BASE_URL)
            .client(okHttpClient)
            // ========== Gson を converter として指定！ ==========
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(SakamichiApi::class.java)
    }
    ...
}

interface SakamichiApi {

    @GET("api/v1/members")
    suspend fun getMembers(
        @Query("gn") groupName: String,
        @Query("key") apiKey: String = "",
    ): MembersDto  // ========== ここでは Non-null で data class を定義している！ ==========
    ...
}
```

## 対応案

結果 2 つ目の、他の converter (Moshi) を使ってデコードさせました。
Moshi には [failOnUnknown](https://square.github.io/moshi/1.x/moshi/moshi/com.squareup.moshi/-json-adapter/fail-on-unknown.html) というのがありそれを利用しました。

- Gson, Retrofit 側に『Decode に失敗したら例外を投げる』的な設定ができないか確認
  - 多分無理
- [他の converter](https://github.com/square/retrofit/tree/master/retrofit-converters) だと挙動変わらないかな～～っての試す
- API の返却値をぬらぶるにして、コンパイラに教えてあげる
  - てっとりばやいが、無駄に Nullable にするのはいややな。。。

## おわりに

Android Studio と Gson を信じた私がおろかでした。
