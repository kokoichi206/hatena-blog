## SWR を使った SPA での prefetch 機能の実装

React で開発してた SPA のアプリにおいて、[SWR](https://swr.vercel.app/ja) を活用して prefetch 機能を実装したので、その内容をメモしておきます。

## 背景

よくあるアプリと同様、一覧画面と詳細画面を持つアプリを開発していました。  
しかし、詳細画面の表示に時間がかかり、ユーザー体験が悪化している状態でした。  
OpenSearch や RDB の複数のテーブルにアクセスする必要があるため、アプリ側での改善にも限界がありました。

そこで、一覧画面から詳細画面への遷移時に、**事前にデータを取得しておく**「prefetch」機能を導入しました。  
この方法により詳細画面に遷移した瞬間にデータを即座に表示できるようになり、ユーザー体験が大幅に向上しました。

## 環境

``` sh
react: 18.3.1
swr: 2.2.5

# api の呼び出しに openapi-ts のライブラリを使っています。
openapi-typescript: 6.7.6
```

## 実装例

今回 API の呼び出しは `openapi-typescript` を使っていますが、紹介する方法は API 呼び出し方法に依らないものとなっています。

### API データの prefetch

SWR の mutate 関数を用いてキャッシュを更新・作成する方法を取りました。  
（以下の方法は、その中でも[バウンドミューテート](https://swr.vercel.app/ja/docs/mutation#bound-mutate)になります。）

``` ts
import type { Client } from 'openapi-fetch'
import useSWR, { mutate } from 'swr'
import type { paths } from '@/lib/api/gen/v1'

// 一定期間の間に同じリクエストを複数回送信しないようにするためのタイムスタンプ。
const requestTimestamps: Record<string, number> = {}

const userDetailKey = (userId: string) => {
  return `/users/${userId}`
}

export const prefetchUserDetail = async (
  client: Client<paths, `${string}/${string}`>,
  userId: string,
) => {
  const currentTime = Date.now()
  const lastRequestTime = requestTimestamps[userId] || 0

  // 前回のリクエストから一定期間経過していない場合、リクエストをスキップする。
  if (currentTime - lastRequestTime < 3600_000) {
    return
  }

  requestTimestamps[userId] = currentTime

  try {
    const response = await client.GET('/users/{userId}', {
      params: { path: { userId } },
    })

    mutate(
      userDetailKey(userId),
      // useSWR のコールバック関数の返り値と同じ形式でデータを保存する。
      { data: response.data, error: response.error },
      false,
    )
  } catch (error) {
    console.error('Error prefetching user details:', error)
  }
}
```

その他のコードも含まれていますが、特に重要なポイントは以下の 2 点です。

- 第一引数 = **キャッシュとして保存するキーを一意に**する
- 後々 useSWR で取り出す**コールバック関数の戻り値と同じ形式でデータを保存**する

### 実際のデータ取得

データの取得は最もベースとなる useSWR を用いて行いました。

mutate 側とキャッシュのキーを合わせるために `userDetailKey` という関数にキーの作成を切り出しています。

``` ts
export const useUserDetail = (
  client: Client<paths, `${string}/${string}`>,
  userId: string,
) => {
  const { data, error } = useSWR(
    userDetailKey(userId),
    async () => {
      const response = await client.GET('/users/{userId}', {
        params: { path: { userId } },
      })
      return { data: response.data, error: response.error }
    },
    {
      revalidateOnFocus: false,
      revalidateOnReconnect: false,
      revalidateOnMount: false,
    },
  )

  return { data, error }
}
```

### SWR と React (Next) コンポーネントの連携

一覧画面で、Link コンポーネントに対してホバー時に prefetch するように設定しました。

``` ts
<Link
  href={`/users/${user.id}`}
  style={style}
  onMouseOver={() => {
    prefetchUserDetail(user.id)
  }}
>
  {user.name}
</Link>
```

詳細画面のコンポーネントにおいては、以下のように hook を呼び出すだけです。

hook として設定されているので、キャッシュがなくて API 呼び出しが走った場合なども、取得が完了し次第勝手に反映されます。

``` ts
// 今回は openapi-ts の client も渡している。
const { data: detail } = useUserDetail(client, userId)
```

## おわりに

SWR を用いて、SPA アプリのパフォーマンス・ユーザー体験を向上させることができました。  
特に、事前にデータを取得する prefetch 機能によって、詳細画面の表示速度が改善し、ユーザーがスムーズに操作できるようになりました。

ただし、今回の実装には注意点もあります。  
たとえば、ユーザーの操作次第では、サーバーへの負荷が増加する可能性があり、その場合、キャッシュの有効期限の見直しや API にリミットをかけるなどの最適化が必要となります。

今後は、サーバーの負荷状況をモニタリングしつつ、この実装が適切に機能しているかを検証していく予定です。
