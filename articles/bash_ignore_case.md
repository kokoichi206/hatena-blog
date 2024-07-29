# bash 大文字小文字を無視して比較したい

bash の文字列比較において、大文字と小文字を区別して比較する方法のメモです。

**[目次]**

[:contents]


## **bash のパラメータ展開**の文字列操作

bash のパラメータ展開を利用したければ、マニュアルの [3.5.3 Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) に記載があります。

大文字小文字変換には、以下の 4 つが使えそうです。

- `${parameter^pattern}`
- `${parameter^^pattern}`
- `${parameter,pattern}`
- `${parameter,,pattern}`

> The '^^' and ',,' expansions convert each matched character in the expanded value; the '^' and ',' expansions match and convert only the first character in the expanded value.
> If pattern is omitted, it is treated like a '?', which matches every character.

`^^` や `,,` は、マッチした各文字をそれぞれ大文字/小文字に変換します。`^` と `,` はそれぞれ最初の 1 文字を大文字/小文字に変換します。

`pattern` が省略された場合、任意の１文字にマッチする `?` が指定されたのと同様の扱いになります。

つまり、例えば全文字を小文字に変換するには、`${parameter,,}` としたら良さそうです。

```sh
$ bash --version
GNU bash, version 5.0.17(1)-release (aarch64-unknown-linux-gnu)

$ a=AArch
$ echo $a
AArch

$ echo ${a,,}
aarch
$ if [ ${a,,} = "aarch64" ]; then echo "matched"; fi
matched

# 他の例
$ echo ${a^^c}
AArCh64
$ echo ${a^^[d-z]}
AARcH64
```

### zsh にはない？

上記パラメータ展開を mac の zsh で試したところ失敗した。
ポータビリティを考えるとあんまり良くないかもしれない。

```sh
$ zsh --version
zsh 5.8.1 (x86_64-apple-darwin21.0)

$ echo ${a,,}
zsh: bad substitution
```

## sed で大文字小文字

GNU 拡張ありの sed の場合は以下のように簡潔にかける。

```sh
$ sed --version
sed (GNU sed) 4.7

$ echo $a | sed -e "s@\(.*\)@\L\1@"
aarch64

# 先頭のみ大文字、これはいい！
$ echo $a | sed -e "s@\(.\)\(.*\)@\U\1\L\2@"
Aarch64
```

sed に依存しており、mac では使えない。

## tr で変換

```sh
$ tr --version
tr (GNU coreutils) 8.30

$ echo $a | tr A-Z a-z
aarch64
$ if [ "$(echo $a | tr A-Z a-z)" = "aarch64" ]; then echo "matched"; fi
matched
```

悪くなさそうだけど拡張性は低いかも。

## awk でパターンマッチ

```sh
$ awk --version
GNU Awk 5.0.1, API: 2.0 (GNU MPFR 4.0.2, GNU MP 6.2.0)

$ echo $a | awk 'tolower($0) ~ /^aarch64$/ {print "matched"}'
```

これがなんだかんだ一番ポータビリティ性あって拡張性も高いかも？
