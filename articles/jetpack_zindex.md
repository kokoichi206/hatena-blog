# Jetpack Compose で縦方向のスタック（SwiftUI の ZStack）
Jetpack Compose を触っていて画像の上に画像を重ねたいケースが出てきました。  
そこで今回は、SwiftUI での `ZStack`, CSS での `z-index` のようなものを実現する方法を紹介します。

## 実装例
Modifier に zIndex が用意されているので、そちらを使用します。  
CSSと同様に値が大きいほど手前に表示されます。

Box, Column, Row, Image, など様々な Composable に適応可能でした。

``` kotlin
@Composable
fun Map() {
    ...
    Column(
        modifier = Modifier
            .zIndex(1f)
    ) {
        ...
    }
    Image(
        painter = painterResource(id = R.drawable.player_2),
        contentDescription = null,
        modifier = Modifier
            .height(size)
            .width(size)
            .zIndex(2f)
    )
    Column(
        Modifier
            .padding(40.dp)
            .size(100.dp)
            .zIndex(3f),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))
        Image(
            painter = painterResource(id = R.drawable.player_2),
            contentDescription = null,
            modifier = Modifier
                .zIndex(3f)
        )
        Spacer(modifier = Modifier.weight(1f))
    }
}
```


## おわりに
zIndex のように数値で指定する系だと、他で書いた値を考慮する必要があります。  
一方で、SwiftUI の ZStack は Column, Row のように Stack に積んでいくだけなのでより直感的でいいな、と思いました。
