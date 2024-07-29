# awk 1 とは何か

`awk 1`という表現についてメモしておきます。

## awk
大前提として、`awk`の基本パターンは『（マッチ）パターン＋アクション』です。

そして awk では以下のように記述します

``` sh
# awk 'pattern {action}'
$ echo 'hoge fuga pien' | awk '/fuga/ {print $0}'
hoge fuga pien
```

### どちらか一方の省略
実は「パターン」or「アクション」はどちらか一方を省略することができます。

#### パターンが省略された場合
パターンが省略された場合、全ての行に対してアクションが行われます。

``` sh
$ echo -e 'hoge fuga pien\npoe ho'
hoge fuga pien
poe ho

$ echo -e 'hoge fuga pien\npoe ho' | awk '{print $1}'
hoge
poe
```

#### アクションが省略された場合
アクションが省略された場合、`{print $0}`と同等のアクションが行われます。

``` sh
$ echo -e 'hoge fuga pien\npoe ho'
hoge fuga pien
poe ho

# awk '/fuga/ {print $0}' と同等
$ echo -e 'hoge fuga pien\npoe ho' | awk '/fuga/'
hoge fuga pien
```

## awk 1
以上`awk`の基本的性質を押さえておくと、`awk 1`という表現の意味が見えてきます。

この表現は、アクションが省略されたものであるり、また、パターンが『1』であることが分かります。

よって、**awk 1 とは全ての入力行に対し`{print $0}`を行う**ものとなります。

これは**最終行に改行を入れる**ことなどができます。

``` sh
# 行末に改行がない
xx@yy:~$ echo -en 'hoge'
hogexx@yy:~$

xx@yy:~$ echo -en 'hoge' | awk 1
hoge
xx@yy:~$
```

なお、awk では 0 より大きな値は真の判定がなされるため、`awk 3`などでも同様の効果があります。

``` sh
# 0 より大きな値
xx@yy:~$ echo -en 'hoge' | awk 3
hoge
xx@yy:~$
```


## おわりに
今回は、ぱっと見で何をしているのかわからなかった `awk` コマンドについて記載してみました。

次やるときに迷わないようしたいです！
