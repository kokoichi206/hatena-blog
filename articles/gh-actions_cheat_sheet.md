# GitHub Actions 個人用チートシート

[GitHub Actions ハロワ](https://koko206.hatenablog.com/entry/2022/10/22/121642)の記事も書いているので、よかったらご覧ください。

基本的にはドキュメントがしっかりしているのでそちらで足りるかと思うのですが、個人的に何度も調べてるものはこちらにまとめておきます。

**[目次]**

- [トリガー](#%E3%83%88%E3%83%AA%E3%82%AC%E3%83%BC)
  - [手動実行できるようにする](#%E6%89%8B%E5%8B%95%E5%AE%9F%E8%A1%8C%E3%81%A7%E3%81%8D%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%99%E3%82%8B)
  - [定期実行](#%E5%AE%9A%E6%9C%9F%E5%AE%9F%E8%A1%8C)
  - [特定のパス/拡張子の時は実行させない](#%E7%89%B9%E5%AE%9A%E3%81%AE%E3%83%91%E3%82%B9%E6%8B%A1%E5%BC%B5%E5%AD%90%E3%81%AE%E6%99%82%E3%81%AF%E5%AE%9F%E8%A1%8C%E3%81%95%E3%81%9B%E3%81%AA%E3%81%84)
- [複数条件実行](#%E8%A4%87%E6%95%B0%E6%9D%A1%E4%BB%B6%E5%AE%9F%E8%A1%8C)
  - [複数バージョンで走らせる](#%E8%A4%87%E6%95%B0%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3%E3%81%A7%E8%B5%B0%E3%82%89%E3%81%9B%E3%82%8B)
  - [複数マシン（OS）で走らせる](#%E8%A4%87%E6%95%B0%E3%83%9E%E3%82%B7%E3%83%B3os%E3%81%A7%E8%B5%B0%E3%82%89%E3%81%9B%E3%82%8B)
- [CI ファイルを分割する](#ci-%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E5%88%86%E5%89%B2%E3%81%99%E3%82%8B)
  - [reusable 側（呼び出される側）](#reusable-%E5%81%B4%E5%91%BC%E3%81%B3%E5%87%BA%E3%81%95%E3%82%8C%E3%82%8B%E5%81%B4)
  - [使う側（呼び出す側）](#%E4%BD%BF%E3%81%86%E5%81%B4%E5%91%BC%E3%81%B3%E5%87%BA%E3%81%99%E5%81%B4)
- [そのほか](#%E3%81%9D%E3%81%AE%E3%81%BB%E3%81%8B)
  - [job の実行順序を制御](#job-%E3%81%AE%E5%AE%9F%E8%A1%8C%E9%A0%86%E5%BA%8F%E3%82%92%E5%88%B6%E5%BE%A1)
  - [step 間で値を共有する [非推奨]](#step-%E9%96%93%E3%81%A7%E5%80%A4%E3%82%92%E5%85%B1%E6%9C%89%E3%81%99%E3%82%8B-%E9%9D%9E%E6%8E%A8%E5%A5%A8)
  - [step や job の間で値を共有する](#step-%E3%82%84-job-%E3%81%AE%E9%96%93%E3%81%A7%E5%80%A4%E3%82%92%E5%85%B1%E6%9C%89%E3%81%99%E3%82%8B)
- [おわりに](#%E3%81%8A%E3%82%8F%E3%82%8A%E3%81%AB)

**注: 以下は 2022/10/22 現在の情報となります。**  
うまくいかない場合は、[公式のドキュメント](https://docs.github.com/ja/actions)をご覧ください。

## トリガー

何を契機に jobs を走らせるかを指定します。  
（[Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)）

### 手動実行できるようにする

`on` に `workflow_dispatch:` を追加する。

```yml
on:
  # 手動実行できるようにする！
  workflow_dispatch:
```

### 定期実行

スケジュール実行（定期実行）を行う方法について。  
[（schedule について）](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)

`on` に `schedule:` を追加する。  
デフォルトでは UTC なので注意（日本は UTC+9）。

また、正確な時間ではないのでその辺許してあげてください。  
（そのため、12 時ぴったりに処理が走らないと困る、という場合には適してないです。）

```yml
on:
  schedule:
    # 日本時間23時00分ごろの指定
    # 毎日 23 時 17-20 分ごろに
    - cron: "0 14 * * *"
```

### 特定のパス/拡張子の時は実行させない

[マッチパターンの意味](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#patterns-to-match-file-paths)。

```yml
on:
  pull_request:
    paths-ignore:
      # docs フォルダ配下の、全ファイル。
      - "docs/**"
      # 全ディレクトリの md ファイル。
      - "**.md"
```

## 複数条件実行

基本的には [matrix](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs) をうまく使います。

### 複数バージョンで走らせる

```yml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        go: ["1.16", "1.18"]
    steps:
      - name: Setup go
        uses: actions/setup-go@v3
        with:
          go-version: ${{ matrix.go }}
      - name: checkout
        uses: actions/checkout@v3
      - name: Testing
        run: go test ./...
```

### 複数マシン（OS）で走らせる

`runs-on` に指定します

```yml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os:
          - ubuntu-latest
          - macOS-latest
          - windows-latest
    steps: ...
```

## CI ファイルを分割する

jobs 部分が長くなってくると、各ステップでやってることが把握しにくくなり、保守性が下がってくるという問題が発生します。

そういう時は、ファイルを分割しメインファイルから呼んであげることができます。  
また、他リポジトリにあるファイルも呼び出せるため、使い回しが可能になります。

[reusable-workflows](https://docs.github.com/ja/actions/using-workflows/reusing-workflows) を使います。

### reusable 側（呼び出される側）

呼び出し条件 (`on:`) を `workflow_call` で定義します。

```yml
name: Local test

on:
  workflow_call:
    secrets:
      ENCODED_RELEASE_KEYSTORE:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-20.04
    timeout-minutes: 10

    environment: production
    steps:
      - ...
```

### 使う側（呼び出す側）

marketplace から job を使うように `uses` で使用できます。

```yml
jobs:
  call-workflow-passing-data:
    uses: octo-org/example-repo/.github/workflows/reusable-workflow.yml@main
    with:
      username: mona
    secrets:
      envPAT: ${{ secrets.envPAT }}
```

## そのほか

### job の実行順序を制御

基本的には job は並列で進んでいくのですが、『リントやビルドが通った場合のみ単体テストを走らせたい』など、順番を調整したい場合があります。

そんな時は `need` を使います。

```yml
jobs:
  build:
    uses: kokoichi206/xxx

  lint:
    uses: kokoichi206/yyy

  local-test:
    # この job を走らせるには、build, lint の終了が必要
    needs: [build, lint]
    uses: kokoichi206/zzz

  android-emulator-test:
    # この job を走らせるには、build, lint の終了が必要
    needs: [version-check, build, lint]
    uses: kokoichi206/xyz
```

### step 間で値を共有する [非推奨]

**注**: `set-output` は[非推奨になったようです！！](https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/)

```yml
jobs:
  checker:
    runs-on: ubuntu-20.04
    steps:
      - name: Get version of BASE_REF
        id: id-version
        run: |
          echo "::set-output name=version::1.0.0"
      - name: Get version of HEAD_REF
        run: |
          base="${{ steps.id-version.outputs.version }}"
          echo "${base}"
```

### step や job の間で値を共有する

上の方法は 2022/10/18 に非推奨になっているので、今後は『[Passing values between steps and jobs in a workflow](https://docs.github.com/en/actions/learn-github-actions/environment-variables#passing-values-between-steps-and-jobs-in-a-workflow)』に従って値を共有することになります。

**step 間**  
（[実行例](https://github.com/kokoichi206-sandbox/GitHub-Actions-Demo/actions/runs/3303784342/jobs/5452124112)）

```yml
steps:
  - name: Set the value
    run: |
      echo "test_value=pien" >> $GITHUB_ENV

  - name: Use the value
    run: |
      # This will output 'pien'
      echo "${{ env.test_value }}"
```

**job 間**  
（[実行例](https://github.com/kokoichi206-sandbox/GitHub-Actions-Demo/actions/runs/3303784342/jobs/5452124834)）

```yml
jobs:
  # outputs で共有
  Between-jobs-1:
    runs-on: ubuntu-latest
    # Map a step output to a job output
    outputs:
      output1: ${{ steps.step1.outputs.test_value }}
    steps:
      - id: step1
        run: |
          echo "test_value=hello" >> $GITHUB_OUTPUT
  Between-jobs-2:
    runs-on: ubuntu-latest
    needs: job1
    steps:
      - run: echo ${{needs.Between-jobs-1.outputs.output1}}
```

## おわりに

随時便利そうなものがあれば追加します。
