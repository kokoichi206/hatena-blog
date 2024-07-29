# bash スクリプト作成 1 日目に知りたかったこと

いまだに自分も初心者ですが、　**初心者から見て初めに知っておきたかったこと**、**思いがけず詰まったこと**をメモしておきたいと思います。  
誰か（来年のぼく）の参考になればと思います。

- [環境](#%E7%92%B0%E5%A2%83)
- [結論](#%E7%B5%90%E8%AB%96)
- [スタイル編](#%E3%82%B9%E3%82%BF%E3%82%A4%E3%83%AB%E7%B7%A8)
  - [変数](#%E5%A4%89%E6%95%B0)
  - [[ はコマンドです！](#-%E3%81%AF%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89%E3%81%A7%E3%81%99)
- [エラーが起きてもスクリプトは終わらない](#%E3%82%A8%E3%83%A9%E3%83%BC%E3%81%8C%E8%B5%B7%E3%81%8D%E3%81%A6%E3%82%82%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%81%AF%E7%B5%82%E3%82%8F%E3%82%89%E3%81%AA%E3%81%84)
  - [エラー時にスクリプトを止めるオプション](#%E3%82%A8%E3%83%A9%E3%83%BC%E6%99%82%E3%81%AB%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%92%E6%AD%A2%E3%82%81%E3%82%8B%E3%82%AA%E3%83%97%E3%82%B7%E3%83%A7%E3%83%B3)
- [未定義変数の取り扱いに注意する](#%E6%9C%AA%E5%AE%9A%E7%BE%A9%E5%A4%89%E6%95%B0%E3%81%AE%E5%8F%96%E3%82%8A%E6%89%B1%E3%81%84%E3%81%AB%E6%B3%A8%E6%84%8F%E3%81%99%E3%82%8B)
  - [未定義変数使用時にスクリプトを終了するオプション](#%E6%9C%AA%E5%AE%9A%E7%BE%A9%E5%A4%89%E6%95%B0%E4%BD%BF%E7%94%A8%E6%99%82%E3%81%AB%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%92%E7%B5%82%E4%BA%86%E3%81%99%E3%82%8B%E3%82%AA%E3%83%97%E3%82%B7%E3%83%A7%E3%83%B3)
- [パイプは最後の終了ステータスしか見ない](#%E3%83%91%E3%82%A4%E3%83%97%E3%81%AF%E6%9C%80%E5%BE%8C%E3%81%AE%E7%B5%82%E4%BA%86%E3%82%B9%E3%83%86%E3%83%BC%E3%82%BF%E3%82%B9%E3%81%97%E3%81%8B%E8%A6%8B%E3%81%AA%E3%81%84)
  - [パイプ失敗時にエラーを吐かせる](#%E3%83%91%E3%82%A4%E3%83%97%E5%A4%B1%E6%95%97%E6%99%82%E3%81%AB%E3%82%A8%E3%83%A9%E3%83%BC%E3%82%92%E5%90%90%E3%81%8B%E3%81%9B%E3%82%8B)
  - [パイプはそれでも実行されます](#%E3%83%91%E3%82%A4%E3%83%97%E3%81%AF%E3%81%9D%E3%82%8C%E3%81%A7%E3%82%82%E5%AE%9F%E8%A1%8C%E3%81%95%E3%82%8C%E3%81%BE%E3%81%99)
- [引数と標準入力を区別する](#%E5%BC%95%E6%95%B0%E3%81%A8%E6%A8%99%E6%BA%96%E5%85%A5%E5%8A%9B%E3%82%92%E5%8C%BA%E5%88%A5%E3%81%99%E3%82%8B)
  - [xargs は外部コマンドのみを対象とする！](#xargs-%E3%81%AF%E5%A4%96%E9%83%A8%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89%E3%81%AE%E3%81%BF%E3%82%92%E5%AF%BE%E8%B1%A1%E3%81%A8%E3%81%99%E3%82%8B)
- [シェルスクリプト実行中に適時シェルスクリプトを読み込む](#%E3%82%B7%E3%82%A7%E3%83%AB%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E5%AE%9F%E8%A1%8C%E4%B8%AD%E3%81%AB%E9%81%A9%E6%99%82%E3%82%B7%E3%82%A7%E3%83%AB%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%92%E8%AA%AD%E3%81%BF%E8%BE%BC%E3%82%80)
- [リダイレクトはファイルを初期化する](#%E3%83%AA%E3%83%80%E3%82%A4%E3%83%AC%E3%82%AF%E3%83%88%E3%81%AF%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E5%88%9D%E6%9C%9F%E5%8C%96%E3%81%99%E3%82%8B)
- [コマンドによっては終了ステータスが 0 じゃない](#%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89%E3%81%AB%E3%82%88%E3%81%A3%E3%81%A6%E3%81%AF%E7%B5%82%E4%BA%86%E3%82%B9%E3%83%86%E3%83%BC%E3%82%BF%E3%82%B9%E3%81%8C-0-%E3%81%98%E3%82%83%E3%81%AA%E3%81%84)
  - [diff](#diff)
  - [grep](#grep)
- [終わりに](#%E7%B5%82%E3%82%8F%E3%82%8A%E3%81%AB)

## 環境

```
- Machine: Raspberry Pi 4 Model B Rev 1.4
- OS: Linux ubuntu 5.4.0-1045-raspi
- Bash version: GNU bash 5.0.17(1) aarch64
```

## 結論

```
* ShellCheck を導入しよう
    * VSCode の拡張もあるよ
* まとめられない
* `set -euo pipefail` とつけてほぼ困らない
```

## スタイル編

この辺は ShellCheck で圧倒的にカバー可能。

### 変数

変数定義では前後に余計な**スペースは絶対入れてはなりません**。

```sh
a="hoge"
b=pien
# c: command not found というエラーになる。
c = huga

echo "$a" "$b" "$c"
```

### [ はコマンドです！

`[` は例えば次のように使います。

```sh
$ cat test.sh
#!/bin/bash

a=2022
if [ $a -gt 2000 ]; then
    echo "2000年代です。"
fi

# これはアウト
# if [$a -gt 2000]; then
```

この時、`[` の前後に**変なスペースを入れてはいけません**。  
これは `[` がコマンドの一部であるためであるためです。

コマンドの後は引数やオプションが来ると思うのですが、その時にはスペースを開けると思います、その感覚です。  
コマンドであること・使い方は、実際に `man` で確認できます。

```
$ man [
NAME
       test - check file types and compare values

SYNOPSIS
       test EXPRESSION
       test
       [ EXPRESSION ]
       [ ]
       [ OPTION
...
```

## エラーが起きてもスクリプトは終わらない

```sh
$ cat test.sh
#!/bin/bash

a="hoge"
# Error!!
c = huga

echo "$a" "$b" "$c"
```

上記スクリプトは `c = huga` の部分でエラーになるので、そこで通常はプログラムの実行が止まるのですが（少なくともぼくにとっては）、実は**エラーが起きても止まりません！**。  
最後まで強制的に実行を続けます（実はこれは bash の起動時のオプションに依存）

```sh
# 上記ファイル実行時の出力
$ bash test.sh
test.sh: line 5: c: command not found
hoge
```

### エラー時にスクリプトを止めるオプション

`errexit` のオプションを `on` にすることで、エラー時に終了させることが可能です。

```sh
# デフォルトでは off
$ set -o | grep errexit
errexit         off
```

修正したスクリプト

```sh
$ cat test.sh
#!/bin/bash
set -e

a="hoge"
# Error!!
c = huga

echo "$a" "$b" "$c"
```

実行

```sh
# c の定義以降の echo が呼ばれてないことが分かる。
$ bash test.sh
test.sh: line 6: c: command not found
```

## 未定義変数の取り扱いに注意する

通常では、**未定義変数を参照した時もスクリプトは止まりません！**

このことは、時に恐ろしい事態を招いてしまいます。

```sh
#!/bin/bash

data_dir="/home/ubuntu/Documents/work/pien/data"
# path_to_file が定義されてない時（実装ミスがあった時）
# フォルダ全部が削除されてしまう。
rm -r "${data_dir}/${path_to_file}"
```

### 未定義変数使用時にスクリプトを終了するオプション

エラー時同様、bash 起動時のオプションをつけてあげることで回避可能です。

```sh
# デフォルトでは off
$ set -o | grep nounset
nounset         off
```

修正したスクリプト

```sh
$ cat test.sh
#!/bin/bash
set -u

data_dir="/home/ubuntu/Documents/work/pien/data"
rm -r "${data_dir}/${path_to_file}"
echo "ここまで来るかな？"
```

実行

```sh
# 未定義変数参照時にスクリプト終了となる。
# 『ここまで来るかな』は来ない！
$ bash test.sh
test.sh: line 5: result: unbound variable
```

## パイプは最後の終了ステータスしか見ない

bash においては `true`, `false` もコマンド（see: `man true(false)`）なので、それを使って確かめてみます。

```sh
$ cat test.sh
#!/bin/bash

exit 128 | exit 64 | exit 0
echo $?

# パイプのうち、最後のコマンドの終了ステータスが反映される。
$ bash test.sh
0
```

これは困ります。  
パイプ全体の終了ステータスは、`PIPESTATUS` で取得可能です。

```sh
$ cat test.sh
#!/bin/bash

exit 128 | exit 64 | exit 0
echo "${PIPESTATUS[@]}"

$ bash test.sh
128 64 0
```

### パイプ失敗時にエラーを吐かせる

こちらも、`pipefail` のオプションで指定可能です。

```sh
$ cat test.sh
#!/bin/bash
set -o pipefail

# 3 が全体の終了コード、右から組み立てられる感じ？
exit 128 | exit 64 | exit 3 | exit 0 | exit 0
echo $?
echo hoge

$ bash test.sh
3
hoge
```

パイプがこけた時点でスクリプトを終了するには、`-e` と組み合わせて `set -eo pipefail` と指定しておけば問題ないです。

### パイプはそれでも実行されます

`set -o pipefail` を指定することで、パイプの**一部でも**こけたらエラーを吐かせるようにすることができました。

ただ、パイプは『**繋げて前の出力を待つ**』という性質上、**組み立てた時点で実行されます！**  
（パイプ元がパイプ先に接続する時、パイプ先が待機可能になっている必要があるイメージ）

```sh
$ cat test.sh
#!/bin/bash
set -eo pipefail

true | false | echo hoge

$ bash test.sh
hoge
```

## 引数と標準入力を区別する

bash に慣れてきてパイプを繋げまくっていた頃、`xargs` が何のためにあるのか一瞬迷子になりました。  
それはぼくが**引数と標準入力**を意識してなかったことに起因してます。

パイプは標準出力と標準入力を繋げて遊ぶゲームです。  
そのため基本的にパイプの駒の候補となるのは、標準出力を受け付けるコマンドです。  
（引数と標準入力をどちらも取るコマンドも多く存在します。）

そこで引数を受け付けたい場合に、`xargs` を使う、という戦法になります。

```sh
$ man xargs
NAME
       xargs - build and execute command lines from standard input
...
```

一番簡単な例を示します。

```sh
# echo は引数しか受け付けないため、このワンライナーは何も出力されない。
$ echo hoge | echo

# xargs を用いてコマンドを使う。
$ echo hoge | xargs echo
hoge
```

### xargs は外部コマンドのみを対象とする！

ビルドインコマンドと外部コマンドについても意識する必要があります。  
挙動が異なるものも多く、ここでは馴染み深い `echo` を題材に取り上げます。

とりあえず `echo` について確認します。

```sh
# echo の挙動
$ type echo
echo is a shell builtin
$ type -a echo
echo is a shell builtin
echo is /usr/bin/echo
echo is /bin/echo

## ビルドインコマンド（通常）
$ echo -e '\uFF10'
０
## 外部コマンド
$ /usr/bin/echo -e '\uFF10'
\uFF10
```

`xargs` では『外部コマンド』が呼ばれていることを確認します。

```sh
$ echo -e 'FF10' | xargs -I@ echo -e '\u@'
\uFF10
$ echo -e 'FF10' | xargs -I@ which echo
/usr/bin/echo
```

ではビルドインコマンドを使いたい場合はどうしたらいいのか。  
→ シェルを明示的に呼んであげるとよさそうです。

```sh
$ echo 'FF10' | xargs -I@ bash -c 'echo -e "\u@"'
０
```

## シェルスクリプト実行中に適時シェルスクリプトを読み込む

京大のスパコンのデータが[吹っ飛んだ原因です](https://www.iimc.kyoto-u.ac.jp/services/comp/pdf/file_loss_insident_20211228.pdf)。

シェルスクリプトは呼び出されるまで呼び出されません！  
（うい）

以下の２ファイルを使って簡単に確認してみます。

**test.sh**

```sh
#!/bin/bash

echo "script start"

sleep 15

echo "test"  # ①
# サブファイル(echo_script.sh)を実行する
bash ./echo_script.sh
```

**echo_script.sh**

```sh
#!/bin/bash

echo "Echo from another script file"  # ②
```

`sleep 15` の間に ①, ② をそれぞれ変えてどうなるかを確認してみます。

- ①: 元の文言が出力される
- ②: **新しい文言**が出力される!

どうやらサブファイルの読み込みなどにおいては、実行時に初めて読み込まれるようです。

これは python 等他のスクリプト言語とは異なるため、**時間のかかるスクリプトで複数ファイルに分割している**際は注意が必要でしょう。

## リダイレクトはファイルを初期化する

```sh
$ cat hoge
some text

# こういうのは良くない。
# > の時点で対象のファイルが初期化されてしまう。
$ cat hoge > hoge
# hoge は空っぽになってしまっている。
$ cat hoge
```

## コマンドによっては終了ステータスが 0 じゃない

終了ステータスが 0 より大きいものは異常（エラー？）と習うかと思います。

しかし、コマンドによっては（ぼくにとって）予想外のタイミングで 1 を返すことがあります。  
`errexit` が有効になっている bash 環境などでは、こちらが変に効いてきてしまうので注意が必要です。

find 系が多いのかなーと思うのですが、した 2 つは実際に困ったことのあるコマンドです。

### diff

diff は差分がなかった時が 0、差分があった時が 1、ファイルがなかった時などのエラーが 2 で終了します。

```sh
$ diff <(echo hoge) <(echo pien)
...
$ echo $?
1
```

### grep

grep も diff と同様です。  
（差分がなかった時が 0、差分があった時が 1、ファイルがなかった時などのエラーが 2）

```sh
# no grep result
$ grep bine test.sh
$ echo $?
1

# no such file
$ grep bine test.she
grep: test.she: No such file or directory
$ echo $?
2
```

## 終わりに

随時更新していきます。
