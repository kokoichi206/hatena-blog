# コマンドで xxx の部分にランダムな数字を埋め込む

前回の記事で、`rig`コマンドを用いて擬似個人情報を出力する方法を紹介した。

```sh
$ rig
Edgar Durham
342 Stonehedge Blvd
Yonkers, NY  10701
(914) xxx-xxxx
```

**目標**

最後の電話番号のところがデフォルトでは xxx-xxxx となっているので、ここにランダムな数字を埋め込んで、よりデータっぽくしたい！

## rig の結果を置換する方法
早速自分の回答から見ていきます。

```sh
$ rig | sed "s/xxx-xxxx/`cat /dev/urandom | tr -dc 0-9 | head -c3`-`cat /dev/urandom | tr -dc 0-9 | head -c4`/g"
Jackson Hudson
370 Bryant Blvd
Athens, GA  30601
(404) 967-9207    # ここがランダムになった！ 
```

長いのでわかりにくいですが、基本的なのは以下のような感じです。

```sh
# 以下のコマンドでランダムな３桁の数を出力
$ cat /dev/urandom | tr -dc 0-9 | head -c3
346

# ``で囲むことで、その出力を sed 内で利用する
$ echo xxx | sed "s/xxx/`cat /dev/urandom | tr -dc 0-9 | head -c3`/g"
722
```


## （おまけ）ランダムな数字を生成する候補
- 環境変数 RANDOM を用いる

```sh
$ echo $RANDOM
16739
```

- 擬似デバイスの一種である`/dev/urandom`を利用する
  - ランダムバイトを出してるだけなので、文字コードにないものが多数あり文字化け（？）する
  - うまく変換してあげる必要がある

```sh
$ cat /dev/urandom
������H��6x~�����m��w�o&`xȁFzs���ptϸ4�M
...

$ cat /dev/urandom | tr -dc 0-9 | head -c 14
29023487176926
```

## （おまけ）ランダムな生成器を使うタイミング候補
自分がパッと思いついたのは以下の三つで、alias でやろうとしてうまくいきませんでした

- alias に関数として登録する
- シェル変数に登録する
- \`\` を用いて実行結果を受け取る

## おわりに
ターミナルでランダムな数字や文字列を得る方法については、また今度まとめて紹介したいと思いました

