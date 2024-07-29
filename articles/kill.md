# Terminal からプロセスを終了させる
今回は`kill`コマンドを用いてシグナルを飛ばし、プロセスを終了させたりしてみようと思います。

## kill コマンド
とりあえず分からないコマンドが出てきたらマニュアルを読んでみましょう

```sh
$ man kill
NAME
  kill -- terminate or signal a process

SYNOPSIS
  kill [-s signal_name] pid ...
  kill -l [exit_status]
  kill -signal_name pid ...
  kill -signal_number pid ...
```

プロセスにシグナルを送れるそうです。

`kill`という名前がややこしいですが、「プロセスに対しさまざまなタイプの**シグナルを送る**ことができるコマンド」と覚えていただきたいです。

### signal とは
```sh
$ man signal
...
DESCRIPTION
  Signals allow the manipulation of a process from 
outside its domain, as well as allowing the process 
to manipulate itself or copies of itself (children).
  There are two general types of signals: those that cause termination of a process and those that do not.
 ...
```

プロセスを操作するための何かっぽく、プロセスにもいろいろな種類があるっぽいです。

### kill のシグナル一覧
kill コマンドが扱えるシグナルの一覧は、以下のように `-l` オプションで取得することができます。

```sh
# list supported signal names
$ kill -l
1) SIGHUP  2) SIGINT  3) SIGQUIT 4) SIGILL  5) SIGTRAP
...
```

ubuntu では64種類出てきました。

## 使い方

### 基本パターン
`$ kill -<SIGNAL> <process_id>`

プロセス ID に関しては、以下のように`ps`コマンドなどを使って取得できる

```sh
# ps の基本表示
PID TTY   TIME CMD

# (別ターミナルで動く) vue のサーバーに関して調べたい
$ ps aux | grep npm
ubuntu   3649708  6.5  0.5 623960 47976 pts/7    Sl+  09:42   0:01 npm run serve
ubuntu   3649796  0.0  0.0   8724   644 pts/8    S+   09:43   0:00 grep --color=auto npm
```

これより、サーバ起動部分は PID= 3649708 とわかる

よって、このサーバに対して`HUNGUP`コマンドを送りたければ、

```sh
# kill -<SIGNAL> <pid>
$ kill -HUP 3649708
```

また、<SIGNAL>の部分を省略して

`$ kill <process_id>`

と書くこともでき、その場合はデフォルトのシグナルである SIGTERM が送られる。

```sh
$ kill 45624

# manual で確認
$ man kill | grep default
 The default signal for kill is TERM.
```

### １回止めて一定時間後に再開する
```sh
# XXX はプロセスIDが入る

# Suspend process
$ kill -STOP XXX
# Resume process in 10 hours (continue)
$ sleep 36000 && kill -CONT XXX &
```

## 覚えた方が良いシグナル
大量にシグナルはありますが、よく使うのは以下のコマンドだと思います。英語と一緒に覚えてしまいましょう。

SIG は SIGNAL です

- 1) SIGHUP
  - HUNGUP (停止する)
- 2) SIGINT 
  - INTERRUPT (割り込み)
- 9) SIGKILL
  - KILL ()
- 19) SIGSTOP 

### KILL コマンドは最終手段
KILL シグナルは強制的に何がなんでも終了させるイメージであり、一般的には HUP や TERM で一回様子を見た方が良いと思われます。

HUP や TERM でうまくいかない時のみ、KILL シグナルを送るようにしましょう。

```sh
$ kill -HUP XXX
# もし HUP でなかなか終了させられない時
$ kill -TERM XXX
$ kill -KILL XXX
```

### 実は普段から使ってる
実はいくつかのシグナルは標準でコマンドとして stty に割り当てられており、たとえば次のようなものがある

| Command | Signal |
| --- | --- |
| Ctrl-C | 2) SIGINT (interrupt) |
| Ctrl-Z | 20) SIGSTP (temporary stop) |
| Ctrl-\ | 3) SIGQUIT (kill with core dump) |

## おわりに
「ps でプロセスを確認して kill コマンドで終了させる流れ」は、「windows のタスクマネージャーを開いてアプリを強制終了する作業」の CUI バージョンみたいな理解でいいと思います。

是非一回使ってみて、使いこなせるようになっていただけたら嬉しいです。
