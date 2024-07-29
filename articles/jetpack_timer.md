# Jetpack Compose でタイマー処理を実装する
タイマーを Android で作りたいことがあり、その際 Jetpack Compose で定期ループみたいなもの実装しました。

Kotlin で実装を行うには Timer や Runnable を用いることが多いそうですが、Jetpack compose では以下のように`LaunchedEffect`を用いて簡単に実装できます。


``` kotlin
var deadLine by remember {
    mutableStateOf(20000)
}
var cTime by remember {
    mutableStateOf(10000)
}
LaunchedEffect(key1 = deadLine, key2 = cTime) {
    if (cTime > 0) {
        // delay で指定秒数（ミリ秒）だけ間隔を開ける
        delay(100)
        // 時間の更新処理
        cTime -= 100
        // （必要なら）update 処理
    }
}
```

`key1, key2` に指定したキーを監視し、値が変更されると`LaunchedEffect`の中身が実行されます。（`key`は１つでも構いません。）

`LaunchedEffect`の中身で**監視対象である`cTime`の更新をおこなっているので、ブロック終了後に再度`LaunchedEffect`が呼ばれます**。

これが上記コードがタイマー処理として働く理由となります。

