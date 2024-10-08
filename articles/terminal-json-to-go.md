# terminal で json を Go の構造体に変換する (json-to-go)

[JSON-to-Go](https://mholt.github.io/json-to-go/) という『具体的な JSON から Go の構造体を生成してくれるサイト』があることは知っており長年使っていたのですが、以下のようなめんどくささを感じていました。

- 具体的な値を変更して Web サイトに突っ込むのがめんどい
  - 業務で使ってる内容をそのまま Web に貼るのはちょっとリスクがあるため、
- 開発中の response などを突っ込むことが多いため、都度ブラウザに移るのがめんどい

そんな中、[ソースコードが GitHub に公開されてる](https://github.com/mholt/json-to-go)ことを知ったので、ローカルで変換できるようにしてみた、というのが今回の記事になります。  
（JSON-to-Go は Go で作られてて欲しかった。。。）

## Setup

自分なりのセットアップ方法です。  
他に良さそうな方法があれば教えてください。

``` sh
git clone git@github.com:mholt/json-to-go.git /usr/local/json-to-go

# ~/.zshrc に記載。
jtg () {
        node /usr/local/json-to-go/json-to-go.js
}
```

## 使い方

サンプルとしてこんな感じのデータを入れてみます。

``` json
{
    "date": "2014-01-21T11:19:50.000-07:00",
    "author": {
        "displayName": "kokoichi206",
        "path": "kokoichi206"
    },
    "isSpoofed": false
}
```

適当な内容をパイプで標準入力から渡してやる。

``` sh
$ echo '{"date": "2014-01-21T11:19:50.000-07:00","author": {"displayName": "kokoichi206","path": "kokoichi206"},"isSpoofed": false}' | jtg

type AutoGenerated struct {
        Date string `json:"date"`
        Author Author `json:"author"`
        IsSpoofed bool `json:"isSpoofed"`
}
type Author struct {
        DisplayName string `json:"displayName"`
        Path string `json:"path"`
}
```

mac だったらこんな感じの登録をしてても便利そうです。

``` sh
# クリップボードにコピーした内容（JSON）を構造体変換し、再度クリップボードにコピーする。
jtgc () {
        pbpaste | jtg | pbcopy
}
```

生産性爆上げていきたい。
