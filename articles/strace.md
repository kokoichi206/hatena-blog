# strace コマンドでシステムコールをトレースする
`strace`コマンドが使えるようになると、システムコールをトレースすることが可能になり、低レイヤーにおけるプログラムのデバッグに大変役に立ちます。

## 用語説明
本題に入る前に、今回の話題に関連する用語をざっくりと説明していきます。

### システムコール
コンピュータ上で実行中のプログラムが、OS のカーネルに関わる機能を呼び出す仕組みのこと。

### トレース
バグなどをデバッグする際にする際に、「命令を呼ばれた順番にたどって各ステップごとの状態を確認する作業」をトレースと言います。

linux などにおけるトレースのコマンドの代表例としては、`strace, traceroute, ltrace`などが存在します。

## strace

### インストール
もし`strace`と打って何も返ってこない場合は、自分でインストールしてあげる必要があります。以下は Debian GNU/Linux の場合です。

```sh
$ sudo apt install strace
```

### strace とは
新しいコマンドに出会ったら、何はともあれマニュアルを見てみましょう

```sh
$ man strace
NAME
  strace - trace system calls and signals
DESCRIPTION
  ...
  strace  is a useful diagnostic, instructional, and debugging tool.
```

### strace の使い方

strace に続いて、トーレースしたいコマンドを続ける

```sh
$ strace ls
execve("/usr/bin/ls", ["ls"], 0xffffc3a9dc60 /* 45 vars */) = 0
brk(NULL)                               = 0xaaab0a02a000
faccessat(AT_FDCWD, "/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory)
openat(AT_FDCW
...
```

何やら大量に表示されると思うのですが、デフォルトでは標準エラーに出力されています。

先程の単純な`ls`を実行するだけでも、200行近くのシステムコールが呼び出されていることが分かります。

```sh
$ strace ls 2>&1 | wc
    199    1146   12819
```

ファイルに出力させるには -o オプションを用います。

```sh
$ strace -o log ls
```

### use-case

「設定ファイルを作ったのに反映されてない時」など、果たして読み込まれているのかを確認したい際にも strace は便利です。

```sh
# log ファイルの中から open（ファイルを開く）
# の call が呼ばれるものを抽出する
$ grep open log | grep /home/<config_file>
```

### strace のシステムコール
strace でシステムコールを検査できることは分かりましたが、では strace はどのような仕組みになってるのでしょうか。

実は`strace`は基本的に`ptrace`というシステムコールを呼んでおり、そのことは、`strace`を`strace`することで確認できます

```sh
$ strace strace cat log 2>&1 | grep PTRACE | head
ptrace(PTRACE_SEIZE, 500710, NULL, 0)   = 0
ptrace(PTRACE_SETOPTIONS, 500...`
ptrace(PTRACE_GET_SYSCALL_INFO, 500711, 88, {o...
ptrace(PTRACE_SYSCALL, 500711, NULL, 0) = 0
...
```

## おわりに
最近低レイヤーに興味が出てきた初心者ですが、`strace`コマンドの使い方について紹介してみました。

これからも色々とLinuxの実験をしていきたいと思っています。
