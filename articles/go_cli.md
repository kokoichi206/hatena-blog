# Go 言語で CLI ツールを爆速で作る方法

**TOC**

- [なぜ Go 言語で CLI ツールを作るのか](#なぜ-go-言語で-cli-ツールを作るのか)
- [作り方](#作り方)
  - [サブコマンドを取らない場合](#サブコマンドを取らない場合)
  - [サブコマンドを取る場合](#サブコマンドを取る場合)
    - [cobra の使用例](#cobra-の使用例)
    - [urfave/cli](#urfavecli)
- [実際にやってみる](#実際にやってみる)
  - [setup](#setup)
  - [初期化](#初期化)
  - [サブコマンドの追加](#サブコマンドの追加)
- [注意点](#注意点)

## なぜ Go 言語で CLI ツールを作るのか

以下の 4 点がぱっと思いつきますね。

1. 作ってて楽しい
1. クロスコンパイル可能なので、複数プラットフォームへの対応が容易
1. コンパイラ言語であるためそこそこ性能がでる
1. 作ってて楽しい

また、みなさんがよく使ってるコマンドも、実は go でできてた、なんてことも多いと思います。

## 作り方

主に『サブコマンドを取る形式にするかどうか』で大きく 2 つに分類されます。

### サブコマンドを取らない場合

サブコマンドを取らない場合というのは、`ls` コマンドのように『コマンド + オプション』で完結するタイプのコマンドを指しています。

この手のコマンドを作成する場合、公式の [flag](https://pkg.go.dev/flag) の package だけ事足りますが、『ロングオプションとショートオプションを手軽に記述したい』などの要望があるときは [spf13/pflag](https://github.com/spf13/pflag) などのパッケージを利用すると便利です。

### サブコマンドを取る場合

サブコマンドを取る場合というのは、`git` コマンドのように『コマンド + サブコマンド + オプション』のように、複数のサブコマンドを取るタイプのコマンドを指しています。  
（`git add xxx`, `git commit` では、`add`, `commit` の部分をサブコマンドと呼ぶことにします）

この場合は、サードパーティのパッケージにおとなしく頼るのが吉です。  
その中でも [spf13/cobra](https://github.com/spf13/cobra) と [urfave/cli](https://github.com/urfave/cli) が有名です。

どちらも数多くの使用例があり github を参考にできます。

#### cobra の使用例

[『Projects using Cobra』](https://github.com/spf13/cobra/blob/main/projects_using_cobra.md) に~~みせびらかすように~~使用例が列挙されており、そのすごさが見てとれます。

[kubectl](https://github.com/kubernetes/kubectl) や [docker](https://github.com/docker/cli), hugo, github-cli がこちらのパッケージを使って出来ているらしいです（強すぎ）。

#### [urfave/cli](https://github.com/urfave/cli) の使用例

こちらは特に公式にまとめられてるとかはなかったのですが、[ghq](https://github.com/x-motemen/ghq) （や [opencontainers/runc](https://github.com/opencontainers/runc), [ovh/cds](https://github.com/ovh/cds)）が実はそうみたいですね。

[以前 git に関する cli を作った時](https://kb.tokyo.optim.co.jp/open.knowledge/view/1630)はこちらを使いました。

## 実際にやってみる

今回は参考にできるリポジトリの多さから cobra でサブコマンド付きの cli を作成してみたいと思います。  
（以下内容は [gitlab](https://gitlab.tokyo.optim.co.jp/takahiro.tominaga/cobra-example) にあげてます。また、最近個人で作ってみてる cli は [github](https://github.com/android-project-46group/sgi-cli) で確認できます。）

### setup

```sh
# go プロジェクトを初期化
$ go mod init gitlab.tokyo.optim.co.jp/takahiro.tominaga/cobra-example

# のちに使うため、cobra に加えて cli もインストールする
$ go install github.com/spf13/cobra-cli@latest
$ go install -v github.com/golangci/golangci-lint/cmd/golangci-lint@v1.50.1
```

### 初期化

先ほどインストールした cobra-cli を使って、cobra プロジェクトとしての初期化を行います。

```sh
# init 前
.
├── README.md
└── go.mod

# init
$ cobra-cli init

# init 後: いくつかのファイルが生成されている
$ ls
.
├── LICENSE
├── README.md
├── cmd
│   └── root.go
├── go.mod
├── go.sum
└── main.go
```

この状態で適当に動かしてみましょう

```sh
$ go run main.go
A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.
```

きちんと起動はしてそうですが、これ以上何もできないので、お待ちかねのサブコマンドを追加してみます。

### サブコマンドの追加

先ほど同様、cobra-cli を使って追加していきます。

```sh
# cobra-cli add <コマンド名>
$ cobra-cli add hello

# cmd/hello が追加された
.
├── LICENSE
├── README.md
├── cmd
│   ├── hello.go
│   └── root.go
├── go.mod
├── go.sum
└── main.go

# hello サブコマンドを叩く
$ go run main.go hello
hello called
```

今回はこの hello コマンドを変更し、『`name` オプションに名前を取り、その名前を使って出力』させてみたいと思います。

`cmd/hello` の中身は以下のようになっています。  
どうやら `fmt.Println("hello called")` を変更したらよさそうです。

```go
package cmd

import (
"fmt"

"github.com/spf13/cobra"
)

// helloCmd represents the hello command
var helloCmd = &cobra.Command{
Use:   "hello",
Short: "A brief description of your command",
Long: `デフォルトの説明長すぎてカット.`,
Run: func(cmd *cobra.Command, args []string) {
fmt.Println("hello called")
},
}

func init() {
rootCmd.AddCommand(helloCmd)
}
```

フラグを追加してみます。  
フラグは [spf13/pflag](https://pkg.go.dev/github.com/spf13/pflag) が使われているので、慣れているとサブコマンド無しの cli も作りやすいと思います。

```go
// helloCmd represents the hello command
var helloCmd = &cobra.Command{
...
Run: func(cmd *cobra.Command, args []string) {
                // 先ほどのフラグを受け取る。
name, err := cmd.Flags().GetString("name")
if err != nil {
fmt.Println(err)
}
fmt.Printf("Hello %s!\n", name)
},
}

func init() {
        // **対象のコマンドに対し**フラグを追加
        // ロングオプション, ショートオプション, デフォルト値, 説明 の順
        // documentation: https://pkg.go.dev/github.com/spf13/pflag#StringP
helloCmd.Flags().StringP("name", "n", "john doe", "your name")
rootCmd.AddCommand(helloCmd)- [なぜ Go 言語で CLI ツールを作るのか](#なぜ-go-言語で-cli-ツールを作るのか)
}
```

実行してみます。

```sh
$ go run main.go hello --name kotlin
Hello kotlin!

# していないときはデフォルト値が入る
$ go run main.go hello
Hello john doe!
```

なお、オプションの型を bool にすると `-a` などのみで値を与えることが可能です。

## 注意点

`2. クロスコンパイル可能なので、複数プラットフォームへの対応が容易` の良さを生かすためには、OS に固有の表現を使わないことが大切です。

例えば、パスの記述などでを string の結合で書くのはやめましょう。  
パスや URL の扱いは、まともな言語なら標準のパッケージがあるのでそれを使うように意識します（[com](https://gitlab.tokyo.optim.co.jp/takahiro.tominaga/cobra-example/-/commit/c1edbdb90947e38bb41a033d068c80a2559394d6)）。

```go
pwd, _ := os.Getwd()
// dir + "/" + fileName とかで結合しない
joined := filepath.Join(pwd, "./README.md")
fmt.Printf("path to README.md: %s\n", joined)
```

実行例

```sh
# linux 環境
$ go run main.go readme
path to README.md: /home/tominaga/stamp/cobra-example/README.md

# windows 環境 (cmd)
>go run main.go readme
path to README.md: C:\Users\OPM004972\Documents\work\memo_dx\stamp\cobra-example\README.md
```

なお、ci 環境で複数プラットフォーム向けバイナリを作成するには [goreleaser](https://goreleaser.com/) が便利です（[gh-actions の例](https://github.com/android-project-46group/sgi-cli/blob/main/.github/workflows/release.yml)）。
