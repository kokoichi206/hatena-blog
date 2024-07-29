# m1 mac で Execution failed for task ':app:kaptDebugKotlin'.

m1 mac で、今まで通ってたビルドが通らない現象が発生しました。

その際のエラーメッセージと解決策をメモしておきます。

## エラー内容

```
Execution failed for task ':app:kaptDebugKotlin'.
> A failure occurred while executing 
org.jetbrains.kotlin.gradle.internal.KaptWithoutKotlincTask$KaptExecutionWorkAction
   > java.lang.reflect.InvocationTargetException (no error message)
```

## 解決策
[この質問サイト](https://youtrack.jetbrains.com/issue/DBE-12342)によると SQLite のバージョンが問題のようです。

> SQLite supported M1 in versions greater or equal than 3.34.0. Check your dependencies list.

今回は [room ライブラリ](https://developer.android.com/training/data-storage/room?hl=ja)で用いる SQLite が原因でした。

`kapt "org.xerial:sqlite-jdbc:3.34.0"`を依存関係（アプリレベルの build.gradle）に追加します

```
dependencies {
    ...

    // Room
    implementation "androidx.room:room-runtime:2.3.0"
    kapt "androidx.room:room-compiler:2.3.0"

    // Fix sqlite database error in m1 mac
    kapt "org.xerial:sqlite-jdbc:3.34.0"
}
```

## Links
- [[Apple Silicon] Cannot connect to SQLite datasource on M1](https://youtrack.jetbrains.com/issue/DBE-12342)

## おわりに
今まで動いてたプロジェクトが動かなくなったかと思って焦りました。

gradle 周りにはまだ苦手意識があるので、自信を持って Android の環境構築できるよう頑張ります