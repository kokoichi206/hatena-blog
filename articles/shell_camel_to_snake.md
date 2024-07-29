## ユースケース

**H**ogeFuga → **h**ogeFuga みたいな『先頭のみの大文字小文字を変換する』ということがしたいケースがありました。

同じ要領で『キャメルケース → スネークケース（逆も）』ができたのでその紹介です。

（注: 以下コマンドの結果はすべて GNU sed によるものです。）

## まとめ

``` sh
# キャメルケース → スネークケース
$ echo HogeFuga | gsed 's@[A-Z]@_\L&@g' | gsed 's/^_//'
hoge_fuga

# スネークケース → キャメルケース
$ echo hoge_fuga_pien | gsed -E 's@_(.)@\U\1@g'
hogeFugaPien
$ echo hoge_fuga_pien | gsed -E 's@_(.)@\U\1@g' | gsed 's@^.@\U&@'
HogeFugaPien
```

<!-- more -->

## sed などの shell で変換

``` sh
# mac の場合は gsed を使う
brew install gnu-sed
```

``` sh
# 先頭のみを大文字にする
## . により任意の1文字に match する。
## match した部分は & で表し、その前に \L をつけることで Lower case へと変換される。
$ echo HogeFuga | gsed 's@.@\L&@'
hogeFuga
## match 部分を取り出す方法についてはよりきめ細かに指定することも可能。
$ echo HogeFuga | gsed -E 's@(.)@\L\1@'
hogeFuga

# キャメルケース → スネークケースにする
## 大文字（[A-Z] にマッチする1文字）を _ + 小文字 に変換する。
$ echo HogeFuga | gsed 's@[A-Z]@_\L&@g'
_hoge_fuga
## 先頭に _ があるケースのみ削除する。
$ echo HogeFuga | gsed 's@[A-Z]@_\L&@g' | gsed 's/^_//'
hoge_fuga
$ echo hogeFuga | gsed 's@[A-Z]@_\L&@g' | gsed 's/^_//'
hoge_fuga

# スネークケース → キャメルケースにする
$ echo hoge_fuga | gsed -E 's@_(.)@\U\1@'
hogeFuga
## 先頭も大文字にしたいとき。
$ echo hoge_fuga | gsed -E 's@_(.)@\U\1@' | gsed 's@^.@\U&@'
HogeFuga
```

## おまけ

### VSCode 置換

VSCode の Ctrl + F で出てくる検索窓において、正規表現をオンにすると基本は同じことができます。

マッチした文字を取り出す時の作法が少し違う程度です。

```
FROM: ^.
TO: \U$&
```

- `$&`:  マッチした全体を表す
  - `$`: VSCode では1つ目を `$1` などで表す
  - `&`: 全体を表す
- `\U`: upper case
- `\L`: lower case
