# Android 実機の画面を PC 上に表示させたい

Android でデバッグしているときに、その画面をPC 上に表示させ、共有や配信を行いたいことがあると思います。

その際に便利な [scrcpy](https://github.com/Genymobile/scrcpy) というコマンドを見つけたのでメモしておこうと思います。

## インストール方法
Mac の方は brew でインストールできます

```bash
$ brew install scrcpy

# adb 接続されたデバイスがあるか確認
$ adb devices
List of devices attached
adb-8BSX1EC56-SlLKka._adb-tls-connect._tcp.	device
```

Linux (Debian) も同様です

```bash
$ apt install scrcpy
```

Windows をお使いの方は、[こちらの Github のメージ](https://github.com/Genymobile/scrcpy#summary)にインストール先があります

## 使い方
基本的にはターミナル上で`scrcpy`と打つだけです

```
$ scrcpy
```

すると下のように実機と全く同様の画面が PC 上に表示されます。

[f:id:kokoichi206:20210927232314p:plain]

PC 上とスクリーンのどちらからでも操作することが可能です。

## おわりに
今回は`scrcpy`を紹介しました。

今まではPC から動画を撮りたい時、Android で画面録画をしたあと adb コマンドで pull していました。これからは`scrcpy`コマンドを使ってPC 上で録画をしたいと思います。（多少重くなる感は否めません）
