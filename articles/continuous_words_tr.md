# 連続する文字を tr で削除する

`tr`の`-s`オプションを利用すると、「**連続するN文字を１文字にすること**」が可能です

例を見てみます


## 基本的な使い方
``` bash
$ echo pieeeeeen
pieeeeeen

# tr -s "変換を行いたい文字"
$ echo pieeeeeen | tr -s e
pien
```

## 無駄に多い改行を削除
また次の例では、入れすぎた改行を削除することを行なっています。

``` bash
# 無駄な改行が多い
$ echo -e "pi\n\n\n\n\nen"
pi




en

# 連続する改行を１つにまとめる
$ echo -e "pi\n\n\n\n\nen" | tr -s "\n"
pi
en
```

## アルファベット以外で連続するものは削除
tr でアルファベット一般を表すには、`[:alpha:]`とします。

``` bash
$ echo -e "my\n\n\n\nknee" | tr -s "[:alpha:]"
my



kne 
```

これだとアルファベット**のみ**が対象になってしまうので、アルファベット**以外**を表すために、`-c`オプション（complement set：補集合）をつけてあげます

``` bash
$ echo -e "my\n\n\n\nknee" | tr -sc "[:alpha:]"
my
knee
```

今回アルファベット一般を表すために`[:alpha:]`という表現を用いましたが、そのほかの文字クラスについては以下を参考にしてください。

``` bash
$ man tr
...
[:class:]  Represents all characters belonging to 
the defined character class.  Class names are:
    alnum        <alphanumeric characters>
    alpha        <alphabetic characters>
    blank        <whitespace characters>
    cntrl        <control characters>
    digit        <numeric characters>
    graph        <graphic characters>
    ideogram     <ideographic characters>
    lower        <lower-case alphabetic characters>
    phonogram    <phonographic characters>
    print        <printable characters>
    punct        <punctuation characters>
    rune         <valid characters>
    space        <space characters>
    special      <special characters>
    upper        <upper-case characters>
    xdigit       <hexadecimal characters>
...
```

たとえば、大文字を小文字に変換するには以下のようにします

``` bash
$ echo pien | tr "[:lower:]" "[:upper:]"
PIEN

# この方法でも可能
$ echo pien | tr "[a-z]" "[A-Z]"
PIEN
# こっちの方が拡張性は高い
$ echo pien | tr "[a-e]" "[A-E]"
piEn
```

他にも参考になりそうな部分は多いので、`[:class:]`の部分は一度眺めておくといいかもしれません。



## マニュアルページ
`-s`オプションの部分は一応読んでおきます

``` bash
$ man tr
...
-s  Squeeze multiple occurrences of the characters 
    listed in the last operand (either string1 or string2) 
    in the input into a single instance of the character. 
    This occurs after all deletion and translation is completed.
...
```

