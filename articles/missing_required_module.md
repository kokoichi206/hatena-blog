# SwiftPM を使用中にテストコードで missing required module 'xxx'
Swift Package Manager（SwiftPM）を使ってパッケージ管理をしており、firebase 関連のインストールを行なっていました。

そんな中、swiftUI の UITest を記載しようとした時 `missing required module 'FirebaseFirestore'` のエラーに悩まされたので、その解決策についてメモしておきます。

## Binary の Link 先に追加する
1. Project トップのアイコンをクリックする
2. TARGETS から UITest ターゲットを選択する
3. Build Phase > Link Binary With Libraries を確認する
4. エラーのでたライブラリがなければ追加する

[f:id:kokoichi206:20220316204038p:plain]

## @testable でメインプロジェクトを import する
これだけだとエラー解決しませんでしたが、テスト用の Tag 情報などを使用する際に必要でした。

``` swift
import XCTest
@testable import MainProject

class MainProjectTests: XCTestCase {

}
```


## おわりに
Android Studio に比べて、XCode はスムーズにいかない部分が多い気がします。。。
