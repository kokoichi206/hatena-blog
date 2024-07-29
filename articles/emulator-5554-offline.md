# emulator-5554 offline の退治法（Linux, macOS）

emulator は 1 つも立ち上げてないはずなのに、`more than one device/emulator` と表示され `adb` コマンドや `scrcpy` などが動作しない場合があります。

```
adb shell dumpsys package d
adb: more than one device/emulator
```

この時、他の端末・エミュレーターとかないのにな〜〜とか思いながら `adb devices` を叩くと、全く意図しない `emulator-5554` が存在するよ〜と言われました。

```sh
$ adb devices
List of devices attached
adb-8BSX1EC56-SlLKka._adb-tls-connect._tcp.     device
emulator-5554   offline
```

今回はこの `emulator-5554 offline` の退治法についてまとめます（Linux, macOS）。  
（もちろん `adb` コマンドのオプションを利用し、端末を指定して起動しても問題ないですが、無駄なプロセスがいるのも気持ち悪いので対応しましょう。）

## 削除法

5554 は何となく想像つくかもしれませんが、ポート番号だと思われます。

そこで `lsof(list open files)` コマンドを利用し、指定した `port` で何のアプリケーションが動いてるかを特定します。  
（Linux, macOS）

```sh
$ lsof -i

# 特定のポートに絞って表示する
$ lsof -i:5554
COMMAND     PID     USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
qemu-syst 52205 kokoichi   48u  IPv4 0x19d43a316fc9e1b3      0t0  TCP localhost:sgi-esphttp (LISTEN)
qemu-syst 52205 kokoichi   49u  IPv6 0x19d43a3166b04b03      0t0  TCP localhost:sgi-esphttp (LISTEN)
```

問題なさそうなら、PID を指定して抹殺します。

```sh
kill -KILL 52205
```

結果として、無事意図した（自分で把握してる）１台のみになりました！

```sh
$ adb devices
List of devices attached
adb-8BSX1EC56-SlLKka._adb-tls-connect._tcp.     device
emulator-5554   offline
```
