`./gradlew lintDebug` で気になったところまとめ  
（2022/11/05 版）

## 環境

```sh
./gradlew --version

------------------------------------------------------------
Gradle 7.4
------------------------------------------------------------

Build time:   2022-02-08 09:58:38 UTC
Revision:     f0d9291c04b90b59445041eaa75b2ee744162586

Kotlin:       1.5.31
Groovy:       3.0.9
Ant:          Apache Ant(TM) version 1.10.11 compiled on July 10 2021
JVM:          17.0.2 (Azul Systems, Inc. 17.0.2+8-LTS)
OS:           Mac OS X 12.4 aarch64
```

## drawable-v24 はいらない

ある一定の sdk 以上を対象とするアプリにおいては、`v24` 系のごちゃごちゃしたフォルダ・ファイルは不要なようです。

```
This folder configuration (`v24`) is unnecessary;
`minSdkVersion`is 26. Merge all the resources
in this folder into`drawable`
```
