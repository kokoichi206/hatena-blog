# apache のアクセスログを linux コマンドでチョット確認してみた
自宅のラズパイ上に apache でサーバーを立てており、Android アプリのバックエンドとして利用しています。

今回はそのログを少し覗いてみたところ、個人的に面白い結果が得られたので共有をしたいと思います。

## HTTP ステータスコード集計

```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
 awk '{a[$9]++}END{for(i in a){print i, a[i]}}'
"-" 268
200 7134
206 14
301 39
304 1173
392 6
400 184
403 10
404 1296
405 10
408 7
500 85
```

## 404 関連調査
とりあえず 404 の多さにびびったので、その関連について調べてみます。

### どこにアクセスしようとしてる人が多いのか

```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
 awk '$9 == 404 {print $7}' | sort | uniq -c | sort -k1nr | head
58 /favicon.ico
52 /vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php
39 /.env
37 /boaform/admin/formLogin
37 /imgs/blog/nogi/itouriria.jpeg
35 /config/getuser?index=0
28 /_ignition/execute-solution
27 /console/
27 /index.php?s=/Index/\\think\\app/invokefunction&function=call_user_func_array&vars[0]=md5&vars[1][]=HelloThinkPHP21
```

`/.env`など明らかに悪意を感じます。

そのほかのアクセスに関しても何かしらの意図を持ってそうで怖いです

### 誰が多いのか
```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
 awk '$9 == 404 {print $1}' | sort | uniq -c | sort -k1nr | head
252 106.55.168.183
196 45.146.164.110
76 240f:74:c9f6:1:997:c06f:cbe6:1c6
62 240f:74:c9f6:1:a82d:e51e:708d:1bcb
43 88.80.186.144
40 193.169.254.179
28 185.216.203.49
22 240f:74:c9f6:1:6491:e11:f273:81bc
20 209.141.34.220
16 143.198.52.47
```

上２つは自分ものものかと思われますが、その他にも執拗にアクセスしてきてる人がいてびっくりしました（全ての攻撃を１通り試しただけ？）

### 何時が多いのか (UTC)
```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
 awk '$9 == 404 {print substr($4,14,2)}' |\
  sort | uniq -c | sort -k2 | awk '{print $2, $1}'
00 32
01 47
02 64
03 17
04 32
05 64
06 24
07 43
08 298
09 37
10 76
11 50
12 37
13 33
14 148
15 20
16 48
17 22
18 37
19 20
20 25
21 19
22 33
23 72
```

意外にもばらけました。絶対数が少ないのでなんとも言えませんが。


## 400 関連調査

### どこにアクセスしようとしてる人が多いのか
```sh
$ cat `ls access.log* | grep -v "gz"` <(zcat `ls access.log* | grep "gz"`) |\
 awk '$9 == 400 {print $7}' | sort | uniq -c | sort -k1nr | head
123 /
20 /cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh
8 /ab2g
8 /ab2h
5 /cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/%2e%2e/etc/hosts
4 /HNAP1/
4 /icons/.%%32%65/.%%32%65/apache2/icons/non-existant-image.png
4 /icons/.%%32%65/.%%32%65/apache2/icons/sphere1.png
4 /icons/.%2e/%2e%2e/apache2/icons/sphere1.png
1 /R1hq
```

`%2E`は`.`なので、`/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh`は`/cgi-bin/../../../../bin/sh`。。。

## おわりに
今回は apache サーバーのログを簡単に確認してみました。

少しみただけでも怖さの伝わるアクセスが多く、しっかりセキュリティについて勉強しようと思いました。

こんなところも確認しておいた方がいいよ！などあれば、是非コメントで教えていただきたいです。
