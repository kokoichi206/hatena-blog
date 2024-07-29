# xargs で並列処理

xargs では -P オプションを使うことで並列処理させることが可能です。

```sh
# -P2 の 2 の数は何個並列で走らせるかを表す
$ ... | xargs -P2
```

```
* [最大実行数の確認](#最大実行数の確認)
* [実験](#実験)
  * [並列処理されてること](#並列処理されてること)
  * [論理 CPU を超えた場合](#論理-cpu-を超えた場合)
* [おわりに](#おわりに)
```

```sh
# -P2 の 2 の数は何個並列で走らせるかを表す
$ ... | xargs -P2
```

## 最大実行数の確認

論理 CPU の数は、以下のいずれかの方法で取得可能です。

```sh
# 以下ディレクトリのファイルの中身を見てプロセッサの数を確認 (linux)。
$ cat /proc/cpuinfo | grep processor | wc -l
4

# 以下の変数でも確認が可能。
$ echo $(nproc)
4
```

xargs にそのままぶち込むことも可能です。

```sh
# 全ての .png ファイルを、convert を使って .jpg に変換する例。
$ ls *.png | sed 's/\.png//' | xargs -P$(nproc) -I@ convert @.png @.jpg
```

## 実験

マルチプロセスとして**複数同時に処理**されていることを確認します。

```sh
# -P フラグなし
## 1 + 2 + 3 = 6 秒かかる
$ time seq 3 | xargs -I@ sleep @
real    0m6.036s
user    0m0.001s
sys     0m0.044s

# -P フラグあり
## 並列に実行されていることがわかる。
## max(1 + 2 + 3) = 3 秒かかる。
$ time seq 3 | xargs -P3 -I@ sleep @
real    0m3.025s
user    0m0.009s
sys     0m0.030s
```

### 並列処理されてること

以下のような計算をさせることで、実は並列実行されていることがわかります。

``` sh
# CPU に負荷をかける処理。
$ time echo -e '1\n2\n3' | xargs -I{} -P 3 bash -c 'for i in {0..100000}; do sum=$(($sum + $i)); done'

real    0m1.420s
user    0m3.944s
sys     0m0.199s
```


### 論理 CPU を超えた場合

``` sh
# CPU を消費しない処理はそのまま実行される。
$ time echo -e '1\n2\n3\n1\n2\n3\n1\n2\n3\n1\n2\n3' | xargs -I{} -P 12 sleep {}

real    0m3.075s
user    0m0.008s
sys     0m0.101s

# CPU を消費する計算は論理 CPU の数までしかスケールしない。
## 論理 CPU ギリギリの時は、ほとんど実時間は変わらない。
$ time echo -e '1\n2\n3\n1' | xargs -I{} -P 4 bash -c 'for i in {0..100000}; do sum=$(($sum + $i)); done'

real    0m1.521s
user    0m4.981s
sys     0m0.267s

## 12 プロセス走らせた場合。
$ time echo -e '1\n2\n3\n1\n2\n3\n1\n2\n3\n1\n2\n3\n' | xargs -I{} -P 12 bash -c 'for i in {0..100000}; do sum=$(($sum + $i)); done'

real    0m4.292s
user    0m14.312s
sys     0m0.964s
```

## おわりに

linux で並行で処理を使う機会はそうそうないかと思いますが、積極的に探して使っていきたいと思いました。

また、linux には他にも並行処理を実現する手段として、`parallel`コマンドなども有名なようです。こちらも機会があればふれてみたいと思います。
