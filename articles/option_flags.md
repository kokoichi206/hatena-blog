# bash でシェルオプションを確認・変更する

『現在の**シェルセッションにおける変数と関数の一覧**を表示』するには set コマンドに何もつけずに叩きます。

``` sh
# 240 行もあり。
$ set | wc -l
242

# PATH だけを出力。
set | grep PATH
```

**シェルオプションの現在の状態**を表示するには `o` オプションをつけて叩きます。

``` sh
$ set -o
noaliases             off
aliasfuncdef          off
allexport             off
noalwayslastprompt    off
alwaystoend           on
appendcreate          off
noappendhistory       off
...
```

**オプションを変更する方法**

`-o` で off に、`+o` で on にすることができます。

``` sh
$ set -o | grep errexit
errexit               off

# on にする。
$ set -o errexit
$ set -o | grep errexit
errexit               on

# off にする。
$ set +o errexit      
$ set -o | grep errexit
errexit               off
```

また、ショートオプションとして用意されてるものもあります。

``` sh
# set -o errexit と同じ。
$ set -e
$ set -o | grep errexit
errexit               on

# set +o errexit と同じ。
$ set +e
$ set -o | grep errexit
errexit               off
```

詳しくは [man bash 4.3.1 The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) をご覧ください。
