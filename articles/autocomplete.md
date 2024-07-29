# OpenSearch で実現する検索サジェスト機能

## ゴール

Google 検索等では、1文字打つごとに検索候補が表示・更新されます。

![Google 検索画面](./imgs/google-autocomplete.png)

今回はこれと似たような機能を Next.js (MUI) と OpenSearch, Go を用いて実装してみます。

### やること

本体となる検索システムがあると想定し、そこの検索結果を別途 OpenSearch に保持することで『**検索ログの集計・よく検索されてるワードのサジェスト**』を実現します。

### やらないこと

OpenSearch, Next, Go の詳しい説明はしません。また、本体となる検索システム本体の構築も今回のスコープの対象外とします。

## OpenSearch の設定

日本語用の設定を追加した、以下の Dockerfile を用意します。

``` dockerfile
FROM opensearchproject/opensearch:2.13.0
# 日本語の検索をするために必要なプラグインをインストール。
# see: https://opensearch.org/docs/latest/opensearch/plugins/
# see: https://subro.mokuren.ne.jp/0930.html
RUN /usr/share/opensearch/bin/opensearch-plugin install analysis-kuromoji 
RUN /usr/share/opensearch/bin/opensearch-plugin install analysis-icu
```

opensearch 本体を port 9200 番, dashboard を port 5601 番で起動します。

``` yml
version: "3"

services:
  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:2.13.0
    container_name: opensearch-dashboards-c
    environment:
      OPENSEARCH_HOSTS: "https://opensearch-c:9200"
    ports:
      - 5601:5601
    links:
      - opensearch
    networks:
      - opensearch-net

  opensearch:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: opensearch-c
    environment:
      - cluster.name=docker-cluster
      - node.name=os-node
      - cluster.initial_master_nodes=os-node
      - bootstrap.memory_lock=true
      - http.host=0.0.0.0
      - transport.host=127.0.0.1
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=ad.PASS#1
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - opensearch-data:/usr/share/opensearch/data
    ports:
      - 9200:9200
    networks:
      - opensearch-net

volumes:
  opensearch-data:

networks:
  opensearch-net:
```

http://localhost:5601 を開くとログイン画面が表示されるので、以下 Username, Password を入力します。

```
Username: admin
Password: ad.PASS#1
```

![OpenSearch ログイン画面](./imgs/os-login.png)

### Index/Search-template の作成

