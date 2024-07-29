### android studio のメソッドが真っ赤になった！
テストメソッドのほとんどのファイルで、多くのメソッドが真っ赤になる現象が発生しました。

import 文を見て、赤文字の対象となっていたものには以下のようなものがありました。

```
androidx.test.xxx
org.junit.Assert.*
```

### 試してみたこと
以下のようなことをしてみましたが、一向に解決しませんでした。

- FIle > Invalidate Caches/Restart
- Android Studio 再起動
- .idea フォルダの削除
- PC の再起動

### 解決方法
**Build Variants を Release -> Debug にすると解決しました**。

テストクラスでのみエラーが出ていた時点で、もっと早くに気づくべきでした。
