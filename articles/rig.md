# Linux で擬似的な個人情報を得る
今回はターミナル上で実行できるコマンド`rig`を使って個人情報を出力する方法を紹介します

## 実行環境 
今回も例の如く、ubuntu（on raspberry pi） を用いています

## rig
`rig`コマンドとは、 Random Identity Generator の略であり、その名の通りランダムな個人情報を出力してくれるコマンドである

```sh
# 要インストール
$ sudo apt install rig

$ rig
Terrence Sanders  # first name, last name
317 Lake Dr  # street number and address,
Arlington, TX  76010 # geographically consistant city, state, ZIP code
(817) xxx-xxxx  # area code.
```

## オプション紹介
`man rig` でみる限り、以下のオプションが使えそうです。

- -f: female 女性の名前が出力される
- -m: male 男性の名前が出力される
- -d: 指定したデータフォルダを用いる。
  - デフォルトでは`/usr/share/rig`が用いられる
- c: 出力の回数を選択する

```sh
$ rig -c2
Darren Macdonald
209 Cooper St
Dayton, OH  45401
(513) xxx-xxxx

Crystal Rowe
1001 Maple Ln
Addison, IL  60101
(708) xxx-xxxx
```

## データセットを作る
あまり使えないなと思ったこのコマンドですが、擬似的なデータセットを作るのに使ってみました。

やはり1人の情報は横になってる方が良いので、`paste`を使って並べてます

```sh
$ rig -c3 | paste - - - - -
Conrad Owens    622 Third St    Garland, TX  75040      (903) xxx-xxxx
Dominick Snyder 578 Lincoln Rd  Indianapolis, IN  46206 (317) xxx-xxxx
Audra Barron    937 East Parson St      Passaic, NJ  07055      (201) xxx-xxxx
```

## （おまけ）データフォルダを覗いてみる
`man rig`によると、デフォルトのデータは`/usr/share/rig`にあるとのことだったので、そこを少しみてみようと思います。

```sh
# ファイルの確認
$ ls /usr/share/rig
fnames.idx  lnames.idx  locdata.idx  mnames.idx  street.idx

# fnames(female names)の確認
$ head /usr/share/rig/fnames.idx 
Mary
Patricia
Linda
Barbara

# 各ファイル、どのくらいのデータ数あるのか確認
$ ls /usr/share/rig/ | \
xargs -I@ bash -c 'echo -n @ && cat /usr/share/rig/@ | wc'
fnames.idx   1000    1000    7942
lnames.idx   1000    1000    8119
locdata.idx     61     244    1289
mnames.idx   1000    1000    7677
street.idx     60     127     693
```

名前は1000パターンくらい用意されてるっぽい。意外と被り出そうである

## おわりに
Unix コマンドといえば文字列操作！と思ってもちょうど良いデータがない人は、このように擬似的なデータを使って試してみたらいいのかなと思いました。

