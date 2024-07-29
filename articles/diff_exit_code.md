# GitHub Actions 内で diff エラー

## エラー詳細
GitHub の Actions のなかで、次のようなステップを実行しました。

``` yaml
- name: Build
  run: |
    ...
    diff_license=`diff "${fileA}" "${fileB}"`
    ...
```

ところが次のようなエラーが発生し、次に進めませんでした。

```
Error: Process completed with exit code 1.
```

diff のコマンドの部分の終了コードが 1 を返すことが問題なようです。

## diff コマンドの終了コード
`diff` コマンドの終了ステータスは以下のようになっています。

- 0：差分が**ない**とき
- 1：差分が**ある**とき
- 2：ファイルが存在しないとき

（予想に反して？）差分がある場合 1 が返ってきて、これが問題になっているようです。

``` bash
$ echo a > a
$ echo b > b

# 差分がない場合
$ diff a a
$ echo $?
0

# 差分がある場合
$ diff a b
1c1
< a
---
> b
$ echo $?
1

# ファイルが存在しない場合
$ diff a c
> diff: c: No such file or directory
$ echo $?
2
```

## 解決策
今回の場合、diff コマンドの内容がエラーと判定されて処理が中断されてしまってることが原因のようです。

一般に、クリプトの途中のエラーで実行を中断するのは良いことが多く、`set -e`などをつけることが多いです。

GitHub Actions がよしなに付けてくれているものと思われますが、これを一旦外してあげることで解決しました（基本的には`set -e`をつけておいた方がいいと考え、`diff`コマンド直後にもとに戻しています。）


``` yaml
- name: Build
  run: |
    ...
    set +e
    diff_license=`diff "${fileA}" "${fileB}"`
    set -e
    ...
```



## おわりに
GitHub Actions は詰まるところが多いですが、その分色々と勉強になって楽しいです。

次は独自の Actions を作ってみたいと思います。
