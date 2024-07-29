# terminal で alias の定義場所を探す

ターミナルで作業をする時、alias 等を使い極力文字数を減らして打ち間違いを防ぐ事が多いかと思います。

しかし [oh-my-zsh](https://ohmyz.sh/) などのツールによって設定された値など、たまに「あれ？これ**どこで定義された alias だっけ？**」ってなる事があります。

そんな時は以下のようなパワープレイが有効かもしれません。

**Bash**

``` sh
bash -ixlc : 2>&1 | grep alias_name
```

**Zsh**

``` sh
zsh -ixc : 2>&1 | grep alias_name
```

**なんとなくやってることの説明**

alias はシェルの様々なプロセスで設定されうるため、シェルを新規で立ち上げています。

- `-i` インタラクティブモードで
- `-x` デバッグ情報の出力を ON にする
    - XTRACE mode
- `-c` 続くコマンドを実行
- 何もしないコマンド `:` を実行
    - シェルの初期化時に読み込まれる設定や alias のみを与える
- `2>&1` 標準エラー出力の内容を標準出力に繋げる

``` sh
# オプションはこの辺が参考になるかも
man zshoptions | grep '\-x' -A5
```

**実行結果**

``` sh
# 環境
$ zsh --version
zsh 5.8.1 (x86_64-apple-darwin22.0)

# gf は ~/.oh-my-zsh/plugins/git/git.plugin.zsh:215 で定義されてる事がわかる
$ zsh -ixc : 2>&1 | grep gf=
+/Users/kokoichi/.oh-my-zsh/plugins/git/git.plugin.zsh:215> alias 'gf=git fetch'
+/Users/kokoichi/.oh-my-zsh/plugins/git/git.plugin.zsh:292> compdef _git 'ggf=git-checkout'
+compdef:132> [[ 'ggf=git-checkout' = -N ]]
+compdef:134> [[ 'ggf=git-checkout' = -p ]]
+compdef:136> [[ 'ggf=git-checkout' = -P ]]
+compdef:155> [[ 'ggf=git-checkout' = *=* ]]
```

## Links

- [Is it possible to check where an alias was defined?](https://unix.stackexchange.com/questions/322459/is-it-possible-to-check-where-an-alias-was-defined)
