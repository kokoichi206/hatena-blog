# IntelliJ IDEA での便利な設定
[IntelliJ IDEA](https://www.jetbrains.com/ja-jp/idea/) は JetBrains 社が開発する JVM 向け IDE です。  
デフォルト状態でも十分便利な IntelliJ IDEA を、今回は自分用にアレンジしてみたいと思います。  
チームのコーディングスタイル等に合わせて拡張してみてください。

以下で紹介する設定の Tips は、PyCharm などの JetBrains 社が開発する IDE, また Android Studio 等でも似たような設定があると思われます。

## バージョン
```
- IntelliJ IDEA 2021.3.2 (Community Edition)
```

## 個人用設定
以下で設定名を検索するときは、『shift 2 回タップし表示されるウィンドウ』を使って検索しています。

### 最終行に改行を入れる（保存時）
「Ensure every saved file ends with a line break」を有効にする。

これで、「Ctrl + S」で保存をすると、自動的に最終行に改行が入るようになります。

### 保存時にフォーマットを適応
「actions on save」と入力。

「Reformat code」を有効にし、対象ファイルと対象範囲を選択してください。  
他必要に応じて「Optimize imports」等にもチェックを入れましょう。

これで、「Ctrl + S」で保存をすると、自動的にフォーマットが走るようになります。kotlint, detekt 等の個人で設定したフォーマットを使用する方法は分かりません。

## おわりに
全員が IntelliJ IDEA を使って開発する際には、今回紹介したような自動フォーマット等を上手に利用して、無駄なところで使う時間を減らしたいですね！
