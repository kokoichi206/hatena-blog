# datadog で apache のログを収集してる際の /server-status を無視する

個人で勉強のために datadog を入れてみてラズパイで動かしているのですが、CPU 等を監視するために datadog-agent が 15 秒おきに `/server-status?auto` へアクセスを行なっているようです。  
気づい時には 3 万 4000 ほど `/server-status?auto` へのログが datadog へと吸い上げられていました（それに対し意味のあるログは 1000 ほど）。

無駄なログはコストがかかるだけなので、今回はこれをあげないようにしてみました。

ざっと『apache のログに残さないようする』か『apache のログには残すが datadog には吸い上げないようにする』かの２通りあるかと思うのですが、今回は **apache 単体で見ても意味のないログ**であることから『apache のログに残さないようする』方法を取ることにしました。  
（エラーの場合は apache のエラーログには残る）

## 環境

```
$ apache2 -v
Server version: Apache/2.4.52 (Ubuntu)
Server built:   2021-12-28T20:18:12

$ cat /proc/cpuinfo | grep Model
Model           : Raspberry Pi 4 Model B Rev 1.4

$ cat /etc/os-release
NAME="Ubuntu"
VERSION="20.04.2 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.2 LTS"
VERSION_ID="20.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=focal
UBUNTU_CODENAME=focal
```

## apache で特定の URI へのログを残さないようにする

```sh
# とりあえず /server-status から始まるものをはじきたい
$ sudo vim /etc/apache2/apache2.conf

...
# common という名前をつけている。
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined

# https://httpd.apache.org/docs/2.2/env.html#page-header
SetEnvIf Request_URI "^/server-status" dontlog
ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log common env=!dontlog
...

$ sudo systemctl restart apache2
```

- [dont-log-certain-requests-in-apache-access-log](https://stackoverflow.com/questions/40205569/dont-log-certain-requests-in-apache-access-log)
- [Apache の環境変数](https://httpd.apache.org/docs/2.2/env.html)
- [apache-mod-setenvif](http://unixservermemo.web.fc2.com/sv/apache-mod-setenvif.htm)
