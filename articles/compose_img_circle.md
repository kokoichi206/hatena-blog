# 【JetPack Compose】Image で長方形の写真を正円にカットする方法
元の形が長方形の画像を正円に切り取る際に、地味に調べるのに時間がかかったのでメモしておこうと思います。

[目次]

[:contents]

## うまくいかなかった例
`Modifier.clip()`に対し、以下のように指定しましたが上手くいきませんでした。

Modifier の情報を他にも追加してみましたが、効果的なものはありませんでした。

```kotlin
@Composable
fun ImageTest() {
    Image(
        painter = painterResource(R.drawable.test),
        modifier = Modifier
            .size(300.dp)
            .clip(CircleShape),
        contentDescription = "test image"
    )
}
```

### その時の写真

<figure class="figure-image figure-image-fotolife" title="300dp">[f:id:kokoichi206:20211105184857p:plain]<figcaption>300dp</figcaption></figure>


## 改善策
以下のように`contentScale`を指定してあげます。

```kotlin
@Composable
fun ImageTest() {
    Image(
        painter = painterResource(R.drawable.test),
        modifier = Modifier
            .size(300.dp)
            .clip(CircleShape),
        contentDescription = "test image",
        // crop the image if it's not a square
        contentScale = ContentScale.Crop,
    )
}
```

[f:id:kokoichi206:20211105185300p:plain]

ただしこのままでは長辺に対し、常に中央で写真が切り取られてしまいます。

### 上部分を用いて正円を作る
正円を切り取る部分を中央からずらしたい場合、以下のように`alignment`を指定します。

```kotlin
@Composable
fun ImageTest() {
    Image(
        painter = painterResource(R.drawable.test),
        modifier = Modifier
            .size(300.dp)
            .clip(CircleShape),
        contentDescription = "test image",
        // crop the image if it's not a square
        contentScale = ContentScale.Crop,
        alignment = Alignment.TopStart
    )
}
```

[f:id:kokoichi206:20211105185837p:plain]


