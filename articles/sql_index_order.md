# 複合 index の順番には注意したい

## 複合インデックスとは

複合インデックスは、2つ以上のカラムを組み合わせて作成されるインデックスのことを指します。

~~DB スペシャリストの問題文にあったため~~ 複合インデックスの定義順によってはインデックスが使われたり使われなかったりするらしいと知ったので、試しに実験してみました。

### まとめ

- **複合インデックスでは定義する順番が大きな意味を持つ**
  - インデックスで定義した順番のカラムが、**上位から一致している分だけ**インデックスが効率的に使われる
- 貼る際の注意点
  - **最も頻繁に検索やフィルタリングに使用されるカラムを最初に配置**することで、インデックスの効果を最大化できる
  - **高い選択性を持つカラム（ユニークな値が多いカラム）をインデックスの先頭に配置**することで、インデックスの効き目が大きくなる
- 複合インデックスでは単一カラムのインデックスよりもインデックスサイズが大きくなる
  - 公式でも『[4つ以上の列を使用しているインデックスは、不適切である可能性が高い](https://www.postgresql.jp/document/15/html/indexes-multicolumn.html)』といっている

## 実験してみる

実験用に、以下のテーブルを作成します。

``` sql
CREATE TABLE members (
    generation int,
    first char(46),
    last char(46)
);
```

また、以下のように全てのカラムを用いで複合 index を貼っておきます。

``` sql
CREATE INDEX idx_members_generation ON members(generation, first, last);
```

次に、**ある程度の統計情報がないとインデックスを使ってくれない**ため、テーブルにを 6000 行ほどのレコードを追加します。
（実際 11 * 26 程度だと期待値とズレることがありました。）

``` sh
# 9 * 26 * 26 = 6084 レコード
echo {1..9}{a..z}{a..z} | xargs -n 1 bash -c "psql --host=localhost --username=ubuntu --dbname=nogi -c \"INSERT INTO members VALUES ('\${0:0:1}', '\${0:1:1}', '\${0:2:1}');\""
```

現在のテーブル確認しておきます。

``` sql
nogi=# \d kawaiis 
                   Table "public.members"
   Column   |     Type      | Collation | Nullable | Default 
------------+---------------+-----------+----------+---------
 generation | integer       |           |          | 
 first      | character(46) |           |          | 
 last       | character(46) |           |          | 
Indexes:
    "idx_members_generation" btree (generation, first, last)

nogi=# SELECT COUNT(*) FROM members;
 count 
-------
  6084
(1 row)

nogi=# SELECT * FROM members ;
 generation |                     first                      |                      last                      
------------+------------------------------------------------+------------------------------------------------
          1 | a                                              | a                                             
          1 | a                                              | b                                             
          1 | a                                              | c                                             
          1 | a                                              | d                                             
          1 | a                                              | e                                             
          1 | a                                              | f                                             
          1 | a                                              | g                                             
          1 | a                                              | h                          
...
```

### インデックスの確認

インデックスの確認といえば EXPLAIN です。

``` sql
-- 統計情報を手動で更新しておく
ANALYZE members;
```

まずは、インデックスに出てくる全てのカラムで絞り込みます。

``` sql
-- 1 and 2 and 3
nogi=# EXPLAIN SELECT * FROM members WHERE generation = 5 AND first = 'a' AND last = 'o';
                                         QUERY PLAN                                         
--------------------------------------------------------------------------------------------
 Index Only Scan using idx_members_generation on members  (cost=0.41..4.43 rows=1 width=98)
   Index Cond: ((generation = 5) AND (first = 'a'::bpchar) AND (last = 'o'::bpchar))
(2 rows)
```

Index Only Scan が使われ、期待行数も 1 となり、正しく使われてそうな匂いがします。
また、コストは 4.43 となり、今回の基準とします。

次に、インデックスで出てくるカラムのうち、**上から2つ**で絞り込みます。

``` sql
-- 1 and 2
nogi=# EXPLAIN SELECT * FROM members WHERE generation = 5 AND first = 'a';
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Index Only Scan using idx_members_generation on members  (cost=0.41..4.93 rows=26 width=98)
   Index Cond: ((generation = 5) AND (first = 'a'::bpchar))
(2 rows)
```

Index Only Scan が使われており、行数も 26 行で期待値通りです。
また、全カラム指定時は 4.43 だったコストは 4.93 となり、**インデックスがほぼほぼフルで効いている**ことがわかります。

続いて、インデックスに出てくるカラムのうち、**1つ目の3つ目**で絞り込んでみます。

``` sql
-- 1 and 3
nogi=# EXPLAIN SELECT * FROM members WHERE generation = 5 AND last = 'o';
                                          QUERY PLAN                                          
----------------------------------------------------------------------------------------------
 Index Only Scan using idx_members_generation on members  (cost=0.41..55.43 rows=26 width=98)
   Index Cond: ((generation = 5) AND (last = 'o'::bpchar))
(2 rows)     
```

Index Only Scan が使われており、行数も 26 行で期待値通りです。
しかし、**前回 4.93 だったコストは 55.43 と爆増**しており、**インデックスが効率的に使われてない**ことがわかります。
（実質的には1つ目までしか効いてないです。）

ここまでの結果から、複合インデックスで貼ったカラムは WHERE 句で**上から順に指定しないと効果がない**ことが確認できました。

### おまけ

他にとりうる全パターン試してみました。
特に、WHERE 句で指定する順番が関係なさそうなことは頭に入れておきたいです。

``` sql
-- 2 and 3
nogi=# EXPLAIN SELECT * FROM members WHERE first ='a' AND last = 'o';
                         QUERY PLAN                         
------------------------------------------------------------
 Seq Scan on members  (cost=0.00..191.26 rows=9 width=98)
   Filter: ((first = 'a'::bpchar) AND (last = 'o'::bpchar))
(2 rows)

-- 1
nogi=# EXPLAIN SELECT * FROM members WHERE generation = 5;
                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
 Index Only Scan using idx_members_generation on members  (cost=0.41..60.24 rows=676 width=98)
   Index Cond: (generation = 5)
(2 rows)

-- 2
nogi=# EXPLAIN SELECT * FROM members WHERE first ='a';
                         QUERY PLAN                         
------------------------------------------------------------
 Seq Scan on members  (cost=0.00..176.05 rows=234 width=98)
   Filter: (first = 'a'::bpchar)
(2 rows)

-- 3
nogi=# EXPLAIN SELECT * FROM members WHERE last ='o';
                         QUERY PLAN                         
------------------------------------------------------------
 Seq Scan on members  (cost=0.00..176.05 rows=234 width=98)
   Filter: (last = 'o'::bpchar)
(2 rows)

-- WHERE で指定する順番は関係なさそう
-- 2 and 1
nogi-official=# EXPLAIN SELECT * FROM kawaiis WHERE first = 'a' AND generation = 5;
                                         QUERY PLAN                                          
---------------------------------------------------------------------------------------------
 Index Only Scan using idx_kawaiis_generation on kawaiis  (cost=0.41..4.93 rows=26 width=98)
   Index Cond: ((generation = 5) AND (first = 'a'::bpchar))
(2 rows)
```

## Links

- [postgresql: 11.3. 複数列インデックス](https://www.postgresql.jp/document/15/html/indexes-multicolumn.html)
