# Apache2 で特定のパスへの reverse proxy

いつもやり方がわからなくなるので、備忘録として残しておきます。

## やりたいこと

同じローカルマシンに立てたサーバーに、特定のパスを reverse proxy したい。

例:  
`<base_url>/status` にアクセスが来たとき、`localhost:3000` に立てたサーバーに reverse proxy する。

## 環境

```
Machine: Raspberry Pi 4
OS: Ubuntu 20.04.2 LTS (Focal Fossa)
apache2: Apache/2.4.52 (Ubuntu)
```

## やったこと

結論からいうと、立てたサーバーの base_url が `localhost:3000` のままだと、中で持ってる URL の変換が上手くいきませんでした。

そこで、以下のステップで期待通りの挙動を実現しました。

1. reverse proxy **させたい**サーバーの base_url を変更する
   - `/status` にアクセスが来たときに reverse proxy させたい場合は、`localhost:3000/status` とする
   - [gitlab で base_url を変更する方法](https://docs.gitlab.com/ee/user/project/pages/getting_started_part_one.html#urls-and-base-urls)
2. apache2 の設定に以下の内容を記述する
   - 下の例では `conf-enabled/reverse_proxy.conf` に記載しました
3. apache2 のリスタート
   - `sudo service apache2 restart`

``` sh
$ cat conf-enabled/reverse_proxy.conf 
<IfModule mod_proxy.c>
    ProxyRequests Off
    <Proxy *>
        Require all granted
    </Proxy>

    # <apache の base_url>/status を 
    ProxyPass /status http://localhost:3000
    ProxyPassReverse /status http://localhost:3000
    RewriteEngine On
    RewriteRule  ^/status/(.*)$ http://localhost:3000/$1 [L,P]
</IfModule>
```


## Links

- [How to ProxyPass to a '/path/' instead of root '/'?](https://serverfault.com/questions/757759/how-to-proxypass-to-a-path-instead-of-root)

## おまけ: grafana で base_url を変える

ubuntu での情報になります。

``` sh
# root_url と serve_from_sub_path を書き換えました。
sudo vim /etc/grafana/grafana.ini

#########################
# ...
# The full public facing url you use in browser, used for redirects and emails
# If you use reverse proxy and sub path specify full url (with sub path)
root_url = %(protocol)s://%(domain)s:%(http_port)s/status/                                      
# Serve Grafana from subpath specified in `root_url` setting. By default it is set to `false` fo     r compatibility reasons.
serve_from_sub_path = true
# ...
#########################
```
