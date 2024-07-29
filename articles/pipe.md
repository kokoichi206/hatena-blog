# シェルのパイプ連結をシステムコールから理解する

シェルの上でよく遊ぶ方であれば、パイプ `|` は非常にお世話になっているかと思います。
今回はそんなパイプについて、どのようなシステムコールが呼ばれているかを追うことで理解を深めてみました。

**[目次]**

```
- まとめ
- 環境
- pipe status の復習
- システムコールを探る
  - 大枠の確認
  - プロセスを追う
  - 1 つ目の子プロセス 475570 に着目
  - 2 つ目の子プロセス 475571 に着目
- 今後知りたいこと
- Links
```

## まとめ

時間のない方のためにまとめです。

```
- pipe status の復習
  - 終了ステータスは、パイプの**最後の**終了ステータスを返す
  - PIPESTATUS に各コマンドごとの終了ステータスが**全て**保存されている
- `|` で繋がっていく流れを、システムコールから確認
  - pipe2 で繋げたい fd を事前に用意
  - コマンドの数だけ親プロセスから clone し、プロセスを作成
  - dup3 を使い、標準入出力と pipe2 で繋げた fd を複製
```

## 環境

本記事の結果は全て、以下の ubuntu 環境のラズパイでの出力になります。

``` sh
$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

## pipe status の復習

pipe の終了ステータス (exit status) をおさらいしておきます。

まず終了ステータスは、パイプの**最後の**終了ステータスを返します。

``` sh
$ echo hoge| grep o
hoge
$ echo $?
0

# p が見つからないので grep p は 0 を返す。
$ echo hoge| grep o | grep p
$ echo $?
1

$ echo hoge| grep o | grep p | echo xxx | grep x
xxx

$ echo $?
1
```

また、パイプ実行後には PIPESTATUS という変数に値が格納されており、より詳細に実行結果を確認できます。

**各コマンドごとの終了ステータスが、全て保存されている**ことがわかります。

``` sh
$ echo hoge| grep o
hoge
$ echo ${PIPESTATUS[@]}
0 0

$ echo hoge| grep o | grep p
$ echo ${PIPESTATUS[@]}
0 0 1

$ echo hoge| grep o | grep p | echo xxx | grep x
xxx
$ echo ${PIPESTATUS[@]}
0 0 1 0 0
```

補足ですが、パイプ全体としての終了ステータスを、最後の値ではなくエラーを優先させるには pipefail をつけてあげます。

``` sh
$ echo hoeg | grep p | echo pi
pi
$ echo ${PIPESTATUS[@]}
0 1 0

$ echo hoeg | grep p | echo pi
pi
# 全体の終了ステータスには、最後のパイプの後の値が入る。
$ echo $?
0

# ============= pipefail の設定 =============
$ set -o pipefail

$ man bash | grep pipefail -A2
       The return status of a pipeline is the exit status of the last command, unless the pipefail option is enabled.  If pipefail is enabled, the pipeline's return status is the value of the last (rightmost) command to exit with  a  non-
       zero status, or zero if all commands exit successfully.  If the reserved word !  precedes a pipeline, the exit status of that pipeline is the logical negation of the exit status as described above.  The shell waits for all commands
        in the pipeline to terminate before returning a value.
    pipefail
        If set, the return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status, or zero if all commands in the pipeline exit successfully.  This option is disabled  by  de‐
        fault.

$ echo hoeg | grep p | echo pi
pi
# 全体の終了ステータスには、エラーが優先される。
$ echo $?
1

$ echo hoeg | grep p | exit 128 | echo hoge
hoge
$ echo ${PIPESTATUS[@]}
0 1 128 0

$ echo hoeg | grep p | exit 128 | echo hoge
hoge
# 全体の終了ステータスには、ドキュメント通り non0 の最後のコマンドの狩猟ステータスが取得できる。
$ echo $?
128

