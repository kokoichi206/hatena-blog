# adb コマンドで端末を指定して起動する方法

複数端末・エミュレータが接続されているケースにおいて、**adb コマンドを使う際に特定の端末を指定する方法**です。

```sh
# シリアル番号を特定する
$ adb devices
List of devices attached
1C221FDF600AW6	device  # 1C221FDF600AW6 の部分
adb-8BSX1EC56-SlLKka._adb-tls-connect._tcp.	device

# -s でシリアル番号を指定
adb -s 1C221FDF600AW6 shell dumpsys package d
adb -s 1C221FDF600AW6 shell pm list packages

# USB デバッグで繋がってる端末が1つのみの場合
adb -d shell ...
```

`help` をみた感じ、`-d`, `-e`, `-s`, `-t` あたりが使えそうかと思いました。

```sh
$ adb --help | grep device
 -d         use USB device (error if multiple devices connected)
 -e         use TCP/IP device (error if multiple TCP/IP devices available)
 -s SERIAL  use device with given serial (overrides $ANDROID_SERIAL)
 -t ID      use device with given transport id
...
```

## おまけ: scrcpy

scrcpy も同様に指定できます。

```sh
scrcpy -s adb-8BSX1EC56-SlLKka._adb-tls-connect._tcp.
```
