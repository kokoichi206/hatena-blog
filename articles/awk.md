# awk 入門
awk の使い方を簡単に紹介し、「awk 何それ？」っていう状態から「awk 使ったことあるよ」っていう状態になることを目指します。


## awk
- ファイルもしくは標準入力から渡された文字列を、パターン解析し処理していくような言語です。
- 「ワンライナーで、パイプの一要素として使う方法」と「１ファイルに .awk ファイルとして記述する方法」があります
  - 今回はパイプで繋ぐ使い方の紹介が多めです。
- １行ごとに解析・行の中でも１フィールドごとにアクセスできる、といった使い方が基本となります。

### オプション
よく使うオプションの一部を紹介します。

- \-F
  - フィールドの区切り文字を指定します
- \-v
  - 初期変数を定義します
- \-f
  - awk のコードをファイルから読み込ませたいときに使います


## 基本パターン
基本のパターンは、`'pattern{ action }'`となります。このことはぜひ頭に入れてください！

```sh
$ awk 'pattern{ action }'
```

### 各フィールドへのアクセス方法
`field1 field2 field3` という行の入力があった場合、awk で用いるには`$1, $2, $3`と指定します。また、`$0`は行全体を表します

```sh
$ echo 1 2 3 4 5 | awk '{print $1}'
1
$ echo 1 2 3 4 5 | awk '{print $0}'
1 2 3 4 5
```

### pattern の記述方法
pattern には条件を記述します。

普通の条件式のように、`string == pattern`としても良いですが、以下のように「~」を用いることで正規表現が使えます。

```
# どちらの書き方でも良い
"ABC" ~ "^[A-Z]+$"   # true
"ABC" ~ /^[A-Z]+$/   # true

# マッチしてないパターン（「!」で否定）
"012" !~ /^[A-Z]+$/   # true
```


### 特殊な pattern
２つの特殊な pattern として、BEGIN と END があります。その名の通り、BEGIN に続く{ action }は処理が始まる前に実行され、END に続く{ action }は処理が終わった後に実行されます。

BEGIN は初期変数や初期配列の定義、END は最終結果の出力などに使われることが多いです。

### 省略形
`pattern`と`action`のどちらか一方は省略が可能です。

```sh
# 各フィールドには、$1, $2,...とアクセスします
$ echo hoge | awk '$1 == "hoge"{print "hoge found"}'
hoge found

# pattern が省略されると、全ての行に対して action が実行されます
$ echo -e 'hoge\nfuga' | awk '{print "hoge found"}'
hoge found
hoge found

# action が省略されると、行全てを出力します
$ echo hoge | awk '$1 == "hoge"'
hoge
```


## 変数

### awk 組み込み変数
awk には、組み込みの変数がいくつか用意されています。

| 変数 | 説明 |
| --- | --- |
| FILENAME | input ファイルの名前 |
| FNR | ファイルの行数 |
| FS | フィールドの区切り文字(デフォルトは" ") |
| NF | フィールドの数 (横) |
| NR | レコードの数 (縦) |
| OFS | 出力のフィールドの区切り文字 |
| ORS | 出力の行の区切り文字 (デフォルトは"\n") |
| RS | 入力の行の区切り文字 (デフォルトは"\n") |

### 環境変数
シェルの環境変数にもアクセスできます。`ENVIRON`という名前の配列に格納されています。

```sh
$ awk 'BEGIN{ print ENVIRON["HOME"]; print ENVIRON["USER"]}'
/Users/kokoichi
kokoichi
```


## String メソッド

### よく使う関数一覧
| 関数 | 説明 |
| --- | --- |
| length(string) | 文字列の長さを取得 |
| substr(string, start, length) | 部分文字列を取得 |
| tolower(string) | 小文字に変換 |
| toupper(string) | 大文字に変換 |
| index(string, pattern) | patten が含まれるか検索 |
| split(string, array, regexp) | 分割された文字列が array に格納される |

### 使用例
```sh
$ echo "hogeHOGE" | awk '{print length($0)}'
8

# １オリジンっぽい
$ echo "hogeHOGE" | awk '{print substr($1, 5, 4)}'
HOGE

$ echo "hogeHOGE" | awk '{print tolower($0)}'
hogehoge
$ echo "hogeHOGE" | awk '{print toupper($0)}'
HOGEHOGE

$ echo "hogeHOGE" | awk '{print index($1, "hoge")}'
1
# case に sensitive
$ echo "hogeHOGE" | awk '{print index($1, "hoGe")}'
0

# split の戻り値は配列の要素数
$ echo "hogeHOGE" | awk '{print "要素数： ",split($1, pi, /[oO]/)}END{for(i=1;i<=length(pi); i++){print pi[i]}}'
要素数： 3
h
geH
GE
```


## Numeric メソッド

### よく使う関数一覧
| 関数 | 説明 |
| --- | --- |
| atan2(y, x) | arctan(y/x) を -π ~ +π で返す |
| cos(x) | cos関数 |
| sin(x) | sin関数 |
| exp(x) | exp関数 |
| int(x) | 整数値を返す |
| log(x) | log関数 |
| rand() | 0<= x < 1 の一様乱数 |
| srand(x) | 乱数生成の seed を x にセットする |
| sqrt(x) | √x |

### 使用例
```sh
$ awk 'BEGIN{print rand()}'
0.924046
# 意図的に seed を変更しないと、ずっと同じ
$ awk 'BEGIN{print rand()}'
0.924046

# srand(x) を使って変更してみる
# x を指定しないと、現在時刻の秒が使われる
$ awk 'BEGIN{srand();for(i=0;i<5;i++){print rand()}}'
0.22799
```


## おわりに
今回はあまり awk の実用例まで紹介できませんでした。

実際に、どのような場面で使えるのかをまた実演できたらと思います。

