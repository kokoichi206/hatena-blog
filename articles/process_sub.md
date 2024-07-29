# bash でコマンドの実行結果をファイルとして扱う


プロセス置換（[Process Substitution](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Process-Substitution)）を用います。使い方と一緒に、ぜひ名前も覚えましょう。


## 使い方

``` sh
# 通常のファイル入力の場合
$ cat test.txt

# コマンドの実行結果をファイルとして扱う場合
$ cat <(echo "hoge from echo command")
hoge from echo command
```

`ファイル名`を`<(コマンド)`で置き換えるだけです！

`<`と`(`の間にスペースはいりません。

少し具体的なコマンドで見てみます

### diff コマンド
``` sh
diff <(echo 3.0+3 | bc) <(echo $((3.0+3)) )
1c1
< 6.0
---
> 6.
```

片方をファイルにして、もう一方をプロセス置換にすることもできます

``` sh
$ cat file.txt
file

$ diff file.txt <(echo "content")
1c1
< file
---
> content
```

### ファイル読み込み：while read ...
ファイルの中身を読み込みながら１行ずつ処理を行う場合、次のように書くことができます

``` sh
while read line
do
    echo "$line"
done < file.txt
```

この `while` ループに入力させている `file.txt` の部分に、プロセス置換を使うことが可能です。

``` sh
### expected outputs
# hoge
# pien
while read line
do
    echo "$line"
done < <(echo -e "hoge\npien")
```


## おわりに
ファイル入力しか受け付けないコマンドに対し、『ちょっとしたテストコードを試したいが、わざわざファイルを用意するのもめんどくさい』といったケースに使えると感じました。

他にも有用なユースケースがあれば教えていただきたいです。
