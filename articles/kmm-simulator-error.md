# CoreSimulator.framework was changed while the process was running.

kmm のセットアップ時、iOS をビルドしようとしたらタイトルのエラーが発生しました。

```shell
CoreSimulator.framework was changed while the process was running.
This is not a supported configuration and can occur if Xcode.app was updated while the process was running.
Service version (885.2) does not match expected service version (857.13).
```

[こちら](https://youtrack.jetbrains.com/issue/KT-52228) に従い、PC を再起動すると解決しました！

## 環境

```
- PC
    - macOS version 13.0.1 (mac mini)
    - Apple M1 chip
    - Memory 16 GB
- Android Project
    - android studio: Flamingo | 2022.2.1
    - compose: 1.4.0
    - kotlin: 1.8.20
    - agp: 7.4.2
```
