# spectral を用いて openapi の lint をかける

## 課題感

これまで、openapi を用いてサーバーとクライアントのコードを生成することをしてきました。
また、開発時には [prism](https://github.com/stoplightio/prism) で mock サーバーを立て、フロントを繋いで確認することもしてきました。

prism は、定義した example からいい感じのレスポンスを返す mock サーバーなのですが、この際に『**openapi で厳密に定義したスキーマ情報と example の型情報がずれたままフロントの開発を進めてしまう**』という問題が発生しました。
サーバーとクライアントのどちらも openapi から生成されたものを使っていれば被害は少ないですが、これでは厳密に型を決めた意味が半減してしまいます。

そこで今回、**example と openapi 定義の仕様のずれを防ぐことを目的に**、openapi に対して lint をかけてみました。

<!-- more -->

## 具体例

openapi に lint をかけられるツールとしては複数候補がありますが、openapi 専用の linter としては star が多く**開発頻度も高い**こと、またお世話になっている **prism と同じ organization がメンテしている**ということで [spectral](https://github.com/stoplightio/spectral) を選びました。

今回、例として以下のようなフォルダ構成を考えます。

``` sh
├── examples
│   └── get-me.json
├── .spectral.yml
└── openapi.yml
```

各ファイルの内容は以下の通りです。

**openapi.yml**

``` yml
openapi: 3.0.0

info:
  version: 0.1.0
  title: Sample API
  description: sample api
  contact:
    name: Sampler
    email: sample@example.com
    url: https://example.com

servers:
  - url: 'http://localhost:8080'
    description: 開発環境

tags:
  - name: User
    description: ユーザー情報に関するエンドポイント。

paths:
  /me:
    get:
      summary: ユーザー情報取得
      operationId: getMe
      description: |
        ログインユーザーの情報を取得する。
      tags:
        - User
      responses:
        '200':
          description: ユーザー情報を返す。
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Me'
              example:
                $ref: './examples/get-me.json'

components:
  schemas:
    Me:
      type: object
      required:
        - id
        - name
        - mail
      properties:
        id:
          type: string
          description: ユーザー ID。
        name:
          type: string
          description: ユーザー名。
        mail:
          type: string
          description: メールアドレス。
```

**.spectral.yml**

``` sh
extends: "spectral:oas"
rules:
  example-property-required:
    description: "Required properties must be present in examples"
    message: "{{property}} is a required property and must be present in the example."
    given: "$..[?(@.examples)]"
    severity: error
    then:
      function: schema
      functionOptions:
        schema:
          type: object
          properties:
            examples:
              type: object
          additionalProperties: true
          required: 
            - examples
```

**examples/get-me.json**

``` json
{
  "id": "3",
  "name": "John Doe",
  "mail": "john@example.com"
}
```

### spectral 実行

いろんな方法がありますが、自分は以下のように実行しています。

``` sh
$ npx @stoplight/spectral-cli lint openapi.yml
No results with a severity of 'error' found!

# あえてバージョン固定はしてませんが、本記事の動作 6.11.1 で確認しています。
$ npx @stoplight/spectral-cli --version
6.11.1
```

### lint で弾かれることを確認する

今回 openapi の定義的には id, name, mail のいずれも required であることに注意し、example を以下のように変更してみます。

``` json
{
  "id": "3",
  "mail": "john@example.com"
}
```

実行すると、期待通りエラーを吐くことが分かります。

``` sh
$ npx @stoplight/spectral-cli lint openapi.yml

/Users/takahirotominaga/ghq/github.com/kokoichi206/hatena-blog/examples/get-me.json
 1:1  error  oas3-valid-media-example  "example" property must have required property "name"

✖ 1 problem (1 error, 0 warnings, 0 infos, 0 hints)
```

続いて id の型を string から integer に変えてみます。

``` json
{
  "id": 3,
  "name": "John Doe",
  "mail": "john@example.com"
}
```

こちらも期待値通りエラーを吐いてくれました！

``` sh
$ npx @stoplight/spectral-cli lint openapi.yml

/Users/takahirotominaga/ghq/github.com/kokoichi206/hatena-blog/examples/get-me.json
 2:9  error  oas3-valid-media-example  "id" property type must be string  id

✖ 1 problem (1 error, 0 warnings, 0 infos, 0 hints)
```

## まとめ

spectral は example だけではなく、type, description を ref 側につけないなど、細かいルールも強制させることが可能で、いい感じだなと感じました。
