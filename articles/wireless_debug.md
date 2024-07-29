# Wireless debugging 接続（adb）で「Failed: Unable to start pairing client.」と表示される

Android の開発には、端末の開発者モードで debug を ON にする必要があるのですが、wifi で Wireless に接続できることを学びました。（Android 11 以上）

（接続の仕方は公式が詳しいです）


[https://developer.android.com/studio/command-line/adb?hl=ja:embed:cite]


その際、adb コマンドを使って再接続しようとしたら

> Failed: Unable to start pairing client.

というエラーメッセージが出て時間を消費してしまったので、今後のためにメモしておく


## 解決策

### その０
最初当分悩んでいるのですが、PC を再起動したら解決しました。

### その１
1. 開発者モードののなかの DEBUGGING モードのすぐ上の、「Quick settings developer tiles」をクリック
2. Wireless debugging を ON にすると、通知ドロワー（Wifi などがあるところ）に Wireless debugging が表示されている
3. Android Studio には自動的に接続される設定があるので、それを発動させるために、通知ドロワーの「Wifi と Wireless debugging」の両方を１回 OFF にして ON にし直す

### その２
1. adb klii-server
2. android studio再起動


## おわりに
