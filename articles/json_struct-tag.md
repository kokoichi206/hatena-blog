# go の標準パッケージ json がどのようにタグを解釈するかを理解し、独自のタグを設定してみる

json パッケージが最終的に [Tag を解釈しているところ](https://go.dev/src/encoding/json/encode.go#1116:~:text=tag%20%3A%3D%20sf.Tag.Get%28%22json)までに、以下のような関数呼び出しが発生します。

```
Marshal > marshal > reflectValue > valueEncoder >
typeEncoder > newTypeEncoder > newStructEncoder > cachedTypeFields > typeFields
```

## StructTag

json パッケージにおいて Tag の管理は [reflect#StructTag](https://pkg.go.dev/reflect#StructTag) が行なっています。

json パッケージで tag を解釈するまでの流れを、超完結にして実装してみました！

``` go
type Cat struct {
	Name string `cat:"name,required"`
	Age  int    `cat:"age"`
}

func main() {
	c := Cat{
		Name: "Tom",
		Age:  3,
	}

	parse(c)
}

func parse(v any) {
	rv := reflect.ValueOf(v)
	fmt.Printf("rv.Type(): %v\n", rv.Type())

	t := rv.Type()

	switch t.Kind() {
	case reflect.Struct:
		fmt.Println("v is a struct")
		parseType(t)
	}
}

func parseType(t reflect.Type) {
	for i := 0; i < t.NumField(); i++ {
		fmt.Printf("field %d: %v\n", i, t.Field(i))

		sf := t.Field(i)
		// 埋め込みフィールドかどうか。
		if sf.Anonymous {
			t := sf.Type
			if t.Kind() == reflect.Pointer {
				t = t.Elem()
			}
			if !sf.IsExported() && t.Kind() != reflect.Struct {
				continue
			}
		} else if !sf.IsExported() {
			// 非公開フィールドはスキップ。
			continue
		}
		tag := sf.Tag.Get("cat")
		if tag == "-" {
			continue
		}
		tagName, opts := parseTag(tag)
		fmt.Printf("tagName: %v\n", tagName)
		fmt.Printf("opts: %v\n", opts)
	}
}

type tagOptions string

// 1つ目のタグを必須、それ以降をオプションとして扱う。
// 例) a,b,c => 'a' + 'b,c'
func parseTag(tag string) (string, tagOptions) {
	tag, opt, _ := strings.Cut(tag, ",")
	return tag, tagOptions(opt)
}

// options に関しては、個別で扱うことはせずに『含む』or『含まない』のみを扱う。
func (o tagOptions) Contains(optionName string) bool {
	if len(o) == 0 {
		return false
	}
	s := string(o)
	for s != "" {
		var name string
		name, s, _ = strings.Cut(s, ",")
		if name == optionName {
			return true
		}
	}
	return false
}
```

実際には同一の型で何回もリフレクション等をしなくてもいいようにキャッシュしたりしています。

## tag の使いどき

tag を有意義に使ってる例としては、標準の json パッケージや ORM である gorm があると思います。

共通して当てはまることといえば次の性質でしょうか。

- クライアントによって独自の型を受け付ける必要がある
- Go の概念（構造体）と外の概念（json, db schema など）で別の名前で定義したい
- バリデーションなどをフィールドによって使い分けたい

自分でライブラリやフレームワークを開発する際に、ユーザーに対して柔軟な設定やカスタマイズを提供したい場合に特に有効そうです。
