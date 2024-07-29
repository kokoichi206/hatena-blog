# go で init 関数などが初期化される順番の整理

go で初期化処理を書くために `init` 関数を使っている方もいるかと思うのですが、呼び出される順番を 1 回正しく整理しておきたいと思います。

**[目次]**

```
* [まとめ](#まとめ)
* [1パッケージのみ](#1パッケージのみ)
  * [1ファイルのみ](#1ファイルのみ)
  * [複数ファイル](#複数ファイル)
  * [まとめ](#まとめ)
* [複数パッケージ](#複数パッケージ)
* [まとめ（再掲）](#まとめ（再掲）)
* [グローバル変数・init 関数について](#グローバル変数・init-関数について)
* [おわりに](#おわりに)
```

## まとめ

長くなったので先に結論をまとめておきます。

1. import してるパッケージの初期化
   - 複数のパッケージがある場合は、パッケージ名のアルファベット昇順に呼ばれる
   - **単一パッケージ内**での初期化の順番
     1. global 変数
         - **複数ファイル**がある場合は、**ファイル名のアルファベット昇順**に呼ばれる
         - **同一ファイル内**で複数ある場合は、**記載した順番**に呼ばれる
     2. init 関数
         - init 関数内での順番は、global 変数の時と同じ
2. main のパッケージの初期化
   - 『単一パッケージ内での初期化の順番』と同様
3. エントリーポイントとなる関数
    - `main()`

## 1パッケージのみ

まずは1つのパッケージのみ（ここでは main）の場合を考えます。

### 1ファイルのみ

最も簡単なケースとして、`main.go` だけを与えます。

``` go
package main

import (
	"fmt"
)

// init function
func init() {
	fmt.Println("main init")
}

func main() {
	fmt.Println("main")
}
```

この実行結果は予想通り『init 関数 → main 関数』となります。

``` sh
$ go run main.go
main init
main
```

では次に、グローバル変数を入れてみます。

``` go
package main

import (
	"fmt"
)

// global variable
var a = func() string {
	fmt.Println("main global variable")
	return "a"
}()

// init function
func init() {
	fmt.Println("main init")
}

func main() {
	fmt.Println("main")
}
```

実行してみます。

``` sh
$ go run main.go
main global variable
main init
main
```

この実行結果は『global 変数 → init 関数 → main 関数』となります。
つまり、**global 変数は init 関数よりも先に初期化される**ことがわかりました

global 変数は名前を変えて複数定義できますが、実は **`init()` 関数は同一パッケージ・同一ファイル内に複数記載できま**す。

``` go
package main
import "fmt"

// global variable
var m = func() string {
	fmt.Println("main global variable")
	return "m"
}()
var m2 = func() string {
	fmt.Println("main global variable2")
	return "m2"
}()

// init function
func init() {
	fmt.Println("main init")
}
func init() {
	fmt.Println("main init2")
}

func main() {
	fmt.Println("main")
}
```

実行してみます。

``` sh
$ go run main.go
main global variable
main global variable2
main init
main init2
main
```

**同一ファイル内に複数の init 関数（global 変数）がある場合は積まれた順番に呼ばれる**ことが分かりました。

### 複数ファイル

先ほどの `main.go` に加えて、次の `a.go`, `z.go` を main パッケージに記述します。

**a.go**

``` go
package main
import "fmt"
// global variable
var a = func() string {
	fmt.Println("main global variable a.go")
	return "a"
}()
func init() {
	println("main init a.go")
}
```

**z.go**

``` go
package main
import "fmt"
// global variable
var z = func() string {
	fmt.Println("main global variable z.go")
	return "z"
}()
func init() {
	println("main init z.go")
}
```

実行してみます。

``` sh
$ go run *.go
main global variable a.go
main global variable
main global variable2
main global variable z.go
main init a.go
main init
main init2
main init z.go
main
```

どうやら**アルファベット順**に呼ばれてるようです。

### まとめ

以上見てきた結果から、**単一パッケージ内において**以下の順番で呼び出されていることが確認できました。

1. global 変数
    - **複数ファイル**がある場合は、**ファイル名のアルファベット昇順**に呼ばれる
    - **同一ファイル内**で複数ある場合は、**記載した順番**に呼ばれる
2. init 関数
    - init 関数内での順番は、global 変数の時と同じ
3. エントリーポイントとなる関数
   - ここでは `main()`

## 複数パッケージ

パッケージ**内**での初期化の順番は把握できたので、次はパッケージ**間**の順番を考えます。

main パッケージに加えて2つのパッケージ（a, z）を用意してみます。
（あえてパッケージ名とファイル名を統一させてないです。）

**a/z.go**

``` go
package a
import "fmt"
var b = func() string {
	fmt.Println("a global variable")
	return "a"
}()
func init() {
	fmt.Println("a init")
}
```

**z/a.go**

``` go
package z
import "fmt"
var b = func() string {
	fmt.Println("z global variable")
	return "z"
}()
func init() {
	fmt.Println("z init")
}
```

この時点で以下のようなフォルダ構成になっています。

``` sh
$ tree
.
├── a
│   └── z.go
├── a.go
├── go.mod
├── main.go
├── z
│   └── a.go
└── z.go
```

`main.go` に以下のような blank import を加えます。

``` diff
import (
	"fmt"
+	_ "initialize-order/a"
+	_ "initialize-order/z"
)
```

実行してみます。

``` sh
$ go run *.go
a global variable
a init
z global variable
z init
main global variable a.go
main global variable
main global variable2
main global variable z.go
main init a.go
main init
main init2
main init z.go
main
```

**main パッケージよりも先**に import したパッケージの **global 変数・init 関数**が呼ばれました。
また import したパッケージが複数ある場合は、**パッケージ名のアルファベット昇順**に呼ばれるようです。
（**import の順番に依存しない**ことを確認しました。）

## まとめ（再掲）

1. import してるパッケージの初期化
   - 複数のパッケージがある場合は、パッケージ名のアルファベット昇順に呼ばれる
   - **単一パッケージ内**での初期化の順番
     1. global 変数
         - **複数ファイル**がある場合は、**ファイル名のアルファベット昇順**に呼ばれる
         - **同一ファイル内**で複数ある場合は、**記載した順番**に呼ばれる
     2. init 関数
         - init 関数内での順番は、global 変数の時と同じ
2. main のパッケージの初期化
   - 『単一パッケージ内での初期化の順番』と同様
3. エントリーポイントとなる関数
    - `main()`

## グローバル変数・init 関数について

ここまで散々調べておいて何ですが、グローバル変数・init 関数の使用は以下の理由から慎重になるべきだと考えます。

- 状態を保つためにはグローバル変数を使う必要がある
  - グローバル変数に依存する関数のテストが複雑になる
- エラーが返せないため panic などで異常終了させるしかない

とはいえ（[lib/pq](https://pkg.go.dev/github.com/lib/pq) といった）DB ドライバーの初期化に代表されるように、init を用いた方が良いケースもあることは覚えておきたいです。

## おわりに

初期化の手順を整理する中で、色々と面白い発見がありました。
グローバル変数・init 関数などは使い所を見極めて慎重になりたいです。
