# caffeinate で Mac のスリープを止めて power assertion を観察する

出先から自宅の Mac を触っていて、席を外す間にスリープされると困る状況になりました。最初に思いついたのは「ブラウザで動画を流しっぱなしにしておく」でしたが、macOS には power assertion という仕組みがあり、コマンド 1 つで済みます。その設定と、assertion を覗く方法のメモです。

<!-- more -->

## 目次

* [目次](#目次)
* [環境](#環境)
* [スリープを止める](#スリープを止める)
* [効いているか確認する](#効いているか確認する)
* [時系列で観察する](#時系列で観察する)
* [ハマりどころ](#ハマりどころ)
* [おわりに](#おわりに)

## 環境

- macOS 26.0.1（Apple Silicon）

## スリープを止める

macOS 標準の caffeinate コマンドを使います。

```sh
# 24 時間スリープを止める。
$ caffeinate -ims -t 86400 &
```

`man caffeinate` によると、それぞれのフラグは次の assertion を作ります。

- `-i`: アイドルスリープを防ぐ
- `-m`: ディスクのアイドルスリープを防ぐ
- `-s`: システムスリープを防ぐ。AC 電源で動作している時のみ有効
- `-t`: assertion の有効期限（秒）。期限が切れると自動で解放される

`-d`（ディスプレイの消灯を防ぐ）もありますが、リモートから触るだけなら画面は寝ていてよいので付けませんでした。

やめたくなったらプロセスを殺すだけです。

```sh
$ pkill caffeinate
```

## 効いているか確認する

`pmset -g assertions` で、いま誰がどんな assertion を持っているかを一覧できます。

```sh
$ pmset -g assertions
Assertion status system-wide:
   PreventUserIdleSystemSleep     1
   PreventSystemSleep             1
   PreventUserIdleDisplaySleep    0
   ...

Listed by owning process:
   pid 57165(caffeinate): [0x000028d100018fd3] 00:09:15 PreventUserIdleSystemSleep named: "caffeinate command-line tool"
        Details: caffeinate asserting for 86400 secs
        Localized=THE CAFFEINATE TOOL IS PREVENTING SLEEP.
        Timeout will fire in 85845 secs Action=TimeoutActionRelease
   ...
```

見るところは 2 つです。

- 冒頭の「Assertion status system-wide」が種類ごとの現在値。`PreventUserIdleSystemSleep` が 1 なら、誰かがアイドルスリープを止めている
- 「Listed by owning process」には、どのプロセスが何の名目で assertion を持っているかと、残り秒数が並ぶ

自分で立てた caffeinate（pid 57165）が 86400 秒の assertion を持っているのを確認できました。

## 時系列で観察する

assertion が作られたり消えたりする瞬間は `pmset -g log` に残っています。

```sh
$ pmset -g log | grep -E "Assertion" | tail -5
2026-08-08 12:09:46 +0900 Assertions  PID 57165(caffeinate) Created PreventSystemSleep "caffeinate command-line tool" ...
2026-08-08 12:18:28 +0900 Assertions  PID 24550(chrome-headless-shell) Created NoDisplaySleepAssertion "Capturing" ...
2026-08-08 12:18:28 +0900 Assertions  PID 24550(chrome-headless-shell) Released NoDisplaySleepAssertion "Capturing" ...
```

眺めていて面白かったのは Chrome の headless プロセスの行です。スクリーンショットを撮る一瞬だけ「Capturing」という名前の NoDisplaySleepAssertion を立てて、すぐ手放していました。

ブラウザで動画を流している間にスリープしないのも同じ仕組みです。動画を再生しながら `pmset -g assertions` を実行すると、ブラウザのプロセスが一覧に現れます。冒頭の「動画を流しっぱなしにしておく」案は、結局この assertion をブラウザ経由で立てているだけでした。それなら caffeinate で直接立てるほうが確実です。

あと、ログには自分で立てた覚えのない 300 秒の caffeinate が定期的に現れては消えていました。手元で動いている何かの開発ツールが、作業中のスリープ防止に同じ手を使っているようです。

## ハマりどころ

- MacBook のフタを閉じると、caffeinate があってもスリープする。閉じたまま使うには外部ディスプレイと電源接続が必要（[Apple のサポートページ](https://support.apple.com/ja-jp/102384)）
- `-s` が効くのは AC 電源接続時だけ。バッテリー駆動で放置するなら `-i` が本体になる

## おわりに

- スリープさせたくないだけなら `caffeinate -ims -t <秒数>` で足りる。動画を流しっぱなしにする必要はなかった
- 効いているかは `pmset -g assertions`、立った・消えた履歴は `pmset -g log` で見える

逆に「なぜかスリープしない」を調べる時にも `pmset -g assertions` は使えそうです。犯人のプロセス名が名指しで出てくるので。
