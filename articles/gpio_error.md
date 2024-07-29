# gpio のアップデート手順で the package is missing,  has been obsoleted のエラー

gpio のバージョンをアップデートしようとした際に次のようなエラーで詰まったので、解決策についてメモしておこうと思います。

## 環境

- ubuntu 20.0.4
- Raspberry Pi 4 Model B

## エラー内容
```sh
$ sudo apt install libc6:armhf libgcc1:armhf
Reading package lists... Done
Building dependency tree
Reading state information... Done
Package libc6:armhf is not available, 
but is referred to by another package.
This may mean that the package is missing,
 has been obsoleted, or
is only available from another source
However the following packages replace it:
  libdb1-compat libcrypt1

E: Package 'libc6:armhf' has no installation candidate
E: Unable to locate package libgcc1:armhf
```

## 解決方法
依存関係に問題があることが原因なようで、次のような手順で解決できました。

```sh
# パッケージのキャッシュを消去する
$ sudo apt clean
$ sudo apt update
# 壊れた依存性の解決
$ sudo apt -f install

# 再度コマンドを実行する
$ sudo apt-get install libc6:armhf libgcc1:armhf
```

## 参考サイト
- [アップデートを進める際に参考にしたサイト](https://kunolog.com/raspberrypi4_ubuntu2004_gpio/)
- [エラーの解決策を見つけたサイト](https://askubuntu.com/questions/1079797/how-do-i-fix-an-error-with-libc6-dev-armhf-cross-in-ubuntu-18-04-when-trying-to)

## おわりに
今回の手順は行うことで特に悪い影響が出るようなものでもないと思うで、次回からインストールで詰まった際にはやってみます。
