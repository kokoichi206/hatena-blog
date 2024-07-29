# Hellow Deno
今回は deno という言語について軽く触れた後、世界と挨拶すること（hellow world）を目指して頑張ります。

## deno とは何か
> **A modern runtime for JavaScript and TypeScript.**

こんなこと書かれたら deno を勉強しないわけにはいきませんよね！？

以下は[公式]((https://deno.land/)からの説明です。

Deno は　JavaScript と TypeScript を実行できる、シンプルでモダンでセキュアな言語です。そして、以下のような特徴を持ちます。

- デフォルトでセキュアな設定
  - ファイル、ネットワークや環境へのアクセスは、明示的に許可する必要がある
- インストール後すぐに TypeScript を使える
- 唯一の実行ファイルを持つ
- info や fmt などの、組み込みで使える便利なものが多い
- 標準モジュールがいっぱいあるよ！

それでは早速見ていきましょう。なお以下の環境は macOS で動作確認しています。

## install
まずインストール方法ですが、各 OS は[公式](https://deno.land/)に従えば大丈夫だと思います。

```sh
$ curl -fsSL https://deno.land/x/install/install.sh | sh
##################################################### 100.0%#=#=#
##################################################### 100.0%
Archive:  ~~~
  inflating: /home/ubuntu/.deno/bin/deno  
Deno was installed successfully ~~~
Manually add the directory to your $HOME/.zshrc (or similar)
  export DENO_INSTALL="/home/ubuntu/.deno"
  export PATH="$DENO_INSTALL/bin:$PATH"
Run '/home/ubuntu/.deno/bin/deno --help' to get started
```

と出るので、指示に従って`zshrc (bash_profile)`に環境変数を追加していきます

```sh
# 下の２行を追加する
# export DENO_INSTALL="/home/ubuntu/.deno"
# export PATH="$DENO_INSTALL/bin:$PATH"
$ vim ~/.zshrc
```

環境を読み込み直して、バージョンを確認してみましょう

```sh
$ source ~/.zshrc
$ deno --version 
deno 1.13.2 (release, x86_64-apple-darwin)
v8 9.3.345.11
typescript 4.3.5
```

バージョンが表示されたらインストール成功です。

### VSCode で使えるようにする
1. denoland.vscode-deno をインストール
2. コマンドパレットから、`deno: Initialize ...`を選択


## Getting Started
詳しい使い方は[公式](https://deno.land/manual@v1.13.2)にもマニュアルとして用意されているので、気になった方は是非ご覧ください

### Hellow World
何はともあれ、ハローワールドでしょう

以下のような`hello.ts`を書きます

```ts
function hello(name: string): void {
    console.log(`Hello, ${name}`);
}

hello("World!");
```

そして以下のように実行します

```sh
$ deno run hello.ts
Hello, World!
```

### パーミッション制御
冒頭で、

> セキュリティがしっかりしており、明示的に捜査許可を与える必要がある

と書きましたが、具体的には以下のような`--allow-xxx`フラグが存在します（[公式サイト](https://deno.land/manual@v1.13.2/getting_started/permissions)）

- --allow-env
  - 環境変数の読み書き
- --allow-net
  - ネットワークのアクセス
- --allow-write
  - ファイルへの書き込み

などが存在し、必要によって与えてあげます

### Hellow World on server
次のように`hellow2.ts`を記述をします。

```ts
import { Application } from "https://deno.land/x/oak@v7.7.0/mod.ts";

const app = new Application();

app.use((ctx) => {
    ctx.response.body = "Hellow World!";
});

await app.listen({ port: 8888 });
```

これを、次のように`--allow-net`フラグをつけて実行します。（つけ忘れてもエラーも何も表示されません。。。）

```sh
$ deno run --allow-net hello_server.ts
```

うまくいったらブラウザを開いて`http://localhost:8888/`と入力してみましょう。Hellow World! と表示されているはずです。

## おわりに
今回は簡単な紹介で終わってしまいましたが、他にも様々な特徴がある面白い言語です。

個人的にはnpm, package.json などのファイルも存在しないこと、Deno のためのデプロイサービス（[Deno deploy](https://deno.com/deploy)）が用意されていることとかも特徴かなと思いました。

これからも機会があれば紹介してみようかと思っています。

