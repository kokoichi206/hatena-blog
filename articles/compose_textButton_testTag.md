# Text ではなく TextButton に testTag をつける
今回は compose のテストに使用する testTag のつける場所についてハマった話をしようと思います。

## 環境
```
- compose_version = '1.0.1'
- targetSdk 26
- kotlinCompilerVersion '1.5.21'
```

## Text に testTag をつけたら失敗した話
TextButton を使って compose のテストをしようとした際、

「実際にテキストが書いてあるのは Text の方だから、Text の方に testTag つけたらいいだろう」

と思って下記のように testTag をつけていましたが、これでは Node の取得に失敗しました。

```kotlin
TextButton() {
    Text(
        modifier = Modifier
            .testTag(TestTags.CACHE_CLEAR_DIALOG_CANCEL),
        text = stringResource(R.string.clear_cache_cancel),
    )
}
```

いろいろ試した結果、TextButton 側（親側）の Modifier に textTag を設定するとうまく Node が取れたうえに、**その文字列も期待通り**になっていました！

```kotlin
TextButton(
    modifier = Modifier
        .testTag(TestTags.CACHE_CLEAR_DIALOG_CANCEL),
) {
    Text(
        text = stringResource(R.string.clear_cache_cancel),
    )
}
```

## おわりに
なかなか一発で Node が取れることがなく悲しいです。
