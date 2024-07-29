# ブログに書くための何か

## 書きたいこと
- android
  - adbを使って、ファイルをandroidに転送する方法
  - カスタムロム（Android11）を焼いた話
  - そこにAndroid10以降の機能を試した話
- linux
  - manコマンドと仲良くなる方法
  - ls(1)とかの数字の意味

## はてなブログ
- tex数式
  - [tex: brabrabra]
    - プレビューでは崩れているけど問題ない！

<div style="text-align: center; position: relative; margin: 2.5em 0 0 0; padding: 0.5em 1em; border: solid 3px #999999;">
<span style="position: absolute; top: -28px; left: -3px; padding: 0 10px; height: 26px; font-weight: bold; color: white; background-color: #999999; border: solid 1px #999999; border-radius: 5px 5px 0 0;">
加法定理</span>[tex:
\sin(α+β)=\sinα\cosβ+\cosα\sinβ
]</div>

- TOC
  - [:contents]

```html
<details><summary>サンプルコード</summary><div>

\```rb
puts 'Hello, World'
\```
</div></details>
```

### 数式ちょっと独特
[tex:
\int V _ {in}(s)e^{st}ds = \frac{1}{RC}\int V _ {out}(s)\left(\int _ {-\infty} ^{t} e ^{st'}dt'\right)ds + \int V _ {out}(s)e ^{st}ds
]


### やりたいこと
- h2以降のみ！の見出しにしたい


## gif ファイルを作る
調べて出てくる gif 生成ツールでは、少し長い動画からは上手くいかない。

そこで、Mac の機能（Keynote）を使って gif を生成する。

1. 動画を Keynote にはる
2. Keynote のノートのサイズを動画の縦横に合わせる
3. 動画の貼られたページを書き出す

### 2.Keynote のノートのサイズを動画の縦横に合わせる
1. 「キーノート内：書類」→ 「スライドのサイズ」から変更
2. （Pixel3 の縦横比は 470 * 900 でちょうどだった）

### 3.動画の貼られたページを書き出す
1. 「ファイル」 → 「書き出す」 → 「アニメーションGif」を選択
2. スライドの範囲選択で、動画を貼ったページだけに絞る
3. 解像度、フレームレートなどを選択し書き出しを行う