$ echo hoeg | grep p | exit 128 | echo hoge | grep p | echo exit
exit
$ echo ${PIPESTATUS[@]}
0 1 128 0 1 0
$ echo hoeg | grep p | exit 128 | echo hoge | grep p | echo exit
exit
# 128 より 1 の方がより後の non0 終了ステータスなの優先される。
$ echo $?
1
```

また、終了時即リターンしたければ errexit も設定してあげれば可能です。

``` sh
set -e
```

## システムコールを探る

ようやく本題のシステムコールを探っていきたいと思います。

今回は `echo hoge | grep p` の実行結果を追うことにし、以下のコマンドで対象のシステムコールを取得しました。

``` sh
# -f で子プロセスの結果も取得できる。
strace -f -o bash-pipe-fail bash -c 'echo hoge | grep p'
```

<details>
<summary>bash-pipe の内容 (455 行)</summary>

```
475569 execve("/usr/bin/bash", ["bash", "-c", "echo hoge | grep o"], 0xffffd9191e98 /* 52 vars */) = 0
475569 brk(NULL)                        = 0xaaab097fa000
475569 mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffa7a5d000
475569 faccessat(AT_FDCWD, "/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/aarch64/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/aarch64", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/aarch64/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/aarch64", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/aarch64/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/tls/aarch64", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/tls", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/aarch64/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/aarch64", 0xffffe390b910, 0) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=85175, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 85175, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffffa7a12000
475569 close(3)                         = 0
475569 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libtinfo.so.6", O_RDONLY|O_CLOEXEC) = 3
475569 read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0000\327\0\0\0\0\0\0"..., 832) = 832
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=187688, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 317704, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffa79c4000
475569 mmap(0xffffa79d0000, 252168, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffa79d0000
475569 munmap(0xffffa79c4000, 49152)    = 0
475569 munmap(0xffffa7a0e000, 14600)    = 0
475569 mprotect(0xffffa79f9000, 65536, PROT_NONE) = 0
475569 mmap(0xffffa7a09000, 20480, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x29000) = 0xffffa7a09000
475569 close(3)                         = 0
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libdl.so.2", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/libdl.so.2", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libdl.so.2", O_RDONLY|O_CLOEXEC) = 3
475569 read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\0\0\0\0\0\0\0\0"..., 832) = 832
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=6152, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 135200, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffa79ae000
475569 mmap(0xffffa79b0000, 69664, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffa79b0000
475569 munmap(0xffffa79ae000, 8192)     = 0
475569 munmap(0xffffa79c2000, 53280)    = 0
475569 mprotect(0xffffa79b1000, 61440, PROT_NONE) = 0
475569 mmap(0xffffa79c0000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffa79c0000
475569 close(3)                         = 0
475569 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/opt/ros/noetic/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475569 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
475569 read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\340u\2\0\0\0\0\0"..., 832) = 832
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=1641496, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 1810024, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffa77f6000
475569 mmap(0xffffa7800000, 1744488, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffa7800000
475569 munmap(0xffffa77f6000, 40960)    = 0
475569 munmap(0xffffa79aa000, 24168)    = 0
475569 mprotect(0xffffa7989000, 61440, PROT_NONE) = 0
475569 mmap(0xffffa7998000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x188000) = 0xffffa7998000
475569 mmap(0xffffa799e000, 48744, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0xffffa799e000
475569 close(3)                         = 0
475569 mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffa7a5b000
475569 set_tid_address(0xffffa7a5b0f0)  = 475569
475569 set_robust_list(0xffffa7a5b100, 24) = 0
475569 rseq(0xffffa7a5b7c0, 0x20, 0, 0xd428bc00) = 0
475569 mprotect(0xffffa7998000, 16384, PROT_READ) = 0
475569 mprotect(0xffffa79c0000, 4096, PROT_READ) = 0
475569 mprotect(0xffffa7a09000, 16384, PROT_READ) = 0
475569 mprotect(0xaaaae0bec000, 20480, PROT_READ) = 0
475569 mprotect(0xffffa7a61000, 8192, PROT_READ) = 0
475569 prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
475569 munmap(0xffffa7a12000, 85175)    = 0
475569 openat(AT_FDCWD, "/dev/tty", O_RDWR|O_NONBLOCK) = 3
475569 close(3)                         = 0
475569 getrandom("\x21\x09\xe1\x0e\x60\x1e\xed\x85", 8, GRND_NONBLOCK) = 8
475569 brk(NULL)                        = 0xaaab097fa000
475569 brk(0xaaab0981b000)              = 0xaaab0981b000
475569 openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=4121216, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 4121216, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffffa7411000
475569 close(3)                         = 0
475569 openat(AT_FDCWD, "/usr/lib/aarch64-linux-gnu/gconv/gconv-modules.cache", O_RDONLY) = 3
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=27004, ...}, AT_EMPTY_PATH) = 0
475569 mmap(NULL, 27004, PROT_READ, MAP_SHARED, 3, 0) = 0xffffa7a54000
475569 close(3)                         = 0
475569 futex(0xffffa799d89c, FUTEX_WAKE_PRIVATE, 2147483647) = 0
475569 getuid()                         = 1000
475569 getgid()                         = 1000
475569 geteuid()                        = 1000
475569 getegid()                        = 1000
475569 rt_sigprocmask(SIG_BLOCK, NULL, [], 8) = 0
475569 ioctl(-1, TIOCGPGRP, 0xffffe390c614) = -1 EBADF (Bad file descriptor)
475569 sysinfo({uptime=3076812, loads=[20992, 41408, 42784], totalram=8190713856, freeram=221540352, sharedram=81838080, bufferram=803373056, totalswap=0, freeswap=0, procs=1072, totalhigh=0, freehigh=0, mem_unit=1}) = 0
475569 rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, 8) = 0
475569 rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 rt_sigprocmask(SIG_BLOCK, NULL, [], 8) = 0
475569 rt_sigaction(SIGQUIT, {sa_handler=SIG_IGN, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 uname({sysname="Linux", nodename="ubuntu", ...}) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/Documents/syscall/tty", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, ".", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/Documents", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/Documents/syscall", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/Documents/syscall/tty", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/Documents/syscall", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 getpid()                         = 475569
475569 getppid()                        = 475566
475569 newfstatat(AT_FDCWD, ".", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/go/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/go/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.rbenv/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.rbenv/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/work/go/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/go//go/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.goenv/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/shims/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/go/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/opt/ros/noetic/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/go/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/74f6148eb9ea00507ec113ec51c489d6ffb4b771/bin/remote-cli/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.deno/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.yarn/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/shims/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/c3f126316369cd610563c75b1b1725e0679adfb3/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.local/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/c3f126316369cd610563c75b1b1725e0679adfb3/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.local/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/sbin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/local/bin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/sbin/bash", 0xffffe390c268, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 geteuid()                        = 1000
475569 getegid()                        = 1000
475569 getuid()                         = 1000
475569 getgid()                         = 1000
475569 faccessat(AT_FDCWD, "/usr/bin/bash", X_OK) = 0
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 geteuid()                        = 1000
475569 getegid()                        = 1000
475569 getuid()                         = 1000
475569 getgid()                         = 1000
475569 faccessat(AT_FDCWD, "/usr/bin/bash", R_OK) = 0
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 geteuid()                        = 1000
475569 getegid()                        = 1000
475569 getuid()                         = 1000
475569 getgid()                         = 1000
475569 faccessat(AT_FDCWD, "/usr/bin/bash", X_OK) = 0
475569 newfstatat(AT_FDCWD, "/usr/bin/bash", {st_mode=S_IFREG|0755, st_size=1215072, ...}, 0) = 0
475569 geteuid()                        = 1000
475569 getegid()                        = 1000
475569 getuid()                         = 1000
475569 getgid()                         = 1000
475569 faccessat(AT_FDCWD, "/usr/bin/bash", R_OK) = 0
475569 getpid()                         = 475569
475569 getpgid(0)                       = 475566
475569 ioctl(2, TIOCGPGRP, [475566])    = 0
475569 rt_sigaction(SIGCHLD, {sa_handler=0xaaaae0b1ede0, sa_mask=[], sa_flags=SA_RESTART}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, 8) = 0
475569 prlimit64(0, RLIMIT_NPROC, NULL, {rlim_cur=30840, rlim_max=30840}) = 0
475569 rt_sigprocmask(SIG_BLOCK, NULL, [], 8) = 0
475569 rt_sigprocmask(SIG_BLOCK, NULL, [], 8) = 0
475569 rt_sigprocmask(SIG_BLOCK, [CHLD], [], 8) = 0
475569 pipe2([3, 4], 0)                 = 0
475569 rt_sigprocmask(SIG_BLOCK, [INT CHLD], [CHLD], 8) = 0
475569 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0xffffa7a5b0f0) = 475570
475570 set_robust_list(0xffffa7a5b100, 24 <unfinished ...>
475569 rt_sigprocmask(SIG_SETMASK, [CHLD],  <unfinished ...>
475570 <... set_robust_list resumed>)   = 0
475569 <... rt_sigprocmask resumed>NULL, 8) = 0
475569 close(4 <unfinished ...>
475570 getpid( <unfinished ...>
475569 <... close resumed>)             = 0
475570 <... getpid resumed>)            = 475570
475569 close(4 <unfinished ...>
475570 rt_sigprocmask(SIG_SETMASK, [],  <unfinished ...>
475569 <... close resumed>)             = -1 EBADF (Bad file descriptor)
475570 <... rt_sigprocmask resumed>NULL, 8) = 0
475569 rt_sigprocmask(SIG_BLOCK, [INT CHLD],  <unfinished ...>
475570 rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0},  <unfinished ...>
475569 <... rt_sigprocmask resumed>[CHLD], 8) = 0
475570 <... rt_sigaction resumed>{sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD <unfinished ...>
475570 rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475570 rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475570 close(3 <unfinished ...>
475569 <... clone resumed>, child_tidptr=0xffffa7a5b0f0) = 475571
475570 <... close resumed>)             = 0
475569 rt_sigprocmask(SIG_SETMASK, [CHLD],  <unfinished ...>
475570 dup3(4, 1, 0 <unfinished ...>
475569 <... rt_sigprocmask resumed>NULL, 8) = 0
475570 <... dup3 resumed>)              = 1
475569 close(3 <unfinished ...>
475570 close(4 <unfinished ...>
475569 <... close resumed>)             = 0
475570 <... close resumed>)             = 0
475569 rt_sigprocmask(SIG_BLOCK, [CHLD], [CHLD], 8) = 0
475570 rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0},  <unfinished ...>
475569 rt_sigprocmask(SIG_SETMASK, [CHLD],  <unfinished ...>
475570 <... rt_sigaction resumed>{sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475569 <... rt_sigprocmask resumed>NULL, 8) = 0
475570 rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0},  <unfinished ...>
475569 rt_sigprocmask(SIG_BLOCK, [CHLD],  <unfinished ...>
475570 <... rt_sigaction resumed>{sa_handler=SIG_IGN, sa_mask=[], sa_flags=0}, 8) = 0
475569 <... rt_sigprocmask resumed>[CHLD], 8) = 0
475570 rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART},  <unfinished ...>
475569 rt_sigaction(SIGINT, {sa_handler=0xaaaae0b1b6d8, sa_mask=[], sa_flags=0},  <unfinished ...>
475570 <... rt_sigaction resumed>{sa_handler=0xaaaae0b1ede0, sa_mask=[], sa_flags=SA_RESTART}, 8) = 0
475569 <... rt_sigaction resumed>{sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475570 rt_sigprocmask(SIG_BLOCK, [CHLD],  <unfinished ...>
475569 wait4(-1,  <unfinished ...>
475570 <... rt_sigprocmask resumed>[], 8) = 0
475570 rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0
475570 rt_sigaction(SIGCHLD, {sa_handler=0xaaaae0b1ede0, sa_mask=[], sa_flags=SA_RESTART}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, 8) = 0
475570 rt_sigaction(SIGINT, {sa_handler=0xaaaae0b3b338, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475570 newfstatat(1, "", {st_mode=S_IFIFO|0600, st_size=0, ...}, AT_EMPTY_PATH) = 0
475571 set_robust_list(0xffffa7a5b100, 24 <unfinished ...>
475570 write(1, "hoge\n", 5 <unfinished ...>
475571 <... set_robust_list resumed>)   = 0
475570 <... write resumed>)             = 5
475571 getpid()                         = 475571
475570 exit_group(0 <unfinished ...>
475571 rt_sigprocmask(SIG_SETMASK, [],  <unfinished ...>
475570 <... exit_group resumed>)        = ?
475571 <... rt_sigprocmask resumed>NULL, 8) = 0
475571 rt_sigaction(SIGTSTP, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475571 rt_sigaction(SIGTTIN, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475570 +++ exited with 0 +++
475569 <... wait4 resumed>[{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 475570
475571 rt_sigaction(SIGTTOU, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0},  <unfinished ...>
475569 wait4(-1,  <unfinished ...>
475571 <... rt_sigaction resumed>{sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475571 dup3(3, 0, 0)                    = 0
475571 close(3)                         = 0
475571 newfstatat(AT_FDCWD, ".", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475571 newfstatat(AT_FDCWD, "/home/ubuntu/go/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/go/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.rbenv/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.rbenv/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/work/go/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/go//go/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.goenv/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/shims/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/go/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/opt/ros/noetic/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/go/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/74f6148eb9ea00507ec113ec51c489d6ffb4b771/bin/remote-cli/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.deno/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.yarn/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/shims/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.nodenv/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/c3f126316369cd610563c75b1b1725e0679adfb3/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.local/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.vscode-server/bin/c3f126316369cd610563c75b1b1725e0679adfb3/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/.local/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/sbin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/local/bin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/sbin/grep", 0xffffe390be08, 0) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 geteuid()                        = 1000
475571 getegid()                        = 1000
475571 getuid()                         = 1000
475571 getgid()                         = 1000
475571 faccessat(AT_FDCWD, "/usr/bin/grep", X_OK) = 0
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 geteuid()                        = 1000
475571 getegid()                        = 1000
475571 getuid()                         = 1000
475571 getgid()                         = 1000
475571 faccessat(AT_FDCWD, "/usr/bin/grep", R_OK) = 0
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 geteuid()                        = 1000
475571 getegid()                        = 1000
475571 getuid()                         = 1000
475571 getgid()                         = 1000
475571 faccessat(AT_FDCWD, "/usr/bin/grep", X_OK) = 0
475571 newfstatat(AT_FDCWD, "/usr/bin/grep", {st_mode=S_IFREG|0755, st_size=174304, ...}, 0) = 0
475571 geteuid()                        = 1000
475571 getegid()                        = 1000
475571 getuid()                         = 1000
475571 getgid()                         = 1000
475571 faccessat(AT_FDCWD, "/usr/bin/grep", R_OK) = 0
475571 rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
475571 rt_sigaction(SIGQUIT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=SIG_IGN, sa_mask=[], sa_flags=0}, 8) = 0
475571 rt_sigaction(SIGCHLD, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=SA_RESTART}, {sa_handler=0xaaaae0b1ede0, sa_mask=[], sa_flags=SA_RESTART}, 8) = 0
475571 execve("/usr/bin/grep", ["grep", "o"], 0xaaab09808620 /* 52 vars */) = 0
475571 brk(NULL)                        = 0xaaab19fa2000
475571 mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5edd000
475571 faccessat(AT_FDCWD, "/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/aarch64/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/aarch64", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/tls", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/aarch64/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/aarch64", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib", {st_mode=S_IFDIR|0775, st_size=4096, ...}, 0) = 0
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/aarch64/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/tls/aarch64", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/tls/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/tls", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/aarch64/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib/aarch64", 0xffffc1b6c990, 0) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/libpcre.so.3", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 newfstatat(AT_FDCWD, "/opt/ros/noetic/lib", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475571 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=85175, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 85175, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffffb5e92000
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libpcre.so.3", O_RDONLY|O_CLOEXEC) = 3
475571 read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\200\26\0\0\0\0\0\0"..., 832) = 832
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=399240, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 528544, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5e10000
475571 mmap(0xffffb5e10000, 463008, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5e10000
475571 munmap(0xffffb5e82000, 61600)    = 0
475571 mprotect(0xffffb5e71000, 61440, PROT_NONE) = 0
475571 mmap(0xffffb5e80000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x60000) = 0xffffb5e80000
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libdl.so.2", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/libdl.so.2", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libdl.so.2", O_RDONLY|O_CLOEXEC) = 3
475571 read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\0\0\0\0\0\0\0\0"..., 832) = 832
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=6152, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 135200, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5dee000
475571 mmap(0xffffb5df0000, 69664, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5df0000
475571 munmap(0xffffb5dee000, 8192)     = 0
475571 munmap(0xffffb5e02000, 53280)    = 0
475571 mprotect(0xffffb5df1000, 61440, PROT_NONE) = 0
475571 mmap(0xffffb5e00000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5e00000
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
475571 read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\340u\2\0\0\0\0\0"..., 832) = 832
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=1641496, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 1810024, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5c36000
475571 mmap(0xffffb5c40000, 1744488, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5c40000
475571 munmap(0xffffb5c36000, 40960)    = 0
475571 munmap(0xffffb5dea000, 24168)    = 0
475571 mprotect(0xffffb5dc9000, 61440, PROT_NONE) = 0
475571 mmap(0xffffb5dd8000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x188000) = 0xffffb5dd8000
475571 mmap(0xffffb5dde000, 48744, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0xffffb5dde000
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/home/ubuntu/catkin_ws/devel/lib/libpthread.so.0", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/opt/ros/noetic/lib/libpthread.so.0", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/lib/aarch64-linux-gnu/libpthread.so.0", O_RDONLY|O_CLOEXEC) = 3
475571 read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0\267\0\1\0\0\0\0\0\0\0\0\0\0\0"..., 832) = 832
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=13736, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 135200, PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5c1e000
475571 mmap(0xffffb5c20000, 69664, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5c20000
475571 munmap(0xffffb5c1e000, 8192)     = 0
475571 munmap(0xffffb5c32000, 53280)    = 0
475571 mprotect(0xffffb5c21000, 61440, PROT_NONE) = 0
475571 mmap(0xffffb5c30000, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0) = 0xffffb5c30000
475571 close(3)                         = 0
475571 mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0xffffb5edb000
475571 set_tid_address(0xffffb5edb4f0)  = 475571
475571 set_robust_list(0xffffb5edb500, 24) = 0
475571 rseq(0xffffb5edbbc0, 0x20, 0, 0xd428bc00) = 0
475571 mprotect(0xffffb5dd8000, 16384, PROT_READ) = 0
475571 mprotect(0xffffb5c30000, 4096, PROT_READ) = 0
475571 mprotect(0xffffb5e00000, 4096, PROT_READ) = 0
475571 mprotect(0xffffb5e80000, 4096, PROT_READ) = 0
475571 mprotect(0xaaaadba62000, 8192, PROT_READ) = 0
475571 mprotect(0xffffb5ee1000, 8192, PROT_READ) = 0
475571 prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0
475571 munmap(0xffffb5e92000, 85175)    = 0
475571 getrandom("\xb1\xae\x75\x9d\x10\x30\x7b\x15", 8, GRND_NONBLOCK) = 8
475571 brk(NULL)                        = 0xaaab19fa2000
475571 brk(0xaaab19fc3000)              = 0xaaab19fc3000
475571 openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=4121216, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 4121216, PROT_READ, MAP_PRIVATE, 3, 0) = 0xffffb5831000
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/usr/lib/aarch64-linux-gnu/gconv/gconv-modules.cache", O_RDONLY) = 3
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=27004, ...}, AT_EMPTY_PATH) = 0
475571 mmap(NULL, 27004, PROT_READ, MAP_SHARED, 3, 0) = 0xffffb5ed4000
475571 close(3)                         = 0
475571 futex(0xffffb5ddd89c, FUTEX_WAKE_PRIVATE, 2147483647) = 0
475571 sigaltstack({ss_sp=0xaaaadba64400, ss_flags=0, ss_size=16384}, NULL) = 0
475571 openat(AT_FDCWD, "/usr/share/locale/locale.alias", O_RDONLY|O_CLOEXEC) = 3
475571 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=2996, ...}, AT_EMPTY_PATH) = 0
475571 read(3, "# Locale name alias data base.\n#"..., 4096) = 2996
475571 read(3, "", 4096)                = 0
475571 close(3)                         = 0
475571 openat(AT_FDCWD, "/usr/share/locale/en_US.UTF-8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale/en_US.utf8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale/en_US/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale/en.UTF-8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale/en.utf8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale/en/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en_US.UTF-8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en_US.utf8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en_US/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en.UTF-8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en.utf8/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 openat(AT_FDCWD, "/usr/share/locale-langpack/en/LC_MESSAGES/grep.mo", O_RDONLY) = -1 ENOENT (No such file or directory)
475571 rt_sigaction(SIGSEGV, {sa_handler=0xaaaadba390d8, sa_mask=[], sa_flags=SA_ONSTACK|SA_NODEFER|SA_RESETHAND|SA_SIGINFO}, NULL, 8) = 0
475571 fstat(1, {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x6), ...}) = 0
475571 newfstatat(AT_FDCWD, "/dev/null", {st_mode=S_IFCHR|0666, st_rdev=makedev(0x1, 0x3), ...}, 0) = 0
475571 fstat(0, {st_mode=S_IFIFO|0600, st_size=0, ...}) = 0
475571 lseek(0, 0, SEEK_CUR)            = -1 ESPIPE (Illegal seek)
475571 read(0, "hoge\n", 98304)         = 5
475571 newfstatat(1, "", {st_mode=S_IFCHR|0620, st_rdev=makedev(0x88, 0x6), ...}, AT_EMPTY_PATH) = 0
475571 write(1, "hoge\n", 5)            = 5
475571 read(0, "", 98304)               = 0
475571 close(1)                         = 0
475571 close(2)                         = 0
475571 exit_group(0)                    = ?
475571 +++ exited with 0 +++
475569 <... wait4 resumed>[{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 475571
475569 rt_sigaction(SIGINT, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, {sa_handler=0xaaaae0b1b6d8, sa_mask=[], sa_flags=0}, 8) = 0
475569 ioctl(2, TIOCGWINSZ, {ws_row=23, ws_col=222, ws_xpixel=0, ws_ypixel=0}) = 0
475569 ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
475569 newfstatat(AT_FDCWD, "/home/ubuntu/.terminfo", 0xaaab0980bd40, 0) = -1 ENOENT (No such file or directory)
475569 newfstatat(AT_FDCWD, "/etc/terminfo", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/lib/terminfo", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 newfstatat(AT_FDCWD, "/usr/share/terminfo", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
475569 faccessat(AT_FDCWD, "/etc/terminfo/x/xterm-256color", R_OK) = -1 ENOENT (No such file or directory)
475569 faccessat(AT_FDCWD, "/lib/terminfo/x/xterm-256color", R_OK) = 0
475569 openat(AT_FDCWD, "/lib/terminfo/x/xterm-256color", O_RDONLY) = 3
475569 newfstatat(3, "", {st_mode=S_IFREG|0644, st_size=3503, ...}, AT_EMPTY_PATH) = 0
475569 read(3, "\36\2%\0&\0\17\0\235\1\356\5xterm-256color|xterm"..., 32768) = 3503
475569 read(3, "", 28672)               = 0
475569 close(3)                         = 0
475569 ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
475569 ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
475569 ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
475569 ioctl(1, TCGETS, {B38400 opost isig icanon echo ...}) = 0
475569 ioctl(1, TIOCGWINSZ, {ws_row=23, ws_col=222, ws_xpixel=0, ws_ypixel=0}) = 0
475569 ioctl(0, TIOCGWINSZ, {ws_row=23, ws_col=222, ws_xpixel=0, ws_ypixel=0}) = 0
475569 brk(0xaaab0983d000)              = 0xaaab0983d000
475569 rt_sigprocmask(SIG_SETMASK, [CHLD], NULL, 8) = 0
475569 close(3)                         = -1 EBADF (Bad file descriptor)
475569 rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0
475569 --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=475570, si_uid=1000, si_status=0, si_utime=0, si_stime=0} ---
475569 wait4(-1, 0xffffe390aea0, WNOHANG, NULL) = -1 ECHILD (No child processes)
475569 rt_sigreturn({mask=[]})          = 0
475569 rt_sigprocmask(SIG_BLOCK, [CHLD], [], 8) = 0
475569 rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0
475569 exit_group(0)                    = ?
475569 +++ exited with 0 +++
```

</details>

### 大枠の確認

まずは、全体的にどんなシステムコールがあるのか確認してみます。

``` sh
$ cat bash-pipe | sed 's@(.*@@g' | awk '{print $2}' | grep '[a-z]' | sort | uniq -c | sort -n
      1 getpgid
      1 getppid
      1 lseek
      1 pipe2
      1 rt_sigreturn
      1 sigaltstack
      1 sysinfo
      1 uname
      2 clone
      2 dup3
      2 execve
      2 fstat
      2 futex
      2 getrandom
      2 rseq
      2 set_tid_address
      2 write
      3 exit_group
      3 prlimit64
      3 wait4
      4 getpid
      4 set_robust_list
      7 brk
      9 getegid
      9 geteuid
      9 getgid
      9 getuid
     10 ioctl
     12 faccessat
     13 read
     15 munmap
     18 mprotect
     20 rt_sigprocmask
     25 close
     31 rt_sigaction
     33 mmap
     54 openat
    106 newfstatat
```

少ないほど重要なので上から見ていくと、pipe2, clone, dup3 など怪しそうです。

システムコール以外にも、

``` 
+++ exited with 0 +++
```

との出力が目につきます。

色々と実験してみた結果、これは

- パイプで繋がれたコマンドごとの終了ステータス
- パイプ全体としての（bash としての）終了ステータス（一番最後）

になってそうでした。

よって、この前後を見ることにより、どのようにパイプを繋げているのか理解できそうです。

### プロセスを追う

まず大雑把に、プロセスが何をしているか確認してきます。

1行目で、[execve](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/execve.2.html) により bash が実行されています。

```
475569 execve("/usr/bin/bash", ["bash", "-c", "echo hoge | grep o"], 0xffffd9191e98 /* 52 vars */) = 0
```

続いてこのプロセス 475569 において、177, 194 行目で clone が実行され、プロセスが複製されています。

```
475569 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0xffffa7a5b0f0) = 475570
...
475569 clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD <unfinished ...>
...
475569 <... clone resumed>, child_tidptr=0xffffa7a5b0f0) = 475571
```

その結果、PID 475570 と 475571 が生成されました。
後のシステムコールから、それぞれ echo と grep が実行されることがわかります。

ここでは、次の3つのフラグが指定されています。

- CLONE_CHILD_CLEARTID
  - 子プロセスが終了すると、子プロセスのメモリ空間の特定の場所に0を書き込む
  - child_tidptr で指定
  - スレッドの終了を監視
- CLONE_CHILD_SETTID
  - 子プロセス（またはスレッド）のTID（スレッドID）を child_tidptr が指す場所に保存する
  - スレッドん管理
- SIGCHLD
  - 子プロセスが終了したときに親プロセスに SIGCHLD シグナルを送信する

また、これらの**プロセスの間を橋渡しするために、pipe2 というシステムコール**（175 行目）が呼ばれています。
pipe2 は、繋げた pipe の数だけ呼ばれます。

```
475569 pipe2([3, 4], 0)                 = 0
```

ここでは、ファイルディスクリプタ（fd）3 が読み取り端・4 が書き込み端になっています。

また、実行順序としては clone よりも前です。

**わかったこと**

- pipe で繋がれるそれぞれのコマンドに対し、プロセスが生成される
  - 親のプロセスからの **clone** による
- pipe で繋がれる**1つ目のコマンドが始まる前**に、必要なプロセス分 clone が走る
- プロセス間でやり取りするための pipe2 システムコールが、pipe | の数だけよばれる
  - 実行は clone よりも前

### 1 つ目の子プロセス 475570 に着目

ここは pipe の1つ目である、

``` sh
echo hoge
```

を実行するためのプロセス ID に該当します。

本プロセス ID で実行されたシステムコールは、計33回でした。

``` sh
$ cat bash-pipe | grep -E '^475570 ' | wc -l
33
```

その中でも以下の部分が特に関係してそうです。

```
475570 dup3(4, 1, 0 <unfinished ...>
475570 <... dup3 resumed>)              = 1
475570 close(4 <unfinished ...>

475570 write(1, "hoge\n", 5 <unfinished ...>
```

1. [dup3](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/dup.2.html) により複製され、 fd4 と fd1 が繋がる
2. fd1 (標準出力) に書き込みをする
3. fd1 への書き込みでは、1 により fd4 にも書き込まれる
   1. fd4 は親プロセス(475569)の pipe2 で繋げた書き込み端に該当

**わかったこと**

- 親プロセス(475569)の pipe2 で繋げた書き込み端に該当する fd と、標準出力 fd を繋げる

pipe2 で fd4 の書き込みが fd3 の読み込みに繋がっていたことを思い出し、先に進んでみます。

### 2 つ目の子プロセス 475571 に着目

ここは pipe の2つ目である、

``` sh
grep o
```

を実行するためのプロセス ID に該当します。

本プロセス ID で実行されたシステムコールは、計189回でした。

``` sh
$ cat bash-pipe | grep -E '^475571 ' | wc -l
189
```

その中でも特に関係してそうな箇所を勝手にぴくアップしました。

```
475571 dup3(3, 0, 0)                    = 0
475571 close(3)                         = 0

475571 execve("/usr/bin/grep", ["grep", "o"], 0xaaab09808620 /* 52 vars */) = 0
```

1. [dup3](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/dup.2.html) により複製され、 fd3 と fd0 が繋がる
2. `/usr/bin` の中の `grep` が用いられ、`grep o` が実行される
   1. 引数がないため、標準入力から読み取られる
3. fd0 の読み込みは、1 により fd3 からの読み取りに相当する
   1. fd3 は親プロセス(475569)の pipe2 で繋げた読み込み端に該当

**わかったこと**

- 親プロセス(475569)の pipe2 で繋げた読み込み端に該当する fd と、標準入力 fd (fd0) を繋げる

## 今後知りたいこと

- fork, clone の違い
  - 何がどう共有されるのか・されないのか
- 標準入出力は、どの範囲で共有されてるのか

## Links

- system call document
  - [execve](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/execve.2.html)
  - [dup3](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/dup.2.html)
  - [clone](https://kazmax.zpp.jp/cmd/c/clone.2.html)
  - [pipe2](https://linuxjm.osdn.jp/html/LDP_man-pages/man2/pipe.2.html)
