# [ShellCheck](https://www.shellcheck.net/) から学ぶ良いスクリプトの書き方 〜SC2086(ダブルクォート)編〜

とりあえずは**変数はダブルクォーテーションで囲もう**ってことなんですが、囲まないとどうなるか少し調べてみました。

**[目次]**

- [Double quote to prevent globbing and word splitting.](#double-quote-to-prevent-globbing-and-word-splitting)
  - [globbing](#globbing)
  - [word splitting](#word-splitting)
- [おまけ](#%E3%81%8A%E3%81%BE%E3%81%91)
- [おわりに](#%E3%81%8A%E3%82%8F%E3%82%8A%E3%81%AB)

今回は簡単な部類である [SC2086](https://www.shellcheck.net/wiki/SC2086) から確認していきます。

[ShellCheck](https://www.shellcheck.net/) のサイトや、[ShellCheck の拡張機能](https://github.com/vscode-shellcheck/vscode-shellcheck)の入った VSCode などで以下のようなコードを打ちます。

```sh
#!/bin/bash

d="true = true -o x"
if [ $d = "pien" ]; then
    echo "d is equal to pien"
fi
```

すると以下のようなエラーが表示されます。

```sh
$ shellcheck myscript

Line 4:
if [ $d = "pien" ]; then
     ^-- SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean: (apply this, apply all SC2086)
if [ "$d" = "pien" ]; then
```

つまりは『ダブルクォーテーション（"）』で囲めば解決するんですが、今回は**囲まなかったらどうなるか・なぜこれが良くないのか**について少し調べてみました。

## Double quote to prevent globbing and word splitting.

どうやら `Double quote` は何かを防いでくれるようです。

一つずつ見ていきます。

### globbing

まず glob についてはマニュアルの [3.5.8 Filename Expansion](https://www.gnu.org/software/bash/manual/html_node/Filename-Expansion.html) にちょっと書いてありますが、要は『bash 用に定義された特殊なパターン』と思っていいんじゃないでしょうか。

```sh
// こんなやつ
$ ls *.py
```

『ダブルクォーテーションで囲むと、この `glob` 展開を禁止するよ！』と言ってるんですね。

**具体例**  
例えば次のような例を考えます。

```sh
# なんかの演算の結果、ファイル名に * がきてしまった。
file_name="*"
# このままでは file_name がエスケープされていないので、
# sh の拡張子のファイルが全部表示される。
ls $file_name.sh

# ===== Output =====
'*.sh'   check.sh   echo_script.sh   test.sh
```

文字列で受け取っている以上、期待結果としては '\*.sh' のファイル**1 つのみ**なはずです。

ShellCheck の指示通り `"` で囲んであげたら期待値通り `*.sh` のファイルにのみヒットします。

```sh
# なんかの演算の結果、ファイル名に * がきてしまった。
file_name="*"
# '*.sh' というファイル名にのみヒットする
ls "$file_name.sh"

# ===== Output =====
'*.sh'
```

### word splitting

bash では**空白で一息つく**癖があるので、スペースが含まれてると文字列じゃないように解釈されてしまってやばいよ！ってことです。

**具体例**  
これは結構問題になる例が浮かんでくるかと思いますが、とりあえず 1 つ。

```sh
# なんかの拍子で d に以下のような文字列が入ってきた！
d="true = true -o x"
# 実はここは true になるので、意図しないタイミングで if 節の中が実行される！
if [ $d = "pien" ]; then
    echo "variable d is equal to pien"
fi
```

コマンド `[` では `-o` オプションは `OR` の役割を果たしており、`$d = "pien"` とかいた時は次『のどちらかが成立する時』という条件式になっています。

- `true = true`
- `x = "pien"`

つまり 1 つ目の式が絶対に真となるため、**意図せず if ブロックが実行されてしまいます！**

SQL インジェクションみたいだな〜〜って思って考えていました。

## おまけ

glob の文字列を含むファイル名を作成できるの？って感じですが、以下のようにすれば可能でした。

```sh
$ touch \*.sh
$ touch '*.sh'
```

## おわりに

ShellCheck は偉大だけど納得して使いたい。
