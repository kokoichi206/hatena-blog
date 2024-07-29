# docker-compose で立てた psql の結果をローカルで受け取る

以下で紹介していることは基本は [psql のオプション](https://www.postgresql.jp/document/9.4/html/app-psql.html)になります。

docker compose で立ち上げたコンテナに対して内部の DB に入るには以下のようにできます。

```sh
# postgresql: コンテナ名
# root: ユーザー名
# postgresql: 接続したい DB 名
docker compose exec postgresql psql -U root postgresql
```

出力結果をローカルから確認したり、そのままファイル出力させたい時は以下のように** `-c` オプションで SQL を直接渡せ**ます。

```sh
dc exec postgresql psql -U root postgresql -c "SELECT * FROM groups;"
 id  |   name
-----+-----------
   1 | group_01
   2 | group_02
   3 | group_3
   4 | group_4
   5 | group_5
   6 | group_6
   7 | group_7
   8 | group_8
   9 | group_9
  10 | group_10
--More--
```

件数が多く More が表示される場合は、さらに `--pset=pager=off` を指定してあげます。

```sh
dc exec postgresql psql -U root postgresql -c "SELECT * FROM groups;" --pset=pager=off
 id  |   name
-----+-----------
   1 | group_01
   2 | group_02
   3 | group_3
   4 | group_4
   5 | group_5
   6 | group_6
   7 | group_7
   8 | group_8
   9 | group_9
  10 | group_10
  11 | group_11
  ...
```

また、ヘッダーを表示したくない場合は `-t` オプションで指定できます。

```sh
$ dc exec postgresql psql -U root postgresql -c "SELECT * FROM groups;" --pset=pager=off -t
   1 | group_01
   2 | group_02
   3 | group_3
   4 | group_4
   5 | group_5
   ...

# ↓ のようにリダイレクトできる
$ dc exec postgresql psql -U root postgresql -c "SELECT * FROM groups;" --pset=pager=off -t > select_group"$(date "+%Y-%m-%d")"
```