[dashboard の console](http://localhost:5601/app/dev_tools#/console) 上から[『Elasticsearch の公式ブログ（Elasticsearchで日本語のサジェストの機能を実装する）』](https://www.elastic.co/jp/blog/implementing-japanese-autocomplete-suggestions-in-elasticsearch)を参考に Index と Search Template を作成します。

この先コードを実行するには、[GitHub の console](https://github.com/kokoichi206-sandbox/search-suggestions/blob/main/docs/opensearch/console) の内容を、[local の dashboard console](http://localhost:5601/app/dev_tools#/console) に貼り付けてください。

Index の定義は長いので省略しますが、公式ブログのものから以下項目を [mappings に追加しました](https://github.com/kokoichi206-sandbox/search-suggestions/blob/e9d281d72c4aaf668b9a936dd5b06971d442f5e7/docs/opensearch/console#L389-L397)。

- user_email
  - ユーザー単位でどれくらい利用されてるか・利用状況の時系列変化をみるため
- matched_count
  - 『本体となる検索システム』の index 検索において hit した件数
  - hit しない検索（結果として hit が0件のもの）を候補に表示させないため
- searched_at
  - 『本体となる検索システム』が検索された日時

Index の登録をするために、以下の PUT 部分を実行します。

```
PUT searched-history
...
```

`"acknowledged": true,` と返ってきたら成功です。

### dummy data の投入

手元で試すためにダミーデータを [GitHub に用意した](https://github.com/kokoichi206-sandbox/search-suggestions/blob/e9d281d72c4aaf668b9a936dd5b06971d442f5e7/docs/opensearch/console#L620-L688)ので、以下の bulk insert を実行します。

```
POST _bulk
...
```

本来であれば、**検索されるたびに**、先ほどの `searched-history` インデックスにドキュメントを登録することが必要です。

### ユースケース: suggestion に利用

ここは[公式](https://www.elastic.co/jp/blog/implementing-japanese-autocomplete-suggestions-in-elasticsearch)と全く同じものを使いました。
（長いので省いてもいいかも）

```
GET searched-history/_search 
{ 
  "size": 0,
  "query": { 
    "bool": {
      "must": [
        {
          "range": {
            "matched_count": {
              "gt": 0
            }
          }
        },
        {
          "bool": {
            "should": [ 
              {
                "match": { 
                  "query.suggest": { 
                    "query": "開発"
                  }
                }
              },
              {
                "match": {
                  "query.readingform": {
                    "query": "開発",
                    "fuzziness":"AUTO",
                    "operator": "and"
                  }
                }
              }
            ],
            "minimum_should_match": 1
          }
        }
      ]
    }
  },
  "aggs": {
    "keywords": {
      "terms": {
        "field": "query",
        "order": {
          "_count": "desc"
        },
        "size":"10"
      }
    }
  }
}
```

![『ユースケース: suggestion に利用』の検索結果](./imgs/search-suggest.png)

今回はこれを search-template として登録するために、以下を実行しておきます。

```
POST _scripts/history-search-template
...
```

### ユースケース: 検索ワード別検索結果集計

どのワードが最も多く検索されてるかを集計します。

```
GET searched-history/_search 
{
  "size": 0,
  "aggs": {
    "keywords": {
      "terms": {
        "field": "query",
        "order": {
          "_count": "desc"
        },
        "size":"10"
      }
    }
  }
}
```

### ユースケース: 人・期間（daily）別、検索結果。

以下の例は、ユーザー単位・日毎にどのようなワードが検索されてるかを表示するものです。

```
GET searched-history/_search
{
  "size": 0,
  "aggs": {
    "per_user": {
      "terms": {
        "field": "user_email",
        "size": 10
      },
      "aggs": {
        "per_day": {
          "date_histogram": {
            "field": "searched_at",
            "calendar_interval": "day",
            "order": {
              "_key": "desc"
            }
          },
          "aggs": {
            "top_keywords": {
              "terms": {
                "field": "query",
                "order": {
                  "_count": "desc"
                },
                "size": 10
              }
            }
          }
        }
      }
    }
  }
}
```

![『ユースケース: 人・期間（daily）別、検索結果』の検索結果](./imgs/search-per-user-per-day.png)

### curl で叩く例

後ほど API での実装に備え、curl で叩く例を示しておきます。
（と思ったのですが、search-template を使った検索に切り替えたので直接は使ってません。）

``` sh
curl -X POST -k -v "https://opensearch:9200/searched-history/_search" -u 'admin:ad.PASS#1'  --json '{
  "size": 0,
  "aggs": {
    "keywords": {
      "terms": {
        "field": "query",
        "order": {
          "_count": "desc"
        },
        "size":"10"
      }
    }
  }
}'
```

**注意点**

- dashboard と同じ Username, Password で basic 認証を通している
- opensearch が TLS 必須であり `https://opensearch:9200` をオリジンとしている
  - 自己証明書になってるためそこを許可する（curl だと `-k` option）
  - ローカルで名前解決するため、`/etc/hosts` に `127.0.0.1 opensearch` を追加する

## API の実装

今回はクライアントの実装を楽にするため [opensearch-go](https://github.com/opensearch-project/opensearch-go) を使いました。

Go client の使い方の例は[ライブラリのドキュメント](https://opensearch.org/docs/latest/clients/go)に書いてあるので割愛しますが、先ほど作成した search template を利用して検索しています。

全体のコードは [GitHub](https://github.com/kokoichi206-sandbox/search-suggestions/tree/main/api) をご覧ください。

**個人的な注意点**

- [localhost の https に繋ぐときの設定](https://opensearch.org/docs/latest/clients/go/#connecting-to-opensearch)（curl の -k オプションみたいなやつ）
- ライブラリは v4.0.0 とかリリースされてるが、ドキュメントの例に従って v2.3.0 を使った
- JSON-to-Go とかめっちゃ便利なので使って欲しい
  - データの中身には注意

以下のように curl で叩けることが確認できたら API 構築は終了です。

``` sh
$ curl "http://localhost:8085/auto-complete?query=退" | jq
{
  "suggestions": [
    "退職",
    "退勤",
    "退勤 忘れ",
    "退職 方法",
    "退職金"
  ]
}
```

## Front の実装

今回、サジェストの一覧をいい感じに表示してくれるものとして、[MUI](https://mui.com/) の [Autocomplete](https://mui.com/material-ui/react-autocomplete) を利用しました。

詳細は [GitHub](https://github.com/kokoichi206-sandbox/search-suggestions/blob/main/front/src/app/page.tsx) を見ていただきたいのですが、以下のような作戦を取りました。

- ユーザーからの入力が1つあるたびに API を叩く
  - レスポンス速度とサーバーの負荷次第では debounced なども検討してみるといいかも
- options (Autocomplete の候補一覧) に結果を詰めていく

裏側に本体の検索システムがある場合は、『選択時』or『Enter 押下時』などに検索を発火させると良い気がします。

![実装された検索画面](./imgs/search-ui.png)

UI 部分のコードについては、以下に記載しておきます。

``` jsx
<Autocomplete
  value={value}
  onChange={onChange}
  id="search-with-auto-complete"
  filterOptions={(x) => x}
  options={filteredOptions}
  autoComplete
  includeInputInList
  filterSelectedOptions
  noOptionsText={"候補なし"}
  getOptionLabel={(option: QueryInputOption | string) => {
    if (typeof option === "string") {
      return option;
    }
    return option.label;
  }}
  // console の warning
  // useAutocomplete.js:188 MUI: The value provided to Autocomplete is invalid. None of the options match with `"ta"`
  // を防ぐ。
  // see: https://stackoverflow.com/questions/61947941/material-ui-autocomplete-warning-the-value-provided-to-autocomplete-is-invalid
  freeSolo
  selectOnFocus
  clearOnBlur
  handleHomeEndKeys
  // リストの表示をカスタマイズしたい時。
  renderOption={(props, option) => {
    const label = typeof option === "string" ? option : option.label;
    return (
      <li
        {...props}
        key={label}
        style={{
          ...props.style,
          color: "gray",
        }}
      >
        {label}
      </li>
    );
  }}
  renderInput={(params) => (
    <div ref={params.InputProps.ref}>
      <OutlinedInput
        fullWidth={true}
        rows={1}
        onChange={(event) => {
          onChange(event, event.target.value);
        }}
        startAdornment={
          <InputAdornment position="start">
            <SearchIcon sx={{ fontSize: 20, mt: 0.25, ml: 0.5 }} />
          </InputAdornment>
        }
        inputProps={{
          ...params.inputProps,
        }}
        sx={{
          mt: 1,
          height: 48,
          fontWeight: "normal",
        }}
      />
    </div>
  )}
/>
```

## おわりに

今回は『検索ログの保存』と『それを用いた検索サジェスト機能』を実現してみました。
まともなデータ量がたまった時に、どれくらいパフォーマンスが出るか未知数なので、次回はそこも実験してみたいです。
