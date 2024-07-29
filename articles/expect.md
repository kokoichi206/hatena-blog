# 【自動化の敵】対話型 CLI を expect で突破する

突然ですがみなさん、自動化しているでしょうか？

自動化するときに悩むのが、対話型 CLI に代表されるインタラクティブなツールの存在だと思います。

個人的には、**自動化もできない**し**打ち間違いも発生する**しで、対話型 CLI はエンジニアの使うツールとして最悪だと思ってます。選択式なら耐えです。

今回はそんな憎き敵を倒すために現れた救世主『expect』の紹介です（新しくはない）。
また、他に良さげな方法があれば教えてください。

**[目次]**

- expect のインストール
- expect の基本的な使い方
  - sudo を常にパスワードなしで実行させる
- おわりに

## expect のインストール

mac の人は [brew で入れるだけ](https://formulae.brew.sh/formula/expect)です。

``` sh
$ brew install expect

$ expect -v    
expect version 5.45.4
```

それ以外のプラットフォームでも基本的に使えるはずです。

## expect の基本的な使い方

よく使用例として上がってくるのは、ssh 接続の例（パスワードを直接シェルに打ち込み history 等に残したくないための対話型？）かと思いますが、ここでは sudo をパスワードなしでいけるようにしてみます。

``` sh
# sudo が必要な操作の例
$ mv automate /usr/local/bin        
mv: rename automate to /usr/local/bin/automate: Permission denied
```

ここで

``` sh
sudo mv automate /usr/local/bin
```

としてもいいのですが、パスワードを毎回打つのは手間なので以下のようにしてみます。

適当なスクリプトファイルに保存すれば実行可能です。

``` sh
#!/bin/bash

set -euo pipefail

expect -c "
    # 5 秒でタイムアウトにする。
    set timeout 5
    # 実行したいコマンド。
    spawn sudo mv automate /usr/local/bin

    # ターミナル上に現れることが期待される文言。
    expect \"Password:\"
    # 打ち込みたい内容。パスワードの例。
    send \"root_pass\"
    send \"\n\"

    expect \"$:\"
    exit 0
"
```

なお、expect の書き方には流儀があるみたいです。

### sudo を常にパスワードなしで実行させる

この書き方は不十分かつパスワードを起動時の設定ファイルの中に書くことになるため、あんまり良くない気もしてます。
こんなこともできる、という参考までに。

以下内容を .zshrc 等に書き込み、再読み込みさせます(source ~/.zshrc)。

``` sh
sudo_without_password() {
    if [ "$1" = "rm" ]; then
        echo "You are deleting file(s) with a root privileges."
        echo "Are you sure? (y/n)"
        read -r ans
        if [ "$ans" != "y" ]; then
            exit 1
        fi
    fi

    expect -c "
        # 5 秒でタイムアウトにする。
        set timeout 5
        # 実行したいコマンド。
        spawn \sudo $*

        # ターミナル上に現れることが期待される文言。
        expect \"Password:\"
        # 打ち込みたい内容。
        send \"my_password\"
        send \"\n\"

        expect \"$:\"
        exit 0
    "
}

alias sudo='sudo_without_password'
```

あとは いつも通り sudo ~~ と実行するのみです。

## おわりに

expect がどのように作られているか非常に興味があるので、これから少し調べてみようとしています！

それでは良き自動化ライフを！
