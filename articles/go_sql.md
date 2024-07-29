# go の標準パッケージ sql がコネクションを管理する際の注意点

標準パッケージ sql は[一般的な SQL のインタフェースを提供しています](https://pkg.go.dev/database/sql#pkg-overview)。

使用する際は各ベンダーの用意する[ドライバー](https://github.com/golang/go/wiki/SQLDrivers)と共に使うことが**必要**で、諸々の使い方は [go の wiki](https://github.com/golang/go/wiki/SQLInterface) にも書いてあります。

今回はこの sql パッケージで注意が必要な点（と自分が今認識してる範囲）についてメモしておきます。  
他にも気をつけるべき点があればぜひ教えてください。

**[目次]**

```
## 扱わないこと
## 登場人物
## sql パッケージ利用時に気をつけたい点
### sql.Open はコネクションを確立しない
### コネクションを確立するには
### コネクションプールの制御
## （おまけ）db 側からコネクション数確認（postgres 編）
## おわりに
```

## 扱わないこと

以下内容については今回は扱いません。

- sqlboiler や gorm といった ORM がどのような扱いをしているのかについて

## 登場人物

本記事は go 1.21 の環境をもとにしています。

- [sql.DB](https://github.com/golang/go/blob/152ffca82fa53008bd2872f7163c7a1885da880e/src/database/sql/sql.go#L402-L438)
  - コネクションプールを管理する親玉
- [sql.driverConn](https://github.com/golang/go/blob/152ffca82fa53008bd2872f7163c7a1885da880e/src/database/sql/sql.go#L456-L472)
  - sql.DB の freeConn が持っている
- [sql/driver.Conn](https://github.com/golang/go/blob/152ffca82fa53008bd2872f7163c7a1885da880e/src/database/sql/driver/driver.go#L223-L248)
  - [driverConn の ci](https://github.com/golang/go/blob/152ffca82fa53008bd2872f7163c7a1885da880e/src/database/sql/sql.go#L461) として持っている**インタフェース**
  - 各ドライバーが実装
    - [lib/pq で実装している構造体](https://github.com/lib/pq/blob/3d613208bca2e74f2a20e04126ed30bcb5c4cc27/conn.go#L127-L173)
  - sql.DB が、コネクションプールの管理をゴルーチンセーフにしてくれているため、このコネクションはその辺の考慮不要

## sql パッケージ利用時に気をつけたい点

### sql.Open はコネクションを確立しない

[wiki の Connecting to a database](https://github.com/golang/go/wiki/SQLInterface#connecting-to-a-database) にも書いてありますが、sql.Open では sql.DB の初期化を行うのみで実際のコネクションは確立しません。

そのため、**ポートが間違っていたり db が起動してなかったりしてもエラーになりません**。

以下のように、`db.Stats()` で取得できる [sql.DBStats](https://pkg.go.dev/database/sql#DBStats) でコネクションに関する情報が取得できます。

``` go
package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
)

func main() {
	source := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		"localhost", "4646", "ubuntu", "ubuntu", "testdb", "disable",
	)

	db, err := sql.Open("postgres", source)
	if err != nil {
		log.Fatal(err)
	}
	stats := db.Stats()
	// 0: アイドル状態のコネクション数。
	fmt.Printf("stats.Idle: %v\t", stats.Idle)
	// 0: アクティブ状態のコネクション数。
	fmt.Printf("stats.InUse: %v\n", stats.InUse)
}
```

### コネクションを確立するには

ではどのようにコネクションを確立すれば良いかというと、sql.DB に対し db.Exec や db.Query を発行することで**勝手にコネクションが貼られます**。
ユーザーが意識することはありません。

特に Ping のコメントに

> // PingContext verifies a connection to the database is still alive,
> // establishing a connection if necessary.

と丁寧にあるように、Ping でもコネクションが貼られることが分かります。

``` go
func checkDBStatus(db *sql.DB) {
	stats := db.Stats()
	fmt.Printf("stats.Idle: %v\t", stats.Idle)
	fmt.Printf("stats.InUse: %v\n", stats.InUse)
}

func main() {
	source := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		"localhost", "4646", "ubuntu", "ubuntu", "testdb", "disable",
	)

	db, err := sql.Open("postgres", source)
	if err != nil {
		log.Fatal(err)
	}

	// sql.Open は実際にはコネクションをオープンしない！！
	// stats.Idle: 0   stats.InUse: 0
	checkDBStatus(db)

	defer func() {
		if closeErr := db.Close(); err != nil {
			log.Print(closeErr)
		}
	}()

	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	// Ping 等で、必要になった場合にコネクションをオープンする。
	// stats.Idle: 1   stats.InUse: 0
	checkDBStatus(db)
}
```

### コネクションプールの制御

sql.DB に生えているメソッドを通して『コネクションプールの最大数』や『コネクションがアイドルになってから切断するまでの時間』の設定等が可能です。
**デフォルトではどちらも 0 に設定**されており、これは無制限を意味するため注意が必要です。

``` go
func main() {
	source := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		"localhost", "4646", "ubuntu", "ubuntu", "testdb", "disable",
	)

	db, err := sql.Open("postgres", source)
	if err != nil {
		log.Fatal(err)
	}

	// オープンするコネクションの最大数を設定する。
	// デフォルトでは 0 で無制限！！
	db.SetMaxOpenConns(1)

	// 1 時間アイドル状態が続いたコネクションは閉じる！
	// デフォルトでは 0 で無制限！！
	db.SetConnMaxIdleTime(1 * time.Hour)
}
```

## （おまけ）db 側からコネクション数確認（postgres 編）

`pg_stat_activity` テーブルを確認することで、現在のコネクション情報が取得できるらしいです。

``` sql
SELECT pid, usename, application_name, state, query_start FROM pg_stat_activity;
```

``` sql
testdb=# \d pg_stat_activity;
                      View "pg_catalog.pg_stat_activity"
      Column      |           Type           | Collation | Nullable | Default 
------------------+--------------------------+-----------+----------+---------
 datid            | oid                      |           |          | 
 datname          | name                     |           |          | 
 pid              | integer                  |           |          | 
 leader_pid       | integer                  |           |          | 
 usesysid         | oid                      |           |          | 
 usename          | name                     |           |          | 
 application_name | text                     |           |          | 
 client_addr      | inet                     |           |          | 
 client_hostname  | text                     |           |          | 
 client_port      | integer                  |           |          | 
 backend_start    | timestamp with time zone |           |          | 
 xact_start       | timestamp with time zone |           |          | 
 query_start      | timestamp with time zone |           |          | 
 state_change     | timestamp with time zone |           |          | 
 wait_event_type  | text                     |           |          | 
 wait_event       | text                     |           |          | 
 state            | text                     |           |          | 
 backend_xid      | xid                      |           |          | 
 backend_xmin     | xid                      |           |          | 
 query_id         | bigint                   |           |          | 
 query            | text                     |           |          | 
 backend_type     | text                     |           |          | 

testdb=# SELECT pid, usename, application_name, state, query_start FROM pg_stat_activity;
 pid | usename | application_name | state  |          query_start          
-----+---------+------------------+--------+-------------------------------
  28 | ubuntu  |                  |        | 
  27 |         |                  |        | 
  36 | ubuntu  | psql             | active | 2023-09-16 15:40:27.098589+00
  24 |         |                  |        | 
  23 |         |                  |        | 
  26 |         |                  |        | 
(6 rows)
```

## おわりに

`net.Conn` の抽象化もエグいので、いつか使えるようになりたい！
