# monorepo における renovate 設定の紹介

Renovate は非常に柔軟な設定が可能なツールですが、リポジトリの規模やチーム構成に応じて、最適な設定は異なることがよくあります。

renovate 導入時、実際に役立つサンプルがあまり見つからなかったため、ここでは私が個人プロジェクトや業務で試した設定例をそのまま紹介します。

## 前提

- 以下のコードが 1 つのリポジトリで管理されている
  - バックエンド
    - Go
  - フロントエンド
    - Next.js
  - インフラ
    - Terraform
  - データまわり
    - Python 等
- 開発者は 2-3 人
- GitHub でコードを管理しており, GitHub Actions で CI/CD は一通り準備している

<!-- more -->

## 設定

``` json5
{
  // see renovate settings: https://developer.mend.io/github/Shodan-Pro
  $schema: 'https://docs.renovatebot.com/renovate-schema.json',
  extends: [
    'config:recommended',
    // https://docs.renovatebot.com/presets-schedule/#scheduleearlymondays
    'schedule:earlyMondays',
    // https://docs.renovatebot.com/presets-default/#enablevulnerabilityalertswithlabelarg0
    ':enableVulnerabilityAlertsWithLabel(security)',
  ],
  rebaseWhen: 'auto',
  reviewers: ['kokoichi206'],
  assignees: ['kokoichi206'],
  labels: ['renovate'],
  packageRules: [
    {
      matchManagers: ['gomod'],
      matchFileNames: ['backend/**'],
      // https://docs.renovatebot.com/configuration-options/#groupname
      groupName: 'go dependencies',
      // https://docs.renovatebot.com/configuration-options/#groupslug
      // branch 名に使われる。
      groupSlug: 'go-mod-updates',
      // global の labels に追加して設定される。
      // https://docs.renovatebot.com/configuration-options/#addlabels
      addLabels: ['backend'],
    },
    {
      matchFileNames: ['infra/terraform/**'],
      groupName: 'terraform dependencies',
      groupSlug: 'terraform-updates',
      addLabels: ['infra'],
      rangeStrategy: 'update-lockfile',
    },
    {
      matchFileNames: ['frontend/**'],
      groupName: 'frontend dependencies',
      groupSlug: 'frontend-updates',
      addLabels: ['front'],
      rangeStrategy: 'pin',
    },
    {
      matchFileNames: ['search-engine/**'],
      groupName: 'search-engine dependencies',
      groupSlug: 'search-engine-updates',
      addLabels: ['search'],
    },
  ],
  postUpdateOptions: ['gomodTidy', 'gomodUpdateImportPaths'],
}
```

### お気に入りポイント

- json5 形式の採用
  - ケツカンマ問題やコメントをどうやって書くかに悩まなくていい
  - [対応しているパス・ファイル名](https://docs.renovatebot.com/configuration-options/)
- security アラートは週 1 の定期実行とは別途起票する
  - 緊急度が高いため
- postUpdateOptions を使う
  - 依存関係の更新後に lock file もアップデートさせる

### 取り入れなかったポイント

- auto merge
  - ci はあるが、そもそもテストが少なく不安だったため
  - ライブラリの変更を自分の目で追いたかったため
- prConcurrentLimit10 等
  - 上限に溜まってるせいで大事な PR が作られない、などを避けたいため
  - 必要に応じて grouping することで PR の乱立を防止

## おわりに

これからも運用を続けてみて、気になった点があれば更新していきます。  
皆さんのおすすめの設定もぜひ教えてください！
