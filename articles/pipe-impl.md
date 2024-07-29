# パイプの中身をシステムコールレベルで理解・実装する

『ふつうのLinuxプログラミング』を読んで勉強させてもらったメモになります。
コードは載ってなかったため自分で実装してみました。

**[目次]**

```
* [パイプ詳細説明](#パイプ詳細説明)
* [パイプ実装](#パイプ実装)
  * [環境](#環境)
  * [C](#c)
  * [Go](#go)
```

## パイプ詳細説明

Linux の世界で見たパイプとは**プロセスを両端に持ったストリーム**のことを指し、以下の特徴を持ちます。

- 他の概念同様ファイルディスクリプタを使って表現される
- 他のストリームと違ってパイプは一方向

以下のステップでパイプを実装できます。

1. あるプロセスで pipe(2) を実行
   * プロセス内でストリームを繋げる
2. fork して子プロセスを生成
   * プロセス複製時に**ストリームも含め複製**される
3. 必要ない fd を終端（両端で close）
   * 親プロセスの読み込みを close
   * 子プロセスの書き込みを close
4. 残った fd をそれぞれ標準入出力と対応付
   * dup2 を使う
   * （5 で実行するコマンドが標準入出力を取るものが多いため）
5. それぞれのプロセスでコマンド実行

## パイプ実装

### 環境

```
$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

### C

とりあえず2つのコマンドを繋げるようなパイプを作ってみました。
コメント書いたため説明は割愛します。

間違ってる箇所があれば教えてください。

``` c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char **argv)
{
    if (argc != 3)
    {
        fprintf(stderr, "Usage: %s <command1> <command2>\n", argv[0]);
        exit(1);
    }

    int fds[2];
    // 両端とも自プロセスに繋がったストリームを生成する。
    // fds[0] は読み込み専用 fds[1] は書き込み専用。
    pipe(fds);

    // 子プロセスと親プロセスの両方で呼び出しが戻る！！
    int pid = fork();
    if (pid < 0)
    {
        fprintf(stderr, "fork(2) failed\n");
        exit(1);
    }

    if (pid == 0)
    {
        // 子プロセス。

        // 書き込みのストリーム用の fd を閉じる。
        close(fds[1]);
        // 読み込みを標準入力のストリームに複製する。
        dup2(fds[0], STDIN_FILENO);
        close(fds[0]);

        execlp(argv[2], argv[2], NULL);

        // execlpが失敗した場合。
        perror("execlp child");
        exit(1);
    }
    else
    {
        // 親プロセス。

        // 読み込みのストリーム用の fd を閉じる。
        close(fds[0]);
        // 書き込みを標準出力のストリームに複製する。
        dup2(fds[1], STDOUT_FILENO);
        close(fds[1]);

        execlp(argv[1], argv[1], NULL);

        // execlpが失敗した場合。
        perror("execlp parent");
        exit(1);
    }

    wait(NULL);

    exit(0);
}
```

``` sh
gcc -g -Wall -o pipe pipe.c

./pipe ls wc
```

### Go

dup2 がなく、dup, dup3 しかなかったです。何の差でしょうか。
（mac には dup2 ありそう。）

``` go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s <command1> <command2>\n", os.Args[0])
		os.Exit(1)
	}

	rfd, wfd, err := os.Pipe()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Pipe creation failed: %v\n", err)
		os.Exit(1)
	}

	path1, err := exec.LookPath(os.Args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find %s: %v\n", os.Args[1], err)
		os.Exit(1)
	}

	pid, err := syscall.ForkExec(path1, []string{os.Args[1]}, &syscall.ProcAttr{
		Dir:   ".",
		Env:   os.Environ(),
		Files: []uintptr{os.Stdin.Fd(), uintptr(wfd.Fd()), os.Stderr.Fd()},
		Sys:   nil,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "ForkExec failed: %v\n", err)
		os.Exit(1)
	}

	wfd.Close()

	path2, err := exec.LookPath(os.Args[2])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find %s: %v\n", os.Args[2], err)
		os.Exit(1)
	}

	syscall.Dup3(int(rfd.Fd()), int(os.Stdin.Fd()), 0)
	rfd.Close()

	err = syscall.Exec(path2, []string{os.Args[2]}, os.Environ())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Exec failed: %v\n", err)
		os.Exit(1)
	}

	syscall.Wait4(pid, nil, 0, nil)
}
```

``` sh
go run pipe.go ls wc
```

syscall でシステムコールを呼べた気になってしまってます。
