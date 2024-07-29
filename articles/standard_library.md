# もっとよく標準パッケージを使おう！

これは自戒を込めてになるんですが、もっとよく標準パッケージを使おう（知ろう）という話です。

なければ探す。

例をいくつかあげてみます。

## URL Encode

基本的な言語には、URL エンコード・デコードをするための標準ライブラリがあるはずです。

### Bad

```kotlin
val encoded = path
    .replace("/", "%2F")
    .replace("?", "%3F")
```

### Good

```kotlin
val encoded = Uri.encode(name)
```

## File Path 結合

同じく基本的な言語には、Path や URL を結合する標準ライブラリがあるはずです。

### Bad

```go
var fullPath := fmt.Sprintf("%s/%s", "dir", "file")
```

### Good

OS の区切り文字が出力されるので、windows, UNIX 系のどちらでも同じように記述できます。

```go
var fullPath := filepath.Join("dir", "file")
```

また、path に間違って `/` 等がついていても安心です。

```go
dir := "dir/"
file := "/file"
// dir/file
var fullPath := filepath.Join(dir, file)
```

## おわりに

紹介しきれてないものもたくさんありますが、基本的な機能は標準パッケージにあるので、そのつもりで探すことが大切だと思っています。

標準パッケージを使った方が、安全で読みやすいです。  
絶対に使っていきましょう。
