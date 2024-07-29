# SwiftUI で URL の画像を表示させる方法
今回は SwiftUI において、`AsyncImage`を使ってURLの画像を表示させる方法についてメモしておきます。

## AsyncImage
「URL の画像を表示させる方法」について調べると色々とややこしそうな方法が出てくるのですが、** Xcode13 & iOS15**からは簡単にかける方法があり、それが`AsyncImage`です。

名前から想像のつくように、「非同期で画像をロードし表示させる」ということを行なっています。

### 使い方
使い方を簡単に説明します（詳しくは[公式のドキュメント](https://developer.apple.com/documentation/swiftui/asyncimage?changes=latest_major)を参照）。

ローカルの Asset を表示させるときに使っていた`Image`の部分を、以下のように`AsyncImage `に変更します。

``` swift
AsyncImage(url: URL(string: "https://example.com/icon.png"))
    .frame(width: 200, height: 200)
```

### 注意点
`Image`などに使われるような一部の modifier についてはそのままでは使えず、以下のように一旦`Image instance`として受け取ってから処理を行う必要があります。

``` swift
AsyncImage(url: URL(string: "https://example.com/icon.png")) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
.frame(width: 50, height: 50)
```

これは公式のドキュメントにも以下のように記述があります。

> **Important**

>You can’t apply image-specific modifiers, like resizable(capInsets:resizingMode:), directly to an AsyncImage. Instead, apply them to the Image instance that your content closure gets when defining the view’s appearance.

### 使用例
「自分の顔写真の周りを遠景にクリップし、その周りに縁をつける」という、よくありそうなユースケースでは以下のように記述します

``` swift
AsyncImage(url: URL(string: urlString)) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
.frame(width: length, height: length)
.aspectRatio(contentMode: .fill)
.clipShape(Circle())
.background(
    Circle()
        .stroke(Color.purple, lineWidth: 4)
)
```

![](img/face_icon.png)

## おわりに
最近は Android や機械学習系の学習をすることが多かったのですが、先週から突然 SwiftUI を始めてみました。

書きやすく気に入っているので、ちょくちょくやることになるかもしれません。
