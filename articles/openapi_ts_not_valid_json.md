# openapi-typescript で is not valid JSON のエラー

この記事では、[openapi-typescript](https://github.com/openapi-ts/openapi-typescript) を使って TypeScript クライアントを生成した際に遭遇した「Uncaught (in promise) SyntaxError: Unexpected token "xxx"... is not valid JSON」エラーと、その解決方法について紹介します。

## 対象コード

**openapi**

``` yml
paths:
  /download:
    post:
      operationId: downloadSomething
      responses:
        '200':
          description: 企業情報の一覧を CSV 形式で返す。
          content:
            text/csv:
              schema:
                type: string
                format: binary
```

**生成コード**

``` ts
export interface components {
  ...
  downloadSomething: {
    responses: {
      200: {
        content: {
          "text/csv": string;
        };
      };
    };
  };
```

**リクエスト方法**

``` ts
const { data, error } = await client.POST('/download', {})
```

## 修正方法

以下のように [fetchOption の parseAs](https://openapi-ts.dev/openapi-fetch/api#fetch-options) をつけると解決します。

``` ts
const { data, error } = await client.POST('/download', {
  parseAs: 'text',
})
```

どうやら、json 以外のレスポンスに対しては明示的に parse 方法を指定する必要があるらしいです。

## おわりに

生成コードに content: "text/csv" ってあるんだから、それを元に解釈してほしい。。。
