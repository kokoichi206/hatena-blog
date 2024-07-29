# kdoctor: Xcode requires to perform the First Launch tasks

kmm のセットアップ時、`kdoctor` を叩いたらタイトルのエラーが発生しました。

``` sh
❯ kdoctor
Environment diagnose (to see all details, use -v option):                                                                                       ─╯
[✓] Operation System
[✓] Java
[✓] Android Studio
[✖] Xcode
  ✖ Xcode requires to perform the First Launch tasks
    Launch Xcode and complete setup
```

[こちらの github の issue](https://github.com/Kotlin/kdoctor/issues/34) に従い、↓ のコマンドを叩くと解決しました！

``` sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```


## 環境

```
- PC
    - macOS version 13.0.1
    - Apple M1 chip
    - Memory 16 GB
- Android Project
    - android studio: Flamingo | 2022.2.1
    - compose: 1.4.0
    - kotlin: 1.8.20
    - agp: 7.4.2
```

