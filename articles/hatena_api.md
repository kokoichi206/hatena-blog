# はてなブログ API の結果を xml から json へ変換（xq, sed, jq）

はてなブログ API を叩いた時の備忘録と、その際 jq を使ってみたのでそのメモになります。  
レスポンスが xml だったので、xq と sed と jq を使って一歩ずつ理想とする形に近づけました。

## 結論

xq を使って xml を json にしたら**要素が 1 つの時は string, 複数の時は配列**になっており、そこを統一させるのに少し苦労しました。

```sh
curl -u kokoichi206:api_key https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry |\
  xq |\
  sed -z 's@"category": \({\n[^}]*}\)@"category": [\1]@g' |\
  jq '.feed.entry | { entries: (map({ title: .title, url: .link[0]."@href", published: .published, summary: .summary."#text", category: (.category | map(."@term") ) }))}' \
  > output.json
```

## やりたいこと

はてなブログの最新記事 5 つくらいを、自分のポートフォリオかどこか埋め込みたい。

埋め込みがあればそれでもいいし、情報だけもらって自分の方で表示するのでもいい。

## [はてなブログ AtomPub](https://developer.hatena.ne.jp/ja/documents/blog/apis/atom)

`https://blog.hatena.ne.jp/{はてなID}/{ブログID}/atom/entry` を[認証つき](https://developer.hatena.ne.jp/ja/documents/blog/apis/atom/#auth)で叩く。

今回は API キーを使った Basic 認証方式で取得を行いました。 　
（API キーは[アカウント設定](https://blog.hatena.ne.jp/-/config)から取得可能です。）

以下の `api_key` を自身の API キーに置き換える必要があります。

```sh
curl -u kokoichi206:api_key https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry
```

結果が xml で返ってくる為、色々整形して使いやすい json にしてあげてる。

**結果**

```sh
# はてなブログ API を Basic 認証付きでたたく
curl -u kokoichi206:api_key https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry > entry

# xq を使って xml を json に変換する
cat entry | xq > entry_xq

# sed で category の方を string から Array に変換（gsed = GNU sed）
# xml を xq で json に変換した影響、もっと良い方法ありそう。
cat entry_xq | gsed -z 's@"category": \({\n[^}]*}\)@"category": [\1]@g' > entry_xq_

# jq を使ってほしい要素だけ抜き出す
cat entry_xq_ | jq '.feed.entry | { entries: (map({ title: .title, url: .link[0]."@href", published: .published, summary: .summary."#text", category: (.category | map(."@term") ) }))}' > entry_output
```

### jq: 1 compile error

xml を無理やりパースして json にしているため、key の値に `#text`, `@href` などが含まれてしまっている。

これらをそのまま jq の `.` で繋げていくとエラーになるため、`"` で囲ってやる。

```sh
$ echo '{ "#text": "This is a text" }' | jq '. | { title: .#text }'
jq: error: syntax error, unexpected $end, expecting '}' (Unix shell quoting issues?) at <top-level>, line 1:
. | { title: .#text }
jq: 1 compile error

# " をつけてみる
$ echo '{ "#text": "This is a text" }' | jq '. | { title: ."#text" }'
{
  "title": "This is a text"
}
```

### 全件取得したい場合

[一覧取得 API](https://developer.hatena.ne.jp/ja/documents/blog/apis/atom/#%E3%83%96%E3%83%AD%E3%82%B0%E3%82%A8%E3%83%B3%E3%83%88%E3%83%AA%E3%81%AE%E4%B8%80%E8%A6%A7%E5%8F%96%E5%BE%97) では、（デフォルトでは）1 度に 7 件が取得可能らしい。

URL パラメータで page を指定することで、続きのエントリーを取得ができる。

```sh
# page 番号は、1つ前のレスポンスボディに含まれている。
curl -u kokoichi206:api_key https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry | xq | jq '.feed.link[1]."@href"'
> https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry?page=1667486025

# page 番号を指定して次のエントリーを取得。
curl -u kokoichi206:api_key https://blog.hatena.ne.jp/kokoichi206/koko206.hatenablog.com/atom/entry?page=1667486025
```

この値が返ってこなくなるまでループしてあげたらよい。

### jq で外側を配列にする

```sh
# このままだと正しい json の形をしていない
$ cat entry_xq | jq '.feed.entry[] | { category: .category }'
{
  "category": [
    {
      "@term": "Android-jetpack compose"
    },
    {
      "@term": "Android"
    }
  ]
}
{
  "category": {
    "@term": "Android"
  }
}
```

上では entry の各要素 `[]` に対して変換をおこなっていたが、map を使って `entry` 自身に対して返還をしてあげる。

```sh
$ cat entry_xq | jq '.feed.entry | map({ category: .category })'
[
  {
    "category": [
      {
        "@term": "Android"
      },
      {
        "@term": "Android-jetpack compose"
      }
    ]
  },
  {
    "category": {
      "@term": "Android"
    }
  },
  {
  ...
]
```

### category の型が異なる問題

xq で json にパースする際に、`category` が 1 つか複数かによって**返却される型が異なる**（`category` なしは何が返ってくるかも**要確認**）

```sh
$ cat entry_xq | jq '.feed.entry[] | { category: .category }'
{
  "category": [
    {
      "@term": "Android"
    },
    {
      "@term": "Android-jetpack compose"
    }
  ]
}
{
  "category": {
    "@term": "Android"
  }
}
```

これを他の他の型付き言語とかでパースしようと思ったらエラーになりそうな予感（わからん）がするので、json の段階で直しておきたい（`[]` に統一しておきたい）。

sed で置換し、その後は jq で頑張る！

```sh
cat entry_xq_ | jq '.feed.entry | { categories: (map({ category: (.category[] | ."@term" ) }))}'

cat entry_xq_ | jq '.feed.entry | { categories: (map({ category: (.category[] | ."@term" ) }))}'

# gsed = GNU sed
cat entry_xq | gsed -z 's@"category": \({\n[^}]*}\)@"category": [\1]@g' > entry_xq_

cat entry_xq_ | jq '.feed.entry | { categories: (map({ category: (.category | map(."@term") ) }))}'
```

## おわりに

いろんな外部 API 使ってみましたが、過去一ドキュメントが分かりにくかった気がする。
