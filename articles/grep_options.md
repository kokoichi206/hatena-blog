# grep で特定のフォルダを無視して再帰検索する

プログラミングにおいてコード内の特定の文字列を探すことは多いですが、特に大規模なプロジェクトでは、この作業が一筋縄ではいかないことがあります。
node_modules や dist といったディレクトリを含めたくない場合がその典型例です。

今回は, grep のオプションで解決する方法をメモしておきます。

**環境**

``` sh
$ grep --version
grep (BSD grep, GNU compatible) 2.6.0-FreeBSD

$ $(echo $SHELL) --version
zsh 5.8.1 (x86_64-apple-darwin22.0)
```

**再起的検索**

``` sh
# grpc という文字列を現在のディレクトリから(.)再帰的に(-r)検索する。
grep -r grpc .
```

**バイナリファイルを検索対象から除外**

``` sh
# -I (Ignore binary files.)
grep -I -r grpc .
# grep -Ir grpc .
```

**特定のディレクトリを検索対象から除外**

``` sh
# node_modules という名前のディレクトリを検索対象としない。
# サブディレクトリの一部でも対象となる(./xxx/node_modules/zzz も検索されない)。
grep -I -r --exclude-dir=node_modules grpc .

# 複数付け加えることも可能。
grep -I -r --exclude-dir=node_modules --exclude-dir=dist grpc .
```
