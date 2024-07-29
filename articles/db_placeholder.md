# プレースホルダーは何を守ってくれるか 〜Go での確認を添えて〜

特に深いことは語れないのですが、[安全な SQL の呼び出し方](https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf)を読んで気づきがあったためメモしておきます。

## まとめ

- SQL の構成要素（**以下を意識して区別する！**）
  - キーワード（予約語）: SELECT, WHERE, AND, ...
  - 演算子など: `=, >=, ...`
  - 識別子: テーブル名、カラム名
  - リテラル: 文字列や数値など
- SQL インジェクション**対策の基本**
  - **プレースホルダーを用いたバインド機構**を利用する
    - パラメータを表す部分（go では $1, $2,...）のことを**プレースホルダ**、そこへ実際の値を割り当てることを『**バインド**』と呼びます
- プレースホルダー
  - **リテラルのみを対象**にエスケープをかける
  - 逆にいうと、**それ以外の構成要素**にユーザーの入力情報を使いたい場合は**バインド機構に頼らずエスケープ**が必要
    - go だと [pq#QuoteIdentifier](https://pkg.go.dev/github.com/lib/pq#QuoteIdentifier) のようにドライバーが用意してくれたり
  - 静的プレースホルダー（Prepared Statement）
    - 後から構文が変化する事がなく安全！
  - 動的プレースホルダー（クライアントサイド Prepared Statement）
    - パラメータのバインドはアプリのライブラリ内で実行
- そのほか
  - 全てのインジェクションの原因
    - [「**命令**」と「**データ**」が分離されてないこと](https://blog.ohgaki.net/injection-prevention-basic)

**目次**

```
* [まとめ](#まとめ)
* [SQL インジェクション](#sql-インジェクション)
  * [対策](#対策)
  * [リテラル](#リテラル)
  * [プレースホルダとバインド機構](#プレースホルダとバインド機構)
* [Links](#links)
* [おまけ: Go で遊んでみる](#おまけ:-go-で遊んでみる)
  * [環境](#環境)
  * [用意した db](#用意した-db)
  * [DB セットアップ](#db-セットアップ)
  * [プレースホルダーのない世界（SQL injection）](#プレースホルダーのない世界（sql-injection）)
  * [プレースホルダーを使う](#プレースホルダーを使う)
  * [リテラル以外へのプレースホルダーの適応はどうなるか](#リテラル以外へのプレースホルダーの適応はどうなるか)
  * [リテラル以外に入力を受け取るときの注意点](#リテラル以外に入力を受け取るときの注意点)
* [おわりに](#おわりに)
```

## SQL インジェクション

他のインジェクション同様、基本的には入力値の検証漏れにより**データの一部を命令として扱ってしまう**ことが原因で SQL インジェクションは発生します。

### 対策

基本的な対策としては、DB のプレースホルダーを使うことになります。
（SQL にとって特別な意味を持つ記号（メタ文字）はデータベースエンジンによって異なるため、個人で対応しようと思ったらしんどいです。）

- バインド機構を利用し対策する
  - なんらかの理由でバインド機構で実装できない場合は、エスケープ処理による対策も必要
- SQL にとって特別な意味を持つ記号（メタ文字）はデータベースエンジンによって異なる
  - → 環境に応じて対策が必要

### リテラル

``` sql
-- SQL 例
SELECT name, age FROM users WHERE name = 'John' AND age > 20;
```

SQL を構成する要素

- キーワード（予約語）
  - SELECT, FROM, WHERE, AND
- 演算子など
  - `= >= ,`
- 識別子
  - name age users
- リテラル
  - 'John' 20
  - 文字列リテラルや数値リテラル、論理値リテラルなどがある。

対策

- 文字列の中に ' が入ってたりする場合は、それをエスケープして '' とする。
- アプリケーションとして扱う際は、リテラル部分をパラメータ化する事が一般的。
  - ここで生成される文を正しくエスケープ処理する必要がある。

文字列リテラルに対する SQL インジェクション

- パラメータを正しくリテラルとして展開する事が必要
- 文字列リテラルに対しては、エスケープすべき文字列をエスケープさせること
- 数値リテラルに対しては、数値以外の文字を混入させないこと
  - **型のない言語で注意**

通常の文字列結合では不都合が生じることがあります。
（あとでみる）

### プレースホルダとバインド機構

SQL インジェクションされないよういい感じにエスケープする必要があるのですが、便利なことに RDBMS にはプレースホルダとよばれるものが用意されています。

パラメータを表す部分（go では $1, $2,...）のことを**プレースホルダ**、そこへ実際の値を割り当てることを『**バインド**』と呼びます。

また、プレースホルダの組み立てには主に2つの方法があります。

- 静的プレースホルダ
  - Prepared Statement
  - SQL を準備する段階で SQL の文が確定する
    - 後から構文が変化する事がなく安全！
- 動的プレースホルダ
  - プレースホルダを利用するものの、パラメータのバインドをアプリのライブラリ内で実行
    - ライブラリ側の実装によるところが大きいため、場合によっては脆弱
  - クライアントサイドのプリペアードステートメント

## Links

- [全てのインジェクション対策は「命令」と「データ」を確実に分離することで対策可能](https://blog.ohgaki.net/injection-prevention-basic)
  - KVS（Key Value Store）がSQLデータベースより安全であるのは、インターフェースレベルで命令とデータを完全に分離しているから
- [安全な SQL の呼び出し方](https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf)


## おまけ: Go で遊んでみる

理解を深めるための Go の素振りコードです。

### 環境

```
postgres image
  postgres:15-alpine

go version
  go1.20.7 darwin/arm64
libraries
  github.com/lib/pq v1.10.9
```

### 用意した db

``` yaml
services:
  postgres:
    image: postgres:15-alpine
    command: postgres -c log_destination=stderr -c log_statement=all -c log_connections=on -c log_disconnections=on
    environment:
      - POSTGRES_USER=ubuntu
      - POSTGRES_PASSWORD=ubuntu
      - POSTGRES_DB=postgres
    logging:
      options:
        max-size: "10k"
        max-file: "5"
    ports:
      - "4949:5432"
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/docker_postgres_init.sql
```

また、以下のようなデータを用意しておき、users table から情報を取り出すプログラムを考えます。

``` sql
$ cat init.sql

CREATE TABLE users (
    name VARCHAR(255),
    password VARCHAR(255),
    age INT
);

INSERT INTO users (name, password, age) VALUES ('John', 'doe', 25), ('Jane', 'pien', 30), ('Joe', 'hi', 28);
```

### DB セットアップ

Go で postgresql のデータベースを扱うために、lib/pq というドライバを準備しておきます。

``` go
package main

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

type database struct {
	db *sql.DB
}

type user struct {
	Name string
	Age  int
}

func parseRows(rows *sql.Rows) ([]user, error) {
	resp := []user{}

	for rows.Next() {
		var n sql.NullString
		var a sql.NullInt64

		if err := rows.Scan(&n, &a); err != nil {
			return nil, fmt.Errorf("failed to scan: %w", err)
		}

		resp = append(resp, user{
			Name: n.String,
			Age:  int(a.Int64),
		})
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to loop rows scan: %w", err)
	}

	return resp, nil
}

func connect(driver, host, port, user, password, dbname, sslmode string) (*sql.DB, error) {
	source := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode,
	)

	sqlDB, err := sql.Open(driver, source)
	if err != nil {
		return nil, fmt.Errorf("failed to open sql: %w", err)
	}

	return sqlDB, nil
}

func main() {
	// ===================== lib/pq ======================
	db, err := connect("postgres", "localhost", "4949", "ubuntu", "ubuntu", "postgres", "disable")
	if err != nil {
		panic(err)
	}

	d := &database{db: db}
}
```

### プレースホルダーのない世界（SQL injection）

プレースホルダーがない場合、ナイーブに考えると、以下のように文字列結合で繋ぎたくなります。

``` go
const getAllUsersStmt = `
SELECT name, age FROM users WHERE name = '%s'
`

func (d *database) getAllUsers(ctx context.Context, name string) ([]user, error) {

	rows, err := d.db.QueryContext(ctx, fmt.Sprintf(getAllUsersStmt, name))
	if err != nil {
		return nil, fmt.Errorf("failed to select messages: %w", err)
	}

	// close 略。

	return parseRows(rows)
}

func main() {
	// ======= db setup ===========

	// John はユーザーからの入力を受け付けた値とする。
	users, err := d.getAllUsers(context.Background(), "John")
	if err != nil {
		panic(err)
	}
}
```

しかしこの結合では脆弱性があり、以下のようなユーザーからの入力があった場合 **users テーブルがテーブルごと削除されてしま**います。
（とてつもない被害が発生しうる事がわかります。）

``` go
func main() {
	// ======= db setup ===========

	// users, err := d.getAllUsers(context.Background(), "John")
	// John'; DROP TABLE users; -- はユーザーからの入力を受け付けた値とする。
	users, err := d.getAllUsers(context.Background(), "John'; DROP TABLE users; --")
	if err != nil {
		panic(err)
	}
}
```

この例では最終的に発行される SQL は

``` sql
SELECT name, age FROM users WHERE name = 'John'; DROP TABLE users; --'
```

のようになり、`;` が終端文字として機能するので**異なる 2 文**が実行されてしまいます。
また、最後にコメント開始の合図である `--` を付け加えることでもともとあった SQL の残りを無視しています。

### プレースホルダーを使う

Postgresql でプレースホルダーを表す文字は `$i` なので、Go で実装するには以下のようにします。

``` go
const getAllUsersPlaceholderStmt = `
SELECT name, age FROM users WHERE name = $1
`

func (d *database) getAllUsersPlaceholder(ctx context.Context, name string) ([]user, error) {
	rows, err := d.db.QueryContext(ctx, getAllUsersPlaceholderStmt, name)
	if err != nil {
		return nil, fmt.Errorf("failed to select messages: %w", err)
	}

	// close 略。

	return parseRows(rows)
}

func main() {
	// db setup

	// users テーブルは削除されない。
	uss, err := d.getAllUsersPlaceholder(context.Background(), "John'; DROP TABLE users; --")
	if err != nil {
		panic(err)
	}

	// []
	fmt.Println(uss)
}
```

バインド機構を使った SQL においては SQL injection は発生せず、users テーブルは削除されない事がわかります。

また、この時 SQL のログを見ると以下のような動的に生成された（名前なしの）プリペアードステートメントが使われてそうなことが観測できました。

``` sh
// playground-postgres-1  | 2023-10-08 17:21:59.919 UTC [58] LOG:  execute <unnamed>:
// playground-postgres-1  |        SELECT name, age FROM users WHERE name = $1
// playground-postgres-1  |
// playground-postgres-1  | 2023-10-08 17:21:59.919 UTC [58] DETAIL:  parameters: $1 = 'John''; DROP TABLE users; --'
```

きちんと文字列リテラルとしてのエスケープができてて偉い。

### リテラル以外へのプレースホルダーの適応はどうなるか

SQL 構成要素においてリテラルとか識別子とかを意識することは大事ですが、

プレースホルダーが SQL インジェクションに有効なことは確認できましたが、例えばリテラル以外の例えば識別子を入力で変えたい場合はどうでしょうか？

以下のように ORDER BY の次の内容（テーブルのカラム名）をプレースホルダーとし、バインドさせることを考えます。

``` go
const orderByParamPlaceHolder = `
SELECT name, age FROM users ORDER BY $1
`

func (d *database) getAllUsersOrderByPH(ctx context.Context, param string) ([]user, error) {
	rows, err := d.db.QueryContext(ctx, orderByParamPlaceHolder, param)
	if err != nil {
		return nil, fmt.Errorf("failed to select messages: %w", err)
	}

	// close 略。

	return parseRows(rows)
}

func main() {
	// db setup
	users, err := d.getAllUsersOrderByPH(context.Background(), "age; DROP TABLE users; --")
	if err != nil {
		panic(err)
	}

	fmt.Println(users)
}
```

実行後に db をのぞいてみても、テーブルは**削除されていません！**

じゃあこれで対策は大丈夫なのかと思いきや、**肝心のソートがされていません**。

``` go
func main() {
	// db setup
	users, err := d.getAllUsersOrderByPH(context.Background(), "age")
	if err != nil {
		panic(err)
	}

	// 出力が age の昇順になっていない！
	// [{John 25} {Jane 30} {Joe 28}]
	fmt.Println(users)
}
```

これは**プレースホルダーとして埋め込んだ識別子が、文字列リテラルとして解釈されそれ用のエスケープが施された**事が原因となります。

つまり、内部的には以下のような SQL が発行されています。

``` sql
SELECT name, age FROM users ORDER BY 'age';
```

### リテラル以外に入力を受け取るときの注意点

識別子に対してはプレースホルダーが正しく機能しないことを確認しましたが、外から受け取りたい時はどうしたらいいのでしょうか？

残念ながら、ユーザーで独自のバリデーションをかけるしかありません。

- ホワイトリストで特定の識別子以外を弾く
- RDBMS の仕様に沿ったエスケープ処理を施す
  - [pq#QuoteIdentifier](https://pkg.go.dev/github.com/lib/pq#QuoteIdentifier) なども便利か

ORDER BY での例を下に挙げておきます。

``` go
const orderByParam = `
SELECT name, age FROM users ORDER BY %s
`

func (d *database) getAllUsersOrderBy(ctx context.Context, param string) ([]user, error) {
	// 次のようなナイーブな結合では SQL インジェクションを起こす。
	// query := fmt.Sprintf(orderByParam, param)
	query := fmt.Sprintf(orderByParam, pq.QuoteIdentifier(param))
	rows, err := d.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to select messages: %w", err)
	}

	// close 略。

	return parseRows(rows)
}

func main() {
	users, err := d.getAllUsersOrderBy(context.Background(), "age")
	if err != nil {
		panic(err)
	}

	fmt.Println(users)
}
```

## おわりに

何が何を守ってくれるのか、理解して使いたい。
