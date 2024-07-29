# systemd で定期実行する

『systemd で定期実行をする』というよくある内容ですが、設定できたつもりになってた自分自身の反省を兼ねてメモしておきます。
（細かい設定方法については説明しません。）

systemd などのタスク系に関しては、**うまく動いてるかの確認**がより大事になってきます。

**[目次]**

```
* [環境](#環境)
* [Service の作成](#service-の作成)
* [Timer の作成](#timer-の作成)
* [設定反映](#設定反映)
* [動作確認](#動作確認)
* [失敗談](#失敗談)
```

## 環境

以下内容は ubuntu の 20.04.2 で動作確認してます。

``` sh
$ uname -a
Linux ubuntu 5.4.0-1045-raspi #49-Ubuntu SMP PREEMPT Wed Sep 29 17:49:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

systemd による設定内容は `/etc/systemd/system` にあります。

``` sh
$ ls /etc/systemd/system
```

ここにいい感じにファイルを追加していきます。

## Service の作成

実行の主体となる Service 設定を定義します。

``` sh
$ cat update-mydns.service 
[Unit]
Description = Login mydns scripts

[Service]
User=ubuntu
Group=ubuntu
Type=oneshot
WorkingDirectory=/home/ubuntu/work/worker
ExecStart=/home/ubuntu/work/worker/login-mydns.sh

[Install]
WantedBy=multi-user.target
```

`login-mydns.sh` には実行権限をつけました。

``` sh
chmod +x /home/ubuntu/work/worker/login-mydns.sh
```

## Timer の作成

作成した Service をどのような頻度・間隔で実行するかを定義します。

``` sh
$ cat update-mydns.timer 
[Unit]
Description=Update mydns timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

- OnUnitActiveSec
  - 最終に実行されてからどれくらい時間が経ったら実行するか
- OnBootSec
  - OS が起動後、どのくらい時間が経ったら実行するか

## 設定反映

``` sh
# 設定ファイルを変更した後に毎回必要。
sudo systemctl daemon-reload

sudo systemctl enable update-mydns.timer
sudo systemctl start update-mydns.timer

# restart する場合。
sudo systemctl restart update-mydns.timer
```

## 動作確認

自分の場合ですが、**設定ミスにより1ヶ月ほど timer が動作してない**ことがありました。

そうならないためにも、設定後はぜひ動いてることを確認しましょう。

systemctl status を叩き、`Active` と `Trigger` を確認します。
以下のように表示されていれば問題ないです。

- Active: active
- Trigger: 次に実行される日時

``` sh
$ systemctl status update-mydns.timer
● update-mydns.timer - Update mydns timer
     Loaded: loaded (/etc/systemd/system/update-mydns.timer; enabled; vendor preset: enabled)
     Active: active (waiting) since Sun 2024-01-14 15:09:46 UTC; 17min ago
    Trigger: Sun 2024-01-14 15:29:51 UTC; 2min 27s left
   Triggers: ● update-mydns.service

Jan 14 15:09:46 ubuntu systemd[1]: Stopped Update mydns timer.
Jan 14 15:09:46 ubuntu systemd[1]: Stopping Update mydns timer.
Jan 14 15:09:46 ubuntu systemd[1]: Started Update mydns timer.
```

また実行が失敗したりしてないか、ログも確認しておきます。
（path が見つからなかったり実行権限がなかったりと、普通のスクリプトよりはエラーが発生しやすいので）

``` sh
$ journalctl -u update-mydns.service
$ journalctl -u update-mydns.timer
```

## 失敗談

ちなみに自分は以下のように Timer セクションを書いたまま、実行され続けている気になっていました。

``` sh
[Timer]
OnUnitActiveSec=5min
Persistent=true
```

`Persistent=true` に関しては、システム異常などにより最後の起動時間から指定以上経ってた場合、即座に実行させるためのものらしいです。
（OnCalendar と一緒に使うことが多分必要なんだろう。）

後々 **status を見てみると、どうやら `Trigger` に `n/a` に**なってしまっていました。

``` sh
$ systemctl status update-mydns.timer
● update-mydns.timer - Update mydns timer
     Loaded: loaded (/etc/systemd/system/update-mydns.timer; enabled; vendor preset: enabled)
     Active: active (elapsed) since Fri 2023-12-08 13:56:12 UTC; 1 months 6 days ago
    Trigger: n/a
   Triggers: ● update-mydns.service
```
