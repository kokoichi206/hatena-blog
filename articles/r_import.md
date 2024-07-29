# Jetpack Compose で R の import がされない！

## 環境
```
- compose_version = '1.0.1'
- targetSdk 26
- kotlinCompilerVersion '1.5.21'
```

## 問題点
以下のように composable 関数の中で string リソースファイルの文言を使いたいケースを考えます。

```
Text(
    text = stringResource(id = R.string.your_feet)
)
```

この時何かの import 文が優先され、間違った R で解釈され続けて string の部分に赤字が出てくる場合があります。

しかも困ったことに import 文に分かりやすい R はありません。

## 解決策
いろいろ試してみたのですが、以下の方法が手っ取り早いです。

1. import 文をコメントアウトする
2. R の左右どっちかにキャレッジを合わせ、alt + enter で R を import


## おわりに
compose の version で変わってくるかもしれませんが、一発で R は出てきて欲しいと思います。
