# bash のみで progress bar をつくる

特に bash のみで作る理由はないですが、こんなことも出来るんだという紹介です。

**[目次]**

* [echo のオプション](#echo-のオプション)
  * [r](#r)
  * [c](#c)
* [progress bar 実装](#progress-bar-実装)

## echo のオプション

まず、プログレスバーを作るのに必要な技術（特殊文字）を説明します。

echo コマンドで特殊文字を有効にするには `-e` option を付ける必要があります。

``` sh
$ man echo | grep '\-e' -A5
       -e     enable interpretation of backslash escapes

       -E     disable interpretation of backslash escapes (default)

       --help display this help and exit

--
       If -e is in effect, the following sequences are recognized:

       \\     backslash

       \a     alert (BEL)

# デフォルトでは \n とかでは改行されない。
$ echo 'h\no'
h\no

# -e オプションを付けた場合 \ での特殊文字が有効になる。
$ echo -e 'h\no'
h
o
```

### r

``` sh
$ man echo | grep '\\r'
       \r     carriage return
```

`\r` は**キャリッジ（カーソル）をリターンする（先頭に戻す）**特殊文字です。

windows や HTML の規格では Line Feed の `\n` と併せて `\r\n` で改行を表したりします。

``` sh
$ echo -e 'hoge\rpien'
pien

# hoge の入力で4つ目まで進んだキャリッジが \r で先頭まで戻る。
# その後の pi の入力により 1 文字目から上書きされている。
$ echo -e 'hoge\rpi'
pige
```

### c

``` sh
$ man echo | grep '\\c'
       \c     produce no further output
```

`\c` は**以降の出力を無効にする**特殊文字です。

``` sh
# \c 以降の pienfuga... は出力されない。
$ echo -e 'hoge\cpienfuga\npaon'
hoge

# 改行文字も出力されない。
$ echo -e '1\c' | od -t x1
0000000 31
0000001
$ echo -e '1' | od -t x1
0000000 31 0a
0000002
```

## progress bar 実装

![](./img/progress.gif)

``` sh
#!/bin/bash

# print_bar prints a progress bar.
# This function takes a decimal number between 0 and 1 as its 1st argument,
# representing the percentage of completion.
print_bar() {
    # total length of the progress bar to 60 characters.
    LENGTH=60

    bar='['

    percent="$(echo $1 | awk '{print int($1 * 100)}')"
    columns="$(echo $1 | awk -v len="$LENGTH" '{print int($1 * len)}')"
    # Build the filled part of the bar.
    for (( i=1; i<=$columns; i++ )); do
        bar=$bar'='
    done
    # Complete the bar with spaces to maintain a fixed length.
    for (( i=1; i<=$(($LENGTH-$columns)); i++ )); do
        bar=$bar' '
    done

    bar=$bar"] $percent%"
    # output the trailing newline ONLY when the job is completed.
    # \c means 'produce no further output'.
    if [[ "$percent" != 100 ]]; then
        bar=$bar"\c"
    fi

    echo -e "\r$bar"
}

# example usage.
for i in 0.1 0.2 0.3 0.5 0.7 0.8 0.9 1.00 ; do
    print_bar $i
    sleep 0.3
done
```
