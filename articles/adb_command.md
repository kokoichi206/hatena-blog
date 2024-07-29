# よく使う adb コマンド
adb（Android Debug Bridge）コマンドとは、その名の通り Android 開発をする際に色々とお世話になるコマンドです。

その中でも個人的によく使うコマンドをまとめておこうと思います。

以下では基本的にターミナル上で使うことを想定しており、事前にパスが通ってることを確認します。

```sh
# パスが通ってる場合
$ adb
Android Debug Bridge version 1.0.41
Version 31.0.2-7242960
Installed as ...
...

# パスが通ってない場合
$ adb
Command 'adb' not found, but can be installed with:
    ....
```

それではコマンドを見ていきます。

## adb devices
接続されている機器一覧を表示させます。

```sh
$ adb devices
adb devices
List of devices attached
06......	device

# -l オプションで詳細表示
$ adb devices -l
06......   device usb:33..... product:hammerhead 
model:Nexus_5 device:hammerhead transport_id:5
```

## adb install
apk ファイルを端末にインストールする

```sh
# 事前に apk ファイルの場所まで移動しておく
$ adb install <apk_name>

# -r をつけると上書きインストールになる
$ adb install -r <apk_name>
```

## adb uninstall
apk ファイルを端末からアンインストールする

```sh
$ adb install <apk_name>
```

## adb shell pm list package
端末内にインストールされているパッケージ一覧を表示させる。

```sh
$ adb shell pm list package
adb shell pm list package
package:com.google.android.carriersetup
package:org.lineageos.overlay.accent.black
package:com.android.cts.priv.ctsshim
...

# grep などでお目当てのものを探す
$ adb shell pm list package | grep google
package:com.google.android.carriersetup
package:com.google.android.youtube
package:com.google.android.ext.services
...
```

## adb logcat
アプリから出力されるログを検知する

```sh
# 全てのログを出力させる
$ adb logcat

# エラー以上のログを出力させる
$ adb logcat '*:E'

# 特定のタグの名前に絞ってログを検出する
$ adb logcat -s <tag_name>:*

# さらに、error 以上などの条件をつけたければ、
$ adb logcat -s <tag_name>:E
```

## adb reboot bootloader
リブートモードで再起動する

```sh
$ adb reboot bootloader
```

## おわりに
他にもPCからデータを送ったり、PCにデータを送ったりと、実質なんでもできます。

やりたいことがあれば是非調べてみてください！
