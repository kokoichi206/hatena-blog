# [Shell] IFS を変えてセミコロンで文字列を分割する

## IFS とは
IFS とは Internal Filed Separator の略語であり、シェルの環境変数で設定されています。

### 現在の値確認
では実際に、現在設定されている IFS を確認してみます。

 
``` sh
# ubuntu: 
# bash: version 5.0.17(1)-release (aarch64-unknown-linux-gnu) 
$ echo $IFS

# mac: 
# zsh 5.8.1 (x86_64-apple-darwin21.0)
$ echo $IFS


```

目視では何も確認できませんが、mac の方は余計な改行が入ってるようにも見えます。  
そこで、次は 16 進数で表示させてみます。  
なおここでは `echo` 標準の改行を無視するため `-n` オプションをつけてます。

``` sh
# ubuntu: 
# bash: version 5.0.17(1)-release (aarch64-unknown-linux-gnu)
$ echo -n $IFS | od -ax
0000000

# mac: 
# zsh 5.8.1 (x86_64-apple-darwin21.0)
$ echo -n $IFS | od -ax
0000000   sp  ht  nl nul                                                
             0920    000a                                                
0000004
```

ubuntu の方は何も指定されておらず、mac の方は『スペース（sp, 20）』『水平タブ（ht, 09）』『改行（nl, 0a）』の 3 つが指定されていることが確認できました。

## IFS を変えてセミコロンで文字列を分割する
**目標**  
『複数の変数を 1 つの文字列として定義し、シェル内で再度配列として取得する。ただし、変数はスペースを含み得る。』

**達成方法例**  
ここでは表題にもあるように、IFS を変更しリストとして読み取る方法を使います。  
またシェルスクリプト内で使用する場合、続く動作に影響を与えないよう、実行前の値を保存しておき実行後に元に戻すのがベターです。

``` sh
# 分割したい文字列（;区切り）
line="hoge;pien;paon"

# 実行前の IFS の値を一時避難
OLD_IFS=$IFS

IFS=";"
# 文字列を配列に変換
lines=($line)
for a in "${lines[@]}"; do
    echo "$a"
done

# 実行前の IFS の状態に戻す
IFS=$OLD_IFS
```


## 参考
- [bash IFS split string into array [duplicate]](https://stackoverflow.com/questions/30807306/bash-ifs-split-string-into-array)

## おわりに
もっとスクリプト書けるようになりたいです。

