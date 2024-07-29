# .gz ファイルをまとめて cat する

apache のログは、貯めていくと勝手に .gz ファイルに圧縮されるかと思います。

例えば、自分のラズパイ上の apache のログは以下のようになっています。

```sh
/var/log/apache2$ ls
 access.log	    access.log.13.gz   access.log.5.gz	 access_log	   error.log.12.gz   error.log.4.gz   error.log.9.gz
 access.log.1	    access.log.14.gz   access.log.6.gz	 error.log	   error.log.13.gz   error.log.5.gz   other_vhosts_access.log
 access.log.10.gz   access.log.2.gz    access.log.7.gz	 error.log.1	   error.log.14.gz   error.log.6.gz  'udo ufw status'
 access.log.11.gz   access.log.3.gz    access.log.8.gz	 error.log.10.gz   error.log.2.gz    error.log.7.gz
 access.log.12.gz   access.log.4.gz    access.log.9.gz	 error.log.11.gz   error.log.3.gz    error.log.8.g
```

このままでは解析に使いづらいので、gzip のファイルと普通のファイルをワンライナーで cat して標準出力として返す方法を考えたのでメモしておきます。

[:contents]

## 時間がないひとまとめ
- 以下のコマンドで access.log* のファイル全てが cat できます
- zcat したものをもう１回ファイル入力として取り扱うため、効率は良くない気がしてます

```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`)

# あとはこの後に続けて解析を行う
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
    awk '$9 == 404 {print $7}' | sort | uniq -c | sort -k1nr
```

## 非圧縮ファイルのみの中身を全て見る
「ファイルの中身を見る」といえば、もちろん`cat`を使います

### 複数ファイルを同時に見る
複数ファイルを対象に中身を見るには、以下のようにファイル名を続けて渡してあげます（これが concatenate!）

```sh
$ cat access.log access.log.1
```

### カレントディレクトリ配下の全てのフォルダを見る
複数ファイルを cat の引数（？）として渡せばいいことは分かりましたが、このままでは毎回ファイル名を調べて手打ちしなければなりません。

それをしたくない人は以下のようにコマンドの結果を渡してあげます。

```sh
# `ls access.log*` には ls access.log* の結果が展開される
$ cat `ls access.log*`
```

ところが`.gz`ファイルに`cat`をかけると文字化けするので（終了ステータスは 0 のためエラーではない？）、.gz ファイルを除いてあげます

```sh
# grep は -v オプションで、「マッチしなかったもの」という意味 (invert-match)
$ cat `ls access.log* | grep -v ".gz"`
```

## 圧縮ファイルのみの中身を全て見る

### 圧縮ファイルを見る
圧縮ファイルの中身が気になったら、解凍してから閲覧する方法が簡単かと思います。

しかし Linux には解凍せずとも中身を閲覧するコマンドが用意されているので、今回はそれを使ってみます。

```sh
# zcat コマンドで解凍せずとも閲覧できる
$ zcat access.log.3.gz
```

### 圧縮ファイルのみを全て閲覧する
非圧縮ファイルの時と同じような要領でファイルをコマンドの結果から渡してあげます

```sh
$ zcat `ls access.log* | grep ".gz"`
```

## 圧縮ファイルと非圧縮ファイルの全てを合わせて見る
cat と zcat の結果を合わせて使いたいと思います。

そのために zcat の結果に関しては、「プロセス置換でファイル入力に戻した後、cat に渡してあげる」という方針を取ります。

### プロセス置換でファイル入力のように扱う
プロセス置換とは、

> `<(command)`とすることで、コマンドの実行結果をファイルのように渡せる

というものです。

例として、以下のように`echo`で標準出力するという簡単なコマンドを`cat`に渡してあげます。

```sh
$ cat <(echo 'hi')
hi
```

何が起こっているかを説明します。

1. `echo`の結果、"hi" と標準出力に出力される（はずだった）
2. 標準出力に出力されるべきだった**中身**が、プロセス置換によってファイルとして渡されなおす
3. ファイルとなったプロセス（中身は "hi"）を`cat`することで中身が表示される

あんまり現実でのユースケースが思いつかないのですが、diff をとる際など便利かもしれません。

```sh
$ diff <(echo "hige") <(echo "hoge")
```

### zcat 関連の結果を全てプロセス置換として渡す

```sh
# zcat `ls access.log* | grep "gz"` はそのままでは標準出力
#  → プロセス置換でファイルとして扱う
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`)
```


## おわりに
やっぱり無理矢理やっている感が否めませんが、とりあえず「全ての log ファイルをワンライナーで閲覧する」という当初の目的は達成できました。

次回からは、これを使って怪しいログなどを解析してみたいと思います。
