# ワンライナーでid のかぶりがないかチェック
id というのはユニークである必要がありますが、自分で命名してると下手し被ってしまうことがあると思います。

そこで今回は、HTML をユースケースとして、id に被りがないかをチェックするワンライナーを書いてみました



## HTML を確認する
今回考えたい HTML として、以下のように被りのある test.html を用意しました。

```sh
$ cat text.html
<html>
  <div class="container">
    <div id="hoge">
      <div id="pien">
        <img src="" alt="" id="img">
      </div>
    </div>
    <p id="hoge"></p>
  </div>
</html>
```

## id を取ってくる
一致する部分をとってくるには、grep を用います

```sh
$ cat test.html | grep id
    <div id="hoge">
      <div id="pien">
        <img src="" alt="" id="img">
    <p id="hoge"></p>
```

ただこのままだと、p タグと div タグの違いを区別できないので、id="<something\>"に絞って、一致部分を広げてみます。

今回の例では、必ず

- id名はダブルクォーテーションで括る
- id=と""の間はスペースを入れない

と書かれることを想定しています。

```sh
$ cat test.html | grep 'id="[^"]*"'
```

### 一致部分のみ取り出す
ただ今のままでは１行丸々取り出してきてしまって比較しにくいので、一致部分<span style="color:red">のみ</span>を取り出してくるように変更します。

そのためには、-o オプションを使います。

```sh
$ cat test.html | grep -o 'id="[^"]*"'
id="hoge"
id="pien"
id="img"
id="hoge"
```

余談ですが、`grep -o`を用いて１文字ずつ出力するシェル芸として次のようなものがあります

```sh
# . で全ての文字列にヒットされる
$ cat test.html | grep -o .
<
h
t
m
l
>
```

## 被りがどうなるかチェックする
被りチェックなので`uniq`を使いたいところですが、`uniq`を使うときには必ず`sort`を挟みます（暗記）

```sh
# sort を挟まない場合
$ cat test.html | grep -o 'id="[^"]*"' | uniq
id="hoge"
id="pien"
id="img"
id="hoge"

# sort を挟むと
$ cat test.html | grep -o 'id="[^"]*"' | sort | uniq
id="hoge"
id="img"
id="pien"
```

さらに、「被りのある行」のみを取り出したいために -d オプションをもちいます。

```sh
$ cat test.html | grep -o 'id="[^"]*"' | sort | uniq -d
id="hoge"
```

## おわりに
