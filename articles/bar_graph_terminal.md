# ワンライナーで棒グラフを作る
ダウンロード時などに、進捗を表すグラフをターミナルでも見かけることが多く、「自分でもグラフっぽいの作れるんじゃないか！」と思ったので作ってみました


## 棒グラフを作ってみた
具体的には、二列のデータ（二列目は数値）から以下のようなグラフを作ることが目標です。


<figure class="figure-image figure-image-fotolife" title="terminal_graph">[f:id:kokoichi206:20211216231741p:plain]<figcaption>terminal_graph</figcaption></figure>


### 方針
1. ターミナルからはみ出ては困るので、まず MAX の長さを決める
2. 二列目の数値が最大のものをその長さに合わせる
3. 他の値は最大のものとの相対比で決める

### 実装
``` sh
# file のフォーマット: ラベル 値
$ cat hoge
0.3 6
0.4 21
0.5 142
0.6 693
0.7 1931
0.8 3875
0.9 5342
1 5403
1.1 3773
1.2 1955
1.3 678
1.4 152
1.5 26
1.6 3

$ cat hoge |\
awk -v i=1 -v max_length=60 -v shape="□" '{b[i]=$1; a[i]=$2; i=i+1; if($2 > max){max = $2}}
END{for(j=1; j<=length(a); j++){printf "%1.2f: ", b[j]; for(k=0; k<int(max_length*a[j]/max); k++){printf shape}{printf "\n"}}}'
```

変数の説明

- max：二列目の数値の最大値
- 配列 b：一列目の値
- 配列 a：：二列目の値

注意点：最終結果の出力を、１列目の値を少数２桁で表示しています（`printf "%1.2f: ", b[j];` の部分）。ここは適宜必要に応じて変更してください。

### 写真と同じものを作るには
前半三行に関しては、前回解説をしてますのでよろしければご覧ください。ガウシアンニ従う離散分布を出力しています。



[https://koko206.hatenablog.com/entry/2021/05/19/110005:title]



``` sh
cat /dev/urandom | LANG=C tr -dc 0-9 | fold -w 5 | sed 's@^@0.@' | xargs -n 12 2>/dev/null | head -n 2000 | \
awk '{for(i=0; i<=int(NF) ;i++){{if(i==0){a = 0}else{a += $i}}{if(i == NF){print 2*a/NF}}}}' |\
awk -v g=4 '{print substr(g*$0,1,3)/g}' | sort | uniq -c | awk '{print $2,$1}' |\
awk -v i=1 -v max_length=60 -v shape="□" '{b[i]=$1; a[i]=$2; i=i+1; if($2 > max){max = $2}}
END{for(j=1; j<=length(a); j++){printf "%1.2f: ", b[j]; for(k=0; k<int(max_length*a[j]/max); k++){printf shape}{printf "\n"}}}'
```

## おわりに
こういう何の生産性も上がりそうにないことを考えている時間が一番楽しいです。

## おまけ：何となくスクリプト書きました
と思ったら、ワンライナーじゃなくなりました

``` sh
#! /bin/bash -
# 
# Make a graph from a data file.
#
# Usage: bash ./graph.sh FILE
#   FILE format: label value
#

usage()
{
    echo "Usage: $PROGRAM [OPTION] FILE"
    echo "  -c, --average-count"
    echo "      average counts"
    echo "  -h, --help, -help"
    echo "      print manual"
    echo "  -l, --max-length"
    echo "      max length of the graph"
    echo "  -s, --shape"
    echo "      shape of the graph" 
}

usage_and_exit()
{
    usage
    exit $1
}

AVERAGE_COUNT=12
MAX_LENGTH=60
SHAPE="■"
PROGRAM=`basename $0`

for i in "$@"; do
    case $i in
    -c | --average-count)
        if [[ -z "$2" ]] || [[ ! "$2" =~ [0-9]+ ]]; then
            echo "option requires an integer -- $1"
            usage_and_exit 1
        fi
        AVERAGE_COUNT="$2"
        shift 2
        ;;
    -h | --help | -help)
        usage_and_exit 0
        ;;
    -l | --max-length)
        if [[ -z "$2" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
            echo "option requires an integer -- $1"
            usage_and_exit 1
        fi
        MAX_LENGTH="$2"
        shift 2
        ;;
    -s | --shape)
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo "option requires an argument -- $1"
            usage_and_exit 1
        fi
        SHAPE="$2"
        shift 2
        ;;
    -*)
        echo "Unknown option $1"
        usage_and_exit 1
        ;;
    *)
        if [[ ! -z "$1" ]] && [[ -f "$1" ]]; then
            FILE="$1"
            shift 1
        fi
        ;;
    esac
done

if [[ "$FILE" ]] ; then
    cat "$FILE" |\
    awk -v i=1 -v max_length="$MAX_LENGTH" -v shape="$SHAPE" \
    '{b[i]=$1; a[i]=$2; i=i+1; if($2 > max){max = $2}}\
    END{print " "shape"~"int(10*max/max_length)/10; \
    for(j=1; j<=length(a); j++){printf "%1.2f: ", b[j]; \
    for(k=0; k<int(max_length*a[j]/max); k++){printf shape}{printf "\n"}}}'
else
    echo "file $1 does NOT exist"
    usage_and_exit 1
fi
```
