# bash で `!` は特殊な意味を持つっていう話

bash で `!` は特殊な意味を持つので注意しよう、という話をしたいと思います。

私は語尾に ! をつける癖があるのですが、そのせいで予想と異なる挙動をすることがありました。

**[目次]**

[:contents]

## 時間がないひとまとめ

```
- !, !! は履歴展開を表す
  - 通常は "" の中でも！
- POSIX MODE もいいかもしれない
```

## 環境

```sh
$ bash -version
GNU bash, version 5.0.17(1)-release (aarch64-unknown-linux-gnu)
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
```

## なにが起こったか

```sh
# 文字列の中で !! を使うと変なことになっちゃう！（こういうとこ）
$ ls
...
$ echo "やったぜ!!"
echo "やったぜls"
やったぜls

$ a=hoge
$ if [ $a = "hoge" ]; then echo "matched!!"; fi
if [ $a = "hoge" ]; then echo "matcheda=hoge"; fi
matcheda=hoge
```

## とりあえずはマニュアル

`!` も `!` も [History Expansion（履歴展開）](https://www.gnu.org/software/bash/manual/html_node/History-Interaction.html)の機能になります。

[9.3.1 Event Designators](https://www.gnu.org/software/bash/manual/html_node/Event-Designators.html) を見ると良さそうです。

### `!`

`!` は過去の履歴から参照するコマンドです。

- **!n**
  - Refer to command line n.
- **!-n**
  - Refer to the command n lines back.

```sh
$ history | tail
 1231  history
 1232  echo $a | awk 'tolower($0) ~ /^aarch64$/ {echo "matched"}'
 1233  echo "echo $a | awk 'tolower($0) ~ /^aarch64$/ {echo "matched"}'"
 1234  set -o | grep posix
 1235  ls
 1236  ww
 1237  echo "やったぜww"
 1238  a=hoge
 1239  if [ $a = "hoge" ]; then echo "matcheda=hoge"; fi
 1240  history

# !n
# 1237 番目の履歴が実行される
$ !1237
echo "やったぜww"
やったぜww

# !-n
$ echo hoge
hoge
# マイナスインデックスと考える
$ !-1
echo hoge
hoge

# "" の中でも履歴展開される
# それはえぐいって。。。
$ echo "!-1"
echo "echo hoge"
echo hoge
```

### `!!`

- **!!**
  - Refer to the previous command. This is a synonym for '!-1'.

`!-1` と同義である。つまり直前のコマンドを参照し展開します。

```sh
# !!
$ echo hoge
hoge
$ !!
echo hoge
hoge

# "" の中でも履歴展開される。。。
$ echo "!!"
echo "echo hoge"
echo hoge
```

## POSIX モード

実は [POSIX モード](https://www.gnu.org/software/bash/manual/html_node/Bash-POSIX-Mode.html)を有効にすると、`!` や `!!` の展開を禁止することが可能です。

> 9 . The POSIX PS1 and PS2 expansions of '!' to the history number and '!!' to '!' are enabled, and parameter expansion is performed on the values of PS1 and PS2 regardless of the setting of the promptvars option.
> 23 . The '!' character does not introduce history expansion within a double-quoted string, even if the histexpand option is enabled.

POSIX = Portable Operating System Interface

### POSIX モードを切り替える

```sh
# POSIX モードが有効かどうかを確認する
$ set -o | grep posix
posix           off

# POSIX モードを ON にする
$ set -o posix
$ set -o | grep posix
posix           on

# POSIX モードを OFF にする
$ set +o posix
$ set -o | grep posix
posix           off
```

### POSIX MODE = ON の時

POSIX_MODE が ON の時は、`"` の中では展開されない！

```sh
# POSIX MODE = ON の時
$ set -o | grep posix
posix           on

$ echo hoge
hoge
$ echo !-1
echo echo hoge
echo hoge
$ echo "!-1"
!-1
$ echo "!!"
!!
```

## おわりに

bash の manual は見てて面白い。
