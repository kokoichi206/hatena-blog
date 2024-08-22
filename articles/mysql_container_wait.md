# MySQL のコンテナの起動を正しく待つ

CI 中など、コンテナが起動し MySQL のサーバーが起動されたか確認したい場合があります。

その目的のため `mysqladmin` コマンドを使っていたのですが、思ったように起動完了しておらず、次のステップで落ちてしまったことがあったのでその共有です。

## 原因 & 解決策

mysql のコンテナは起動時に "temporary server" を立ち上げて、その後自分で設定した mysql のサーバーのが起動するっぽいです。

**後者のサーバーにのみ network interface が割り当てられる**ので、protocol を tcp に指定すると確定で後者の起動が確認できます。

``` sh
# protocol を指定しないと "temporary server" 側にアクセスされてしまう。
mysqladmin ping -hlocalhost --silent --protocol tcp
```

## コンテナの起動方法

`compose.yml`

``` yml
services:
  db:
    image: "mysql:8.0"
    restart: always
    environment:
      MYSQL_ALLOW_EMPTY_PASSWORD: "true"
      MYSQL_USER: mysql_user
      MYSQL_PASSWORD: mysql_password
      MYSQL_DATABASE: app
    ports:
      - "43306:3306"
```

## コンテナの起動確認

``` sh
docker compose up -d db
# --protocol tcp をつける。
docker compose exec db bash -c 'while ! mysqladmin ping -hlocalhost --silent --protocol tcp; do sleep 1; done'
```

## Links

- [(stack overflow) MySQL Docker - Check if mysql server is up and running](https://stackoverflow.com/questions/70485527/mysql-docker-check-if-mysql-server-is-up-and-running)
- [(Qiita) Docker化のMySQLサーバーが正常に起動してるかを簡単に確認できると思う僕が甘かった件](https://qiita.com/akarei/items/1130a4dff48c1cbe978e#%E4%B8%80%E6%99%82%E7%9A%84%E3%81%AAmysql%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC%E3%81%A8%E6%AD%A3%E5%BC%8F%E3%81%AAmysql%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC%E3%81%AB%E3%81%A9%E3%82%93%E3%81%AA%E9%81%95%E3%81%84%E3%81%8C%E3%81%82%E3%82%8B%E3%81%8B)
