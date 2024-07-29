# bash リダイレクトはファイルを初期化します

これはかつての自分が本当に体験したことなのですが、『ファイルの情報源』と『リダイレクトの出力先』を同一にしてしまったために起きた怖い怖い現象の話をしたいと思います。

**[目次]**

[:contents]

## 環境

```sh
$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux

$ cat /etc/os-release
NAME="Ubuntu"
VERSION="20.04.2 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.2 LTS"
...

$ bash -version
GNU bash, version 5.0.17(1)-release (aarch64-unknown-linux-gnu)
Copyright (C) 2019 Free Software Foundation, Inc.
```

## 時間ない人向けまとめ

```
- リダイレクトをすると、真っ先に対象ファイルが初期化される
  - `cat hoge > hoge` みたいなコマンドに注意
- その挙動を、少し systam call で確認してみた
- 基本マニュアルに書いてある
```

## 自己リダイレクト

『自己リダイレクト』という表現が正しいかは知りませんが、ここでは以下のような内容を想定しています。

例えば以下のような `results` ファイルがあるとします。

```sh
$ cat results
a,90
b,100
c,40
```

UNIX のよくある考えに従って、パイプで繋げて次のようにいくつかの演算を施します。
（ここでは消費税込みの値段を計算しています。）

```sh
$ cat results | awk -F',' 'BEGIN { OFS="," } {print $1,int(10*sqrt($2))}'
a,94
b,100
c,63

$ cat results | awk -F',' 'BEGIN { OFS="," } {print $1,$2*1.10}'
a,99
b,110
c,44
```

最後に、今までの結果を書き換えたいと思い、標準出力上の計算結果をファイル（`resulets`）に書き込むようリダイレクト（[Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)）を行います。

（このように `cat` などで情報を得ているファイルに対し、リダイレクトの先も同一ファイルを向いているコマンドを自己リダイレクト状態、と定義します。させてください。）

```sh
$ cat results | awk -F',' 'BEGIN { OFS="," } {print $1,$2*1.10}' > results
```

リダイレクトを行うまでの標準出力は正しく見えるので、期待値通り元のファイルが消費税込みの値段に更新されるかと思われます。

...
が、結果は以下のように何も表示されません！

```sh
# 何も表示されない！
$ cat results
```

これは bash の Redirections の挙動になるのですが、知らないと引っかかる人もいると思いますので、考えてみたいと思います。
（ちなみに `$ cat results > results` でも元ファイル `results` は空になります。）

## system call をみてみる

どういう順番で処理されているかを確認するために、とりあえず `system call` みてみましょう。

ここでは `strace` コマンドを使います。

### リダイレクトについて

```sh
$ strace sh -c "> results" 2>&1 | grep results
execve("/usr/bin/sh", ["sh", "-c", "> results"], 0xfffff57e5c60 /* 52 vars */) = 0
openat(AT_FDCWD, "results", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3
```

2 行目の処理はリダイレクトによって発生した処理で、`results` というファイルを open し、ファイルディスクリプタの 3 番を充てています。

### `cat` について

`cat` の対象ファイルは、どうやら直接ファイル名から取ってきてるのではなく、キャッシュから参照されるようで、system call の中に直接ファイル名（今回だと `results`）が現れることはありませんでした。

```sh
# 特にヒットなし
$ strace sh -c "cat results" 2>&1 | grep -e results
execve("/usr/bin/sh", ["sh", "-c", "cat results"], 0xfffff62f9ed0 /* 52 vars */) = 0
```

どうやら `/etc/ld.so.cache`（キャッシュファイル）を参照してるっぽい？？

```sh
$ strace -e trace=openat,read,write sh -c "cat results"
openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/aarch64/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/aarch64/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/aarch64/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/opt/ros/noetic/lib/aarch64/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/opt/ros/noetic/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\350A\2\0\0\0\0\0"..., 832) = 832
--- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=1078767, si_uid=1000, si_status=0, si_utime=0, si_stime=0} ---
+++ exited with 0 +++
```

### リダイレクトと `cat`

続いて、`cat` とリダイレクトの前後関係を確認してみます。

```sh
$ strace sh -c "cat results > results" 2>&1 | grep -e results -e cat
execve("/usr/bin/sh", ["sh", "-c", "cat results > results"], 0xffffcf4619b0 /* 52 vars */) = 0
...
openat(AT_FDCWD, "results", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3 # これが Redirections
newfstatat(AT_FDCWD, "~/.rbenv/bin/cat", 0xffffd9ba5f88, 0) = -1 ENOENT (No such file or directory)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ = -1 が続く ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
newfstatat(AT_FDCWD, "/usr/sbin/cat", 0xffffd9ba5f88, 0) = -1 ENOENT (No such file or directory)
newfstatat(AT_FDCWD, "/usr/bin/cat", {st_mode=S_IFREG|0755, st_size=35080, ...}, 0) = 0 # この辺から cat がありそう
```

なんとなくでしか読めてませんが、Redirections の呼び出しの方が、`cat`（群）の呼び出しより先にあることがわかります。

つまり、**パイプ等をつなげていく流れ順的には `Redirections` の方が後だったのに、呼び出し順はこちらが先になっています！**

大体見えてきましたが、もう少しシステムコールを深掘ります。

### リダイレクトのファイルの開き方について

先ほどまでで、**リダイレクトは `cat` よりも先に呼び出される**ということが分かりました。
その上で、もう一度リダイレクトのシステムコールを見てみます。

```sh
$ strace sh -c "> results" 2>&1 | grep results
execve("/usr/bin/sh", ["sh", "-c", "> results"], 0xfffff57e5c60 /* 52 vars */) = 0
openat(AT_FDCWD, "results", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3
```

ここで、`openat` のオプションついてもう少し深掘ります。
（自分も詳しくないので `openat` とは何か、という説明は省きますが、興味がある方は `man openat` をご覧ください。。。）

今回着目したいのは `O_TRUNC` であるため、その他 2 つのフラグの説明は省きます。
（それぞれ、書き込み専用モードで開く、ファイルがなければ新規作成する、ということを意味しています。）

それではマニュアルを見てみます。

```sh
$ man openat | grep O_TRUNC -C5
...
O_TRUNC
    If  the  file  already  exists and is a regular file and the access mode allows writin
     (i.e., is O_RDWR or O_WRONLY) it will be truncated to length 0.
```

> すでに対象ファイルが存在し、通常のファイル（ここでいう通常のファイルとは？）で、
> 書き込みが許可されているならば、長さが 0 に切り捨てられる。

ありました！

### system call から見える結果

まとめると、system call を見てみた結果以下の 2 つのことがわかり、その結果『自己リダイレクト』で起こった事象が説明できそうです。

- Redirections の方が `cat` よりも先に呼ばれる。
- Redirections 時のファイルを開くフラグにより、既存ファイルは長さが 0 に切り捨てられる。

## おまけ

今の自分なら、ファイルの中身を inline で書き換えたい時は `sed` の `-i` オプションとか使うかなと思います。

### [bash のマニュアル](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)

`3.6.2 Redirecting Output` にちゃんと記載いただいてます。

> ...If the file does not exist it is created; if it does exist it is truncated to zero size.

- ファイルが存在しない時は、新規に作成される。
- ファイルが存在する時は、サイズが 0 に切り捨てられる。

いつも自分が詰まるところはマニュアルにある。

## リンク

- [bash manual: Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- [bash manual: open](https://man7.org/linux/man-pages/man2/open.2.html)

## まとめ

システムコールにあまり馴染みがない人生でした。
来世ではちゃんと読めるようになりたい。
