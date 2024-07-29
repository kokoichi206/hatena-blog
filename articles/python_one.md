# どうしても python をワンライナーで使いたい
ここでいうワンライナーとは、

>python ファイルを作ることなく、ターミナルの上でちゃちゃっと python のいいところを使っちゃおうよ

って話です。

## -c コマンド
どうやら調べてみると、-c オプションをつけることでワンライナーを実行できるようです。

少し調べてみましょう。

```sh
$ man python
...
 -c command
  Specify the command to execute (see next section).  
  This terminates the option list (following
  options are passed as arguments to the command).
...
```

### 使い方
`python -c` の後に続いて、シングルクォーテーションかダブルクォーテーションで実行したいコマンドを囲みます。

```sh
# python のバージョンを表示する
$ python3 -c 'import sys; print(sys.version)'
3.8.10 (default, Jun  2 2021, 10:49:15) 
[GCC 9.4.0]

$ python3 -c "import sys; print(sys.version)"
3.8.10 (default, Jun  2 2021, 10:49:15) 
[GCC 9.4.0]
```

複数行分のpythonのコードを書きたい時は、`;`で区切ってあげます

```sh
# 予約語一覧を表示する
$ python -c 'import keyword; print(keyword.kwlist)'
['False', 'None', 'True', 'and'...
```

## Tips

### 引数の渡し方
普通の python ファイルを実行するときと同じように、実行の引数として渡してあげます。

```sh
$ python -c 'import sys; print(sys.argv)' 1 2 3
['-c', '1', '2', '3']
```

どうやら -c オプションも`sys.argv`には含まれてしまうようなので、実際は配列の2番目から使うことになると思います。

```sh
$ python -c 'import sys; sum=0;[print(i) for i in sys.argv[1:]]' 1 2 3
1
2
3
```

### for 文について
python はインデントで物事を判断しています。

ところが今回は、無理矢理ワンライナーで書いて行の間を`;`で区切るという方法をとっています。そのため、何が正解になるのか想像がつかず、自分の方で色々と試したので記録しておきます。

```sh
# これが正解！（; がいらない）
$ python -c 'for i in range(4):print(i)'
0
1
2
3
# こんな書き方も使えます
$ python -c '[print(i) for i in range(4)];'

# 上手くいかなかったものたち
$ python -c 'for i in range(4):;print(i)'
$ python -c 'for i in range(4):;    print(i)'
$ python -c 'for i in range(4):;\tprint(i)'
```

どうやら`:`がうまく改行の判定扱いになるから、`;`はいらないってことなんですね！（さらにインデントも不要）

[疑問(解決できなかったこと)]

- for 文をやめることができませんでした

```sh
$ python -c 'for i in range(4):print(i);print(i);'
0
0
1
1
2
2
3
3
```

- python の2行目以降に for 文を挟むことができませんでした
  - これについては、[] の中で無理矢理 for 文を使うことで、多少対応できるのではないかと思ってます。

```sh
$ python -c "import sys;\for i in len(sys.argv[]): print(i)" 1 2 3
  File "<string>", line 1
    import sys;\for i in len(sys.argv[]): print(sys.argv[i])
                                                 ^
SyntaxError: unexpected character after line continuation character

# こうする
$ python -c 'import sys; sum=0;[print(i) for i in sys.argv[1:]]' 1 2 3
```

## おわりに
多少の無理矢理感はありますが、数行であれば python を使えないことはないです。

標準 Linux コマンドなどでは難しい部分をうまく python で代用できるようになるといいですね！
