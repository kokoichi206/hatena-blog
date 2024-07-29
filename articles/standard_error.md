# bash で標準エラー出力のリダイレクト・パイプラインを扱う

今更感ですが、標準エラー出力をリダイレクトやパイプに渡す方法をメモしておきます。

**[目次]**

```
* [標準エラー出力とは](#標準エラー出力とは)
* [標準エラー出力を特定のファイルにリダイレクトさせる](#標準エラー出力を特定のファイルにリダイレクトさせる)
* [標準エラー出力を切り捨てる](#標準エラー出力を切り捨てる)
* [標準エラー出力をパイプに渡す](#標準エラー出力をパイプに渡す)
```

## 標準エラー出力とは

標準エラー出力とは、ファイルディスクリプタ (fd) 2 に流し込まれたメッセージのことです。

**標準エラー出力に吐き出す方法**

shell

``` sh
# 1>&2, >&2 などで無理やり 2 番に繋げてやる。
$ bash -c 'echo "something unexpected happened" 1>&2'

# コマンドによっては、特定のメッセージを fd2 に吐き出すものもある。
$ rm not-found-directory | grep hoge
rm: cannot remove 'not-found-directory': No such file or directory
```

Go 言語

``` go
fmt.Fprintln(os.Stderr, "error message")
```

このような方法で（**fd1 以外**に）出力されたメッセージは、**パイプやリダイレクトの対象とならず**、期待値と違う挙動をする場合があります。

``` sh
# 通常の echo の内容はパイプに渡っている。
$ bash -c 'echo "something unexpected happened"' | grep -o some
some

# fd2 への出力はリダイレクトされない。
$ bash -c 'echo "something unexpected happened" 1>&2' > err_msg     
something unexpected happened
$ cat er

# fd2 への出力はパイプに乗っていかない。
$ bash -c 'echo "something unexpected happened" 1>&2' | grep -o some
something unexpected happened
```

どのように扱っていけばいいか、メモしておこうと思います。

## 標準エラー出力を特定のファイルにリダイレクトさせる

まずは、標準エラー出力はリダイレクトの対象にならないことを再度確認します。

``` sh
# 標準エラー出力にメッセージが吐かれる。
$ rm not-found-directory > rm_result
rm: cannot remove 'not-found-directory': No such file or directory
# 空のまま。
$ cat rm_result
```

次に、標準エラー出力をリダイレクトさせる方法を紹介します。
特に**順番には注意が必要**そうです。

``` sh
# 標準エラー出力**のみ**をリダイレクトする。
$ rm not-found-directory 2> rm_result 
$ cat rm_result 
rm: cannot remove 'not-found-directory': No such file or directory

# 標準出力も標準エラー出力もリダイレクトさせる。
## 順番に注意。
$ rm not-found-directory > rm_result 2>&1
$ cat rm_result 
rm: cannot remove 'not-found-directory': No such file or directory

# この順番だとうまくいかない。
## see: https://www.gnu.org/software/bash/manual/html_node/Redirections.html
$ rm not-found-directory 2>&1 > rm_result       
rm: cannot remove 'not-found-directory': No such file or directory
$ cat rm_result

# 以下のような書き方でも、『標準出力』と『標準エラー出力』を合わせてリダイレクトできる。
## see: 3.6.4 Redirecting Standard Output and Standard Error
$ rm not-found-directory &> rm_result
$ cat rm_result 
rm: cannot remove 'not-found-directory': No such file or directory
```

困ったら [man bash 3.6 Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html) を読んでみることをお勧めします。

## 標準エラー出力を切り捨てる

先ほどの具体例ですが、標準エラー出力を出力させない（切り捨てる）ためには以下のように `/dev/null` にリダイレクトさせてあげます。

``` sh
$ rm not-found-directory 2>/dev/null
```

## 標準エラー出力をパイプに渡す

あまりない例かもしれませんが、標準エラー出力もパイプに渡すことができます。

``` sh
# そのままでは標準エラー出力は渡されない。
$ rm not-found-directory | grep -o such
rm: cannot remove 'not-found-directory': No such file or directory

# 標準エラー出力を標準出力に統合する。
$ rm not-found-directory 2>&1 | grep -o such
such

# こんな書き方もできる。
## see: 3.2.3 Pipelines
$ rm not-found-directory |& grep -o such
such
```

bash のドキュメントとしては [3.2.3 Pipelines](https://www.gnu.org/software/bash/manual/html_node/Pipelines.html) が該当します。
