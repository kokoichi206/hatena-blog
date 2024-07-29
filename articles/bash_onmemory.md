# bash スクリプトはオンメモリにならない？

[目次]

[:contents]

## 環境
```
- Machine: Raspberry Pi 4 Model B Rev 1.4
- OS: Linux ubuntu 5.4.0-1045-raspi
- Bash version: GNU bash 5.0.17(1) aarch64
```

## オンメモリ
プログラムの実行計画を全てメモリ上に書き出し、随時ハードディスクから読み込まれないようにすることを言います。

メモリ使用は増えますが、ディスクへのアクセスが減るため、実行速度は向上する傾向にあります。

そのため、オンメモリの挙動においては、途中でファイルを上書きしても、再起動しない限り挙動はもとのままであることが期待されます。


## bash で検証
bash の実行が完全なオンメモリではないことを確認してみます。

まず、以下の２ファイルを用意します。

**test.sh**

メインの実行ファイル。内部で他の実行ファイルを読んでいます。最初の sleep の間にファイルを変更します（必要に応じて時間は伸ばしてください）。

``` sh
#!/bin/bash

echo "script start"

sleep 15

echo "test"
# サブファイル(echo_script.sh)を実行する
bash ./echo_script.sh
```

**echo_script.sh**

``` sh
#!/bin/bash

echo "Echo from another script file"
```

### メインファイル(test.sh)の中身を変更する
最初の `sleep` の間に、メインファイルの中身を次のように変更してみます。

この時、実行中のファイルは止めずに、別タブなどから編集するようにしてください。

``` sh
#!/bin/bash

echo "script start"

sleep 15

echo "new test"   # 変更した！
# サブファイル(echo_script.sh)を実行する
bash ./echo_script.sh
```

この時の出力は以下のようになります

``` sh
$ bash test.sh
script start
test
Echo from another script file
```

変更は反映されておらず、出力は`test`のままとなっています。

どうやら、メインファイル内に直接記述した`echo`などのコマンドに関しては、実行時に読み込まれてそうです。

### サブファイル(echo_script.sh)の中身を変更する
次に、最初の `sleep` の間に、サブファイルの中身を次のように変更してみます。

``` sh
#!/bin/bash

echo "new Echo from another script file"
```

この時の出力は以下のようになります

``` sh
$ bash test.sh
script start
test
new Echo from another script file
```

`sleep`の間に行った変更が反映されており、`bash ./echo_script.sh`による出力が`new Echo from another script file`となっています。

どうやら、実行ファイルから呼び出した、別 script に関しては、実行時に中身の読み込みまでは行われてないようです。

## おまけ：python で検証
**py_test.py**

``` python
import time
import py_echo

time.sleep(15)
print("test")
py_echo.echo()
```

**py_echo.py**

``` python
def echo():
    print("hi")
#    print("new")
```

python においてはどちらのファイルを変更した際も実行結果が変わることはなく、オンメモリに乗ってるような挙動を確認できました。

## 終わりに
今回は「bash スクリプトはオンメモリになっていない」ような挙動を確認しました。

なかなか普段見ない挙動だったので、意識しないとやらかしそうだな、と思いました。頭の片隅に置いておきます。
