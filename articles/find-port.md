# mac と Linux で特定のポートを使用しているプロセスを調べる

lsof を使うのが簡単で良さそうです。

``` sh
lsof -i:8080

$ lsof -i:8080
COMMAND   PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
main    77228 kokoichi    4u  IPv6 0x50df81af803226e5      0t0  TCP *:http-alt (LISTEN)

# その後該当プロセスを削除する場合。
# 77228 は上で出てきた PID.
$ kill -KILL 77228
```

デーモンなど、プロセスによっては sudo つけないと見えない時があります。
