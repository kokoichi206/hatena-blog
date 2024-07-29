# ubuntu で wget がインストールできない

ubuntu で wget がインストールできない

## 環境

- ubuntu 20.0.4
- Raspberry Pi 4 Model B


```sh
$ cat /etc/os-release
NAME="Ubuntu"
VERSION="20.04.2 LTS (Focal Fossa)"
ID=ubuntu
...
$ uname -a
Linux ubuntu 5.4.0-1038-raspi #41-Ubuntu 
SMP PREEMPT Thu Jun 17 14:14:11 UTC 2021
aarch64 aarch64 aarch64 GNU/Linux
```

## 症状
`apt install`しても、wget が使えるようにならない

```sh
$ wget -h

Command 'wget' not found, but can be installed with:
sudo apt install wget

$ sudo apt install wget
...
wget is already the newest version (1.20.3-1ubuntu1).
0 upgraded, 0 newly installed, 0 to remove and 239 not upgraded.

$ wget -h

Command 'wget' not found, but can be installed with:
sudo apt install wget
```

インストールされてる判定なのに wget が反応しない

```sh
# wget は存在しない
$ ls /usr/bin/ | grep wget
```

## 解決方法
一度アンインストールしてから、再度インストールし直しました

```sh
$ sudo apt remove wget
$ sudo apt install wget

$ wget -h
GNU Wget 1.20.3, a non-interactive network retriever.
Usage: wget [OPTION]... [URL]..
...

# /usr/bin にも存在している
$ ls /usr/bin | grep wget
wget
```

なお上記手順は`sudo apt reinstall wget`と同じです

## おわりに
apt がうまくいかない時は、

- remove → install
- autoremove -y → install
- reinstall

などを試してみる習慣をつけようと思います
