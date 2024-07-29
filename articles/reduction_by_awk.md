# AWK で約分をやってみた

[:contents]


## AWK で約分
**方針：**

1. 素因数分解して、分子の素因数は +1, 分母は -1 とカウントして、AWK の連想配列に突っ込む
2. 最終結果として、a[] の値がプラスのものはその数だけ分子に、マイナスのものは分母にもっていく

(例) 6/8 を約分してみる

```sh
$ echo 6/8 | tr '/' '\n' | factor |\
 awk 'NR == 1{for(i=2; i<=NF; i++){a[$i] += 1}} NR == 2{for(i=2; i<=NF; i++){
a[$i] -= 1}} END{for(b in a){print b, a[b]}}'
2 -2
3 1

$ echo 6/8 | tr '/' '\n' | factor |\
 awk 'NR == 1{for(i=2; i<=NF; i++){a[$i] += 1}} NR == 2{for(i=2; i<=NF; i++){a[$i] -= 1}} END{nume = 1; deno = 1; for(b in a){if (a[b] > 0){nume *= b**a[b]} else if (a[b] < 0){deno *= b**(-1*a[b])}} {print nume"/"deno}}'
3/4
```


ただしこのままでは、1/1 と表示されてしまうため、分母が一の時はもうひと手間加える

```sh
$ (上のワンライナー) | awk -F'/' '{print ($2 == 1)? $1: $1"/"$2}'
```


AWK では上のように三項間演算子が使えます。

## （おまけ）ruby, python なら一瞬

```sh
# ruby の Rational クラスを使う
$ ruby -e 'puts 6r/8r'
3/4
$ echo 6/8 | sed -E 's@(.)/(.)@puts \1r/\2r@g' | ruby
3/4

$ python3 -c "from fractions import Fraction; print(Fraction(5, 15))"
1/3
$ echo 6/8 | sed -E 's@(.)/(.)@from fractions import Fraction; print(Fraction(\1,\2))@' | python3
3/4
```

## おわりに
AWK 以外でターミナルで約分できるよーとかあったら教えてください。

また、計算方法的にも別解があれば知りたいです。
