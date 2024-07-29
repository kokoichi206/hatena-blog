# GitHub Actions でコミットできない時見直したい設定

## はじめに

これらは 2023/1/16 現在の情報であり、GitHub の仕様変更によって将来変更を受ける可能性があります。

## どんなエラーが出るか

権限不足でコミット等できなかった場合は、以下のようなエラーコードが表示されます（例）。
`Invalid status code` など、権限不足であることがぱっと見分かりにくい場合もあります。

```sh
Error: git push Invalid status code: 128
```

## 設定の変更方法

1. repository の Settings > Actions > General のところに移動
2. Workflow permissions の設定値を『Read and write permissions』に変更する

![](img/gh_action_permission.png)

サードパーティの GitHub Actions 等を使う場合は、しっかり内容を検討した上で許可するようにお願いします。

### 例

github-profile-summary-cards という GitHub Actions では、使用する Access Token に必要な[権限については詳しく書いてくれている](https://github.com/vn7n24fzkq/github-profile-summary-cards/wiki/Personal-access-token-permissions)のですが、上記の設定ができていなかったために利用できないケースがありました。

## おわりに

権限周りは慎重にいろんなところで細かく設定できるようにしてくれている分、詰まった時にどこが原因か分かりにくいと感じています。  
問題が発生しないよう丁寧に GitHub Actions を使っていきたですね。
