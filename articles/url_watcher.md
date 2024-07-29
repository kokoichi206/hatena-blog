# HTML の更新を検知する action を作りました [GitHub Actions]

URL を監視し、HTML の内容に更新を検知する Github action を作成しました。Github のリポジトリに最新の情報を保存し、実行時にはそのファイルと比較を行うことで更新を検知する仕組みです。

[Marketplace にも公開してます](https://github.com/marketplace/actions/url-wathcer)ので、よろしければご覧ください（[Github へのリンク](https://github.com/kokoichi206/action-URL-watcher)）。

## なにができるか

もう少し具体的に何ができるか説明します。

- 監視する URL の指定
  - curl で引っ張ってきてます
- 監視対象から除外するパターン
  - sed で正規表現を使って除外してます
- ファイルの保存先フォルダ名の指定
- ファイル名の指定

### 『監視対象から除外するパターン』を作成した経緯

静的ファイルなどで古い情報を読み込ませないようにするため、クエリパラメータにアクセス時の日時を入れるような設計があるようです。

具体的には以下のような URL を観測しました。

```html
<link href="https://example.com/style.css?20220720-1408" />
```

ここの `style.css?` 以下の文字列がアクセス日時毎に異なるため、毎回差分検知してしまい意図した挙動になりません。そこで、sed を用いることで無理やり対象ファイルから削除をおこなっています。

### 補足説明

- 『Github のリポジトリに最新の情報を保存する』のは bot に行わせてます
- 更新検知後に各 SNS 等で通知を行えるよう、output としてフラグを出力しています

## どのように作ったか

Github actions にカスタムアクションを作成する方法として、次の[3 つがあります](https://docs.github.com/ja/actions/creating-actions/about-custom-actions)。

- Docker
- JavaScript
- Compose（いくつかの workflow の step を組み合わせて作成）

今回は既に他のワークフローの中に骨組みを作成済みだったことから、Compose の方法で作成しました。

チュートリアルとしては[公式](https://docs.github.com/ja/actions/creating-actions/creating-a-composite-action)のものに沿っていけばできます。

## 使用例

2 つ目の step の『Diff check』が今回作成したアクションで、そこでの結果により更新があれば slack への通知をおこなっています。

```yaml
name: url_watcher

on:
  workflow_dispatch:
  schedule:
    # 日本時間23時00分に定期実行
    - cron: "0 14 * * *"

jobs:
  checker:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Diff check
        id: diff-check
        uses: kokoichi206/action-URL-watcher@v0.1.0-alpha
        with:
          # 変更を監視したい URL
          url: https://example.com/
          # 変更監視から除外したい正規表現（; 区切りで複数指定可）
          excluded-patterns: 'style.min.css\?[0-9]*-[0-9]*;common.js\?[0-9]*-[0-9]*'
          save-dir: ./url_watcher
          save-file: index.txt

      - name: Notify if diff found
        if: ${{ steps.diff-check.outputs.diff }}
        run: |
          # Slack API を使って通知
          ## see: https://api.slack.com/methods/chat.postMessage
          curl -X POST 'https://slack.com/api/chat.postMessage' \
            -d "token=${{ secrets.SLACK_API_TOKEN_HACKATHON }}" \
            -d 'channel=#times_john_doe' \
            -d 'text=HPの更新を検知しました。'
```

## おわりに

はじめて github action を marketplace に公開してみました。結構学ぶことが多かったので、作成手順も次回まとめてみようと思います。  
また、今度は JavaScript や Docker を使った方法でも独自アクションを作成してみたいです。
