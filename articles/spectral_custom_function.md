# spectral で OpenAPI の required フィールドを検証するカスタム関数を作成する

[spectral](https://github.com/stoplightio/spectral) は OpenAPI、AsyncAPI、JSON Schema などの API ドキュメントを検証するためのツールです。

今回は spectral を使用して OpenAPI の required フィールドを検証するカスタム関数を作成する方法について解説します。

**【今回防ぎたいケース】**

``` yml
components:
  schemas:
    Me:
      type: object
      required:
        ...
        # typo により properties に存在しないフィールドが指定されてしまっている。
        #
        # build-in rulesets を extends した
        # 『['spectral:oas', 'spectral:asyncapi', 'spectral:arazzo']』
        # では防げない。
        - bithday
      properties:
        ...
        birthday:
          type: string
          format: date
          description: 誕生日。
```

**[目次]**

* [環境](#環境)
* [custom functions の作成方法](#custom-functions-の作成方法)
  * [作成が必要なファイルの全貌](#作成が必要なファイルの全貌)
  * [.spectral.yaml](#.spectral.yaml)
  * [`validateRequiredProperties.js`](#`validaterequiredproperties.js`)
* [Links](#links)

## 環境

本記事の内容は spectral v6 系での動作を想定しています。

``` sh
# 動作確認した 2024/10/13 時点での spectral のバージョン。
$ npx @stoplight/spectral-cli --version
6.13.1
```

<!-- more -->

## custom functions の作成方法

spectral では、[カスタム関数を作成して独自の検証が可能](https://docs.stoplight.io/docs/spectral/a781e290eb9f9-custom-functions)です。

今回は『**OpenAPI で required フィールドに記載があるが、properties にその値が存在しない**』というケースを検証をする関数を作成してみます。

### 作成が必要なファイルの全貌

プロジェクトのルートディレクトリに spectral-functions フォルダを作成し、その中に validateRequiredProperties.js ファイルを作成します。

```
.
├── .spectral.yaml
├── examples
│   └── get-me.json
├── openapi.yml
└── spectral-functions
    └── validateRequiredProperties.js
```

各ファイル、それぞれ以下のような内容を記載しています。

**.spectral.yaml**

``` yml
---
# Custom ruleset for the Spectral linter.
#
# ref: https://meta.stoplight.io/docs/spectral/01baf06bdd05a-create-a-ruleset
extends: ['spectral:oas', 'spectral:asyncapi', 'spectral:arazzo']
# ref: ./spectral-functions/
functions: [validateRequiredProperties]
functionsDir: './spectral-functions'
rules:
  invalid-required-field:
    description: 'Required fields must exist in the properties.'
    message: "The required field '{{value}}' does not exist in the properties."
    severity: error
    given: '$.components.schemas.*'
    then:
      function: 'validateRequiredProperties'
```

**examples/get-me.json**

``` json
{
  "name": "Test User",
  "mail": "l.user@example.com",
  "birthday": "2000-01-01"
}
```

**openapi.yml**

``` yml
openapi: 3.0.0

info:
  version: 0.1.0
  title: sample API
  description: sample
  contact:
    name: sample team
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
      description: ログインユーザーの情報を取得する。
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
        - name
        - mail
        - birthday
      properties:
        name:
          type: string
          description: ユーザー名。
        mail:
          type: string
          description: メールアドレス。
        birthday:
          type: string
          format: date
          description: 誕生日。
```

**spectral-functions/validateRequiredProperties.js**

``` js
export default (input, opts, context) => {
  const { required, properties } = input;

  if (!required || !properties) {
    return;
  }

  const propertyNames = Object.keys(properties);
  const results = [];

  required.forEach((prop, index) => {
    if (!propertyNames.includes(prop)) {
      results.push({
        message: `The required field '${prop}' does not exist in the properties.`,
        path: [...context.path, 'required', index],
      });
    }
  });

  return results;
};
```

### .spectral.yaml

`.spectral.yaml` は spectral に関する設定を管理するためのファイルで、今回は `functions`, `functionsDir`, `rules` の 3 つを変更しました。

### `validateRequiredProperties.js` の実装

カスタム関数は[『input, options, context』の3つの引数を取ります](https://docs.stoplight.io/docs/spectral/a781e290eb9f9-custom-functions#writing-functions)。

ドキュメントに思ったより情報が書いてあったのと, console.log で出力を確かめながら実装できるため、ここでの説明は割愛します。

## Links

- [docs: Custom Functions](https://docs.stoplight.io/docs/spectral/a781e290eb9f9-custom-functions)
