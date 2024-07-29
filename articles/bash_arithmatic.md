# bash [[ 内での <,> は文字列比較になるよ

bash で変数の評価を行う際に `[[` をよく使うんですが、その中の `<`, `>` の意味を間違っていたがために、無駄に時間を使ってしまう事件がありました。  
（未来の自分を含めた）皆さんには変なところで躓いて欲しくないため、こちらにメモしておきます。

**[目次]**

- [時間ない人まとめ](#時間ない人まとめ)
- [[[ を使った評価について](#[[-を使った評価について)
  - [<, > の扱いについて](#<,->-の扱いについて)
- [ではどうするか](#ではどうするか)
  - [[ の時同様 -lt, -gt 等を使う](#[-の時同様--lt,--gt-等を使う)
  - [数値の表現 ((..)) を使う](<#数値の表現-((..))-を使う>)
- [リンク](#リンク)
- [おわりに](#おわりに)

## 時間ない人まとめ

```
- [[ は bash で拡張された色々な表現が使える
- <, > は文字列の辞書順の大小を表す
- 数値を比較したいとき
  - -gt, -lt 等を使う
  - [[..]] ではなく ((..)) を使う
```

## [[ を使った評価について

シェルスクリプトには、変数を比較するための**コマンド** `[` があります。  
これは `test` コマンドと同一であり、しばしば `if` と合わせて以下のように使用します。

```sh
# コマンド [ の戻り値が正常（0）かどうかを判断
if [ hoge = hoge ]; then echo same string; fi
same string

if [ 3 -eq 3 ]; then echo same integer; fi
same integer

# <, > は通常のリダイレクト等に解釈されるため使用不可
if [ 3 < 5 ]; then echo left is greater than right; fi
zsh: no such file or directory: 5
```

また、bash には `[[` という拡張された表現があるのですが、正規表現のマッチもできるため私はよくこちらを利用しています。

```sh
if [[ -n "$1" ]] && [[ -f "$1" ]]; then
    FILE="$1"
fi

if [[ "$line" =~ ^(\#+)([ ]+)([^\#]*) ]]; then
    block_level="$(echo -n "${BASH_REMATCH[1]}" | wc -c | xargs)"
    ...
fi
```

### <, > の扱いについて

こちらの表現で何気なく `<`, `>` を使ったところ、実行時エラーにならず処理が続いていきました。

```sh
if [[ 3 < 5 ]]; then echo left is greater than right; fi
left is greater than right
```

ぱっと見良さそうに見えますが、多くの人にとってこれは期待値とは異なる動きをします。

もうお分かりかと思いますが、実はこれは**文字列での辞書順の比較**になっています！

このことについて、マニュアルの [bash: \[\[ について](https://www.gnu.org/software/bash/manual/bash.html#index-_005b_005b)のページにはきちんと記載があります。

> Expressions are composed of the primaries
> described below in Bash [Conditional Expressions](<(https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html)>).

[こちらのコンディション](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html)を参考にすると、辞書式順序で比較する、と書いてあります。

> <pre>
> string1 < string2
>   True if string1 sorts before string2 lexicographically.
> string1 > string2
>   True if string1 sorts after string2 lexicographically.
> </pre>

```sh
if [[ 30 < 5 ]]; then echo left is greater than right; fi
left is greater than right
```

## ではどうするか

### [ の時同様 -lt, -gt 等を使う

先ほどの `[[` で[どう評価されるかの条件](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html)のページを見直すと、`-lt`, `-le`, `-gt`, `-ge` を使えばいいようです。

```sh
if [[ 30 -lt 5 ]]; then echo left is greater than right; fi
```

一応説明すると、以下のような略語になっている、と覚えるとはやいと思います。

- gt: Greater Than
  - \>
- lt: Less Than
  - \<
- gt: Greater than or Equal
  - \>=
- le: Less than or Equal
  - \<=

### 数値の表現 ((..)) を使う

[こちらのマニュアル](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html)を再度みてみると、`((` が使えそうです。

> `(( expression ))`
>
> The arithmetic expression is evaluated according to
> the rules described below (see[ Shell Arithmetic](https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html)).
> The expression undergoes the same expansions
> as if it were within double quotes,

この中では [Shell Arithmetic](https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html) という数式の表現が使えるとのことなので期待できそうです。  
（注意としては、表現が 0 **以外**のとき返り値 0 (false), それ以外の時は返り値が 1 (true) になる、ということです）

```sh
# 良さそう
if (( 30 < 5 )); then echo pien; fi
if (( 3**3 > 5 )); then echo pien; fi
pien

if (( 3 )); then echo hi; fi
hi
if (( 0 )); then echo hi; fi
```

最近の言語と同じ感覚で使えそうですね。

## リンク

- [bash: 3.2.5.2 Conditional Constructs](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html)
- [bash: \[\[ について](https://www.gnu.org/software/bash/manual/bash.html#index-_005b_005b)

## おわりに

bash のドキュメントをみるとなんでも書いてあるので申し訳なくなる（もっと仲良くなりたい）。  
bash 以外の移植性考えたら、なるべく `[[` とか `((` とか使わないほうがいいんだろうか。
