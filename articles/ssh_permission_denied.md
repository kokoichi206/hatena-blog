# ubuntu に ssh 接続した際に Permission denied (publickey)
ラズパイ（ubuntu）に新規の SSH アクセスを行おうとした際に、`Permission denied (publickey)`が出ました。

そんな時にチェックすることと、その解決策についてメモしておきます。

## 環境
```
- クライアント側は mac を使用
- 他の端末からは SSH 接続できている
- `ssh username@host`で接続エラーが発生する
```

## 解決策

### 現状確認
他の端末からは SSH 接続できているにも関わらず新規からの接続ができない場合、password でのログインを無効にしている可能性が高いです（セキュリティ上）。

そのような設定になっているかどうか、`/etc/ssh/sshd_config`の記述を確認します。

``` sh
# ubuntu で確認
$ cat /etc/ssh/sshd_config | grep PasswordAuthentication
PasswordAuthentication no
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication, then enable this but set PasswordAuthentication
```

予想通り`PasswordAuthentication`が`no`となっているので、ssh の公開キーを登録するなどの設定をしてあげる必要があります。

### 設定方法
パスワードによりアクセスができないため、鍵交換方式による ssh 接続をできるように設定をする必要があります。

#### step1. 接続に用いる SSH キーを生成します
今回は他の鍵と区別するため、`raspi`というファイル名で生成しています。

```
$ ssh-keygen -f raspi
```

#### step2. `~/.ssh/config`を編集します

``` sh
$ vim ~/.ssh/config
```

内容については、以下のように記入します

```
Host サーバー名
    HostName ipもしくはドメイン名（192.168.x.x等）
    User ユーザ名（ubuntu等）
    Port 22
    IdentityFile ~/.ssh/raspi
```

#### step3. サーバー側の`~/.ssh/authorized_keys`を編集します
サーバー側の鍵交換 SSH 許可リストに、クライアント側の**公開鍵**を登録します。

``` sh
# サーバー側にログインした状態
$ vim ~/.ssh/authorized_keys
```

記述内容としては、以下の様な publickey（`~/.ssh/raspi.pub`）をファイルの末尾に追加します。

```
ssh-rsa AA...
```

USB なり他 PC から ssh, scp するなり、なんとか登録してください。

### それでもエラーが出る
自分の場合は step3 まで行なっても（設定が反映されてないせいか）接続できないままでした。

そこで、以下のように使用する秘密鍵を明示的に指定してあげることで接続できるようになりました。

``` sh
$ ssh -i ~/.ssh/raspi username@192.168.x.xx
```

## おわりに
SSH の接続設定などは一度やったら当分やらないので毎回悩んでいる気がします。

次回からは（いつになるかわかりませんが）これを参考に設定してみようと思います。
