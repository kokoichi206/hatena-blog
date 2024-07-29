# ターミナルを使って、特定のファイルを見つける
ファイル検索をする方法として、今回は`locate`と`find`のコマンドを整理しておきます。

ファイル名はわかっている時は`locate`、更新日時やサイズなどで詳細な検索をかけたいときは`find`、と使い分けたらいいのかなと思っています。

## locate
```sh
$ man locate 
NAME
     locate -- find filenames quickly

SYNOPSIS
     locate [-0Scims] [-l limit] [-d database] pattern ...
...
```

とあるように、高速にファイルを見つけてくれるんだと思います。

ubuntuの場合は、`mlocate`を別途インストールする必要があります。

```sh
$  sudo apt install mlocate
```

### 使い方
次の例のように、`locate(mlocate)`の後に続いてパターンを記述します。

```sh
# -i は ignore case (大文字小文字を無視)
$ mlocate /home/*/readme.md
```

## find
手始めに manual を見てみましょう

```sh
$ man find
FIND(1) 
NAME
  find - search for files in a directory hierarchy
SYNOPSIS
  find [-H] [-L] [-P] [-D debugopts] [-Olevel] [starting-point...] [expression]
```

### オプション
`find`は優秀なコマンドなので（？）、オプションが50個以上存在します。

その中でも有名なものについていくつか確認してみようと思います。

| オプション | 説明 |
| --- | --- |
| -atime n | n 日を境にアクセスがあった |
| -ctime n | n 日を境に i ノードの変化があった |
| -group g | グループ g に属する |
| -link n | n 個のハードリンクを持つ |
| -ls | 詳しく表示する |
| -mtime n | n 日を境に変更があった |
| -name 'pattern' | パターンにマッチするファイル名 |
| -prune | 再帰的に検索しない |
| -size n | size n のもののみ |
| -type t | タイプが t のもののみ |
| -user u | ユーザー u が所有するもの |

### 使用例
オプションの説明の中で、「〜を境に」という表現をしたと思うのですが、その点について説明します。

`find`のオプションでは、1つのオプションで特定の期日よりも**前も後も**両方の指定が可能で、値の正負で判断しています。

つまり、

- 境界よりも前の日付のファイルに対してはプラスの値（+7など）
- 境界より直近の日付のファイルに対してはマイナスの値（-7など）
- ジャストのものはちょうどの値（7など）

で指定するというルールになっています。

```sh
# 確認
$ ls -l
total 12
-rw-rw-r-- 1 ubuntu ubuntu   44 Aug  8 07:25 command-file
-rw-rw-r-- 1 ubuntu ubuntu 3030 Jul 26 15:19 ipaddress.txt
-rw-rw-r-- 1 ubuntu ubuntu   34 Aug  7 05:30 test.sh

# フォルダを指定しなければ、カレントディレクトリから探す
$ find -atime +1   # 一日よりも前（過去）にアクセスのあったファイル
./ipaddress.txt
$ find -atime -1   # 直近一日の間にアクセスのあったファイル
.
./command-file
$ find -atime 1    # ジャスト一日前にアクセスのあったファイル
./test.sh

# 木構造を持ったフォルダを作る
$ mkdir pien
$ touch pien/file{1..3}
$ find *   # デフォルトでは再帰的に検索される
command-file
ipaddress.txt
pien
pien/file3
pien/file2
pien/file1
test.sh
# -prune オプションで入って行かせない
$ find * -prune
command-file
ipaddress.txt
pien
test.sh

# size option
$ find -size 0   # サイズ 0 のものを探す
./pien/file3
./pien/file2
./pien/file1
$ find -size +1  # サイズが 1 kb より大きいもの
.
./pien
./ipaddress.txt
# この結果が微妙。。。
# 個人的には 1 kb 未満になってほしい
$ find -size 1  # サイズが 1 kb のもの
./test.sh
./command-file
$ find -size -1   # サイズが 1 kb より小さなもの
./pien/file3 
./pien/file2
./pien/file1

# type option
$ find -type d  # only directory (d)
.
./pien
$ find -type f  # only folder (f)
./test.sh
./pien/file3
./pien/file2
./pien/file1
./command-file
./ipaddress.txt
```


## おわりに
find のマニュアルを見ていて、

- search for <物>
- search <場所>

っていう文法を思い出しました（笑）

英語力を高めていきたいです。

