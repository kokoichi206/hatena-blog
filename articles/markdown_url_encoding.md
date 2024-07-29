# markdown のリンクで URL のなかに () がある時に失敗する

`https://example.com/hoge()pi` のようなリンクがある時、ナイーブに

``` markdown
[title](https://example.com/hoge()pi)
```

としてしまうと、[title](https://example.com/hoge()pi) のようになります。

表示も期待値ではないし、リンクも正しくありません。

そんな時は **URL 部分を パーセントエンコーディング**してあげると良さそうです。

今回の例で具体的に言うと、

- `(` -> `%28`
- `)` -> `%29`

のように変換してあげます。

その他の定義は [MDM](https://developer.mozilla.org/ja/docs/Glossary/Percent-encoding) 等をご参照ください。

すなわち、

``` markdown
[title](https://example.com/hoge%28%29pi)
```

のように記載してあげると、[title](https://example.com/hoge%28%29pi) となり期待値通りになります。
