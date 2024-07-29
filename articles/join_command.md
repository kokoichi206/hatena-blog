# ターミナルで RDB の JOIN

join というコマンドがすごい便利だったので共有です。

## 概要

manual page にもあるように、RDB の join と同じことができます。

``` sh
$ man join

JOIN(1)                                General Commands Manual                               JOIN(1)

NAME
     join – relational database operator
```

RDB に多少触れたことがある方なら、以下の使用例だけですごさが分かるかと思います。

``` sh
$ cat file1
a1,b1
a2,b2
a3,b3
$ cat file2
a1,c1
a3,c3
a4,c4
$ join -t ',' file1 file2 # inner join
a1,b1,c1
a3,b3,c3
$ join -t ',' -a 1 file1 file2 # left outer join
a1,b1,c1
a2,b2
a3,b3,c3
$ join -t ',' -a 1 -o 0,1.2,2.2 file1 file2 # left outer join
a1,b1,c1
a2,b2,
a3,b3,c3
$ join -t ',' -a 2 -o 0,1.2,2.2 file1 file2 # right outer join
a1,b1,c1
a3,b3,c3
a4,,c4
```
