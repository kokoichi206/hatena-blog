# openapi-generator の作る Go の構造体を使ったら json.Marshal が 10 倍遅くなった

openapi から Go のコードを生成するツールとしては、[oapi-codegen](https://github.com/deepmap/oapi-codegen), [ogen](https://github.com/ogen-go/ogen) などが勢いありますが、今回は [openapi generator](https://github.com/OpenAPITools/openapi-generator) にまつわる話をします。

このライブラリで**生成されたコードに起因して、json の Marshal が極端に遅くなって**しまう事件が発生しました。

**[目次]**

```
* [生成手順と生成コード](#生成手順と生成コード)
  * [MarshalJSON を削除してみた](#marshaljson-を削除してみた)
  * [遅くなってそうな原因](#遅くなってそうな原因)
* [openapi-generator の修正](#openapi-generator-の修正)
  * [ベンチマーク手順](#ベンチマーク手順)
  * [ベンチマーク結果](#ベンチマーク結果)
  * [Issue を立ててみた](#issue-を立ててみた)
  * [additional-properties に追加](#additional-properties-に追加)
  * [v7.1.0 を使ってみる](#v7.1.0-を使ってみる)
  * [v7.1.0 で UnmarshalJSON が遅くなってそう？](#v7.1.0-で-unmarshaljson-が遅くなってそう？)
* [おわりに](#おわりに)
```

## 生成手順と生成コード

以下のように、docker で cli を起動して生成しています。
（実験時の最新バージョンである v7.0.0 を使用。）

``` makefile
current_dir := $(shell pwd)

.PHONY: gen
gen: clear
	docker run --rm -v $(current_dir):/project openapitools/openapi-generator-cli:v7.0.0 \
		generate -i /project/openapi.yaml -g go \
		--additional-properties=packageName=component -o /project/gen/component -p enumClassPrefix=true

.PHONY: clear
clear:
	ls gen/component | xargs -n1 | grep -v ".openapi-generator" | xargs -I{} rm -r "gen/component/{}"
```

最終的には、以下のようなコードが生成されます（例）。

``` go
func (o Pet) MarshalJSON() ([]byte, error) {
	toSerialize,err := o.ToMap()
	if err != nil {
		return []byte{}, err
	}
	return json.Marshal(toSerialize)
}

func (o Pet) ToMap() (map[string]interface{}, error) {
	toSerialize := map[string]interface{}{}
	if !IsNil(o.Id) {
		toSerialize["id"] = o.Id
	}
	toSerialize["name"] = o.Name
	if !IsNil(o.PhotoUrls) {
		toSerialize["photoUrls"] = o.PhotoUrls
	}
	if !IsNil(o.Status) {
		toSerialize["status"] = o.Status
	}
	return toSerialize, nil
}
```

一般に、構造体を json に変換するときは [json#Marshaler](https://pkg.go.dev/encoding/json#Marshaler) のインタフェースが使われており、上記のように**各自で独自の MarshalJSON を実装することも可能**です。

実装しなくても基底型の Marshaler が使われることになるため、普段から意識することは少なく、実際今回も生成されてることを忘れていました。

### MarshalJSON を削除してみた

ある API の中で JSON の変換に時間がかかっており、さまざまなサードパーティ製のライブラリを探す中で MarshalJSON が余計なことをしてる説が浮上しました。

そこで、openapi-generator のつくる MarshalJSON を削除したものを用意し、単純に時間を比べてみました。

``` sh
# 19.3 MB の JSON で比較

# 特徴
# {
#  "total": 20000,
#  "result": [
#   {
#     "a": "ほげほげ",
#     "b": "aaa",
#     "date": "2021/01/27 01:04:48",
#     "highlight": [
#       "Xxx"
#     ],
#     "c": "59876"
#   },
#  ]
# }

# MarshalJSON 削除前（デフォルト）
average: 235 ms (num=10)

# 削除後
average: 37 ms (num=10)
```

**MarshalJSON がある状態とない状態（削除後）で 5 倍以上の差が**ついてしまってることがわかります。

もちろん構造体の性質・データ量にもよると思いますが、これほどの差が生まれてしまうとちょっとしんどいものがあります。。。

### 遅くなってそうな原因

MarshalJSON の実装の中で、string を key とする **interface** に詰め込んでました。
せっかく型情報を持っているのに**わざわざ any に落とす必要がなく**、最終的な Marshal 時に必要な情報が足りなくなることが想定されます。

## openapi-generator の修正

### ベンチマーク手順

[OpenAPI-Specification のだす petstore](https://github.com/OAI/OpenAPI-Specification/blob/78170608af208da8165ab095715e5cb9ff715f47/examples/v3.0/petstore.yaml) を対象にベンチマークテストを行いました。

``` sh
.
├── Makefile
├── gen
│   ├── component
│       └── .openapi-generator-ignore
│   └── component_method
│       └── .openapi-generator-ignore
├── go.mod
├── main_test.go
├── openapi.yaml
└── res.json
```

**手順**

1. [petstore.yaml](https://github.com/OAI/OpenAPI-Specification/blob/78170608af208da8165ab095715e5cb9ff715f47/examples/v3.0/petstore.yaml) を (openapi.yaml という名前で) 保存
2. 対象とする構造体の json を `res.json` として用意
3. `.openapi-generator-ignore` を指定パスに用意
4. docker コマンドを使って構造体のみ生成 (component と component_method の 2 つ)
5. **component パッケージの方から UnmarshalJSON, MarshalJSON を削除**
6. Benchmark テストを作成

<details><summary><code>.openapi-generator-ignore</code> の中身</summary>

```
api_*
client.go
configuration.go
.travis.yml

README.md
git_push.sh

go.mod
go.sum

api/
docs/

test/
```

</details>

<details><summary><code>res.json</code> の中身</summary>

今回は、実際に自分が遭遇したケースと比べて**かなり小さい JSON** で実験しました。

``` json
{
    "id": 111,
    "name": "Test name 111",
    "tag": [
        "test tag",
        "kawaii"
    ]
}
```

</details>

<details><summary>生成に使ったコマンド（Makefile）</summary>

``` makefile
current_dir := $(shell pwd)

.PHONY: gen
gen: clear
	docker run --rm -v $(current_dir):/project openapitools/openapi-generator-cli:v7.0.0 \
		generate -i /project/openapi.yaml -g go \
		--additional-properties packageName=component -o /project/gen/component -p enumClassPrefix=true

.PHONY: clear
clear:
	ls gen/component | xargs -n1 | grep -v ".openapi-generator" | xargs -I{} rm -r "gen/component/{}"

.PHONY: genm
genm: clearm
	docker run --rm -v $(current_dir):/project openapitools/openapi-generator-cli:v7.0.0 \
		generate -i /project/openapi.yaml -g go \
		--additional-properties packageName=component_method -o /project/gen/component_method -p enumClassPrefix=true

.PHONY: clearm
clearm:
	ls gen/component_method | xargs -n1 | grep -v ".openapi-generator" | xargs -I{} rm -r "gen/component_method/{}"

.PHONY: bench
bench:
	go test -bench .
```

</details>

<details><summary>ベンチマークテスト（<code>main_test.go</code>）</summary>

``` go
package main

import (
	"benchmark/gen/component"
	"benchmark/gen/component_method"
	"encoding/json"
	"os"
	"testing"
)

// ==================== Unmarshal ====================
func BenchmarkJsonUnMarshal(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var res component.Pet
		json.Unmarshal(bytes, &res)
	}
}

func BenchmarkJsonUnMarshalMethod(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var res component_method.Pet
		json.Unmarshal(bytes, &res)
	}
}

// ==================== Marshal ====================
func BenchmarkJsonMarshal(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")
	var res component.Pet
	json.Unmarshal(bytes, &res)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = json.Marshal(res)
	}
}

func BenchmarkJsonMarshalMethod(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")
	var res component_method.Pet
	json.Unmarshal(bytes, &res)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = json.Marshal(res)
	}
}
```

</details>

### ベンチマーク結果

``` sh
$ make bench
go test -bench .
goos: darwin
goarch: arm64
pkg: benchmark
BenchmarkJsonUnMarshal-8                 1000000              1464 ns/op
BenchmarkJsonUnMarshalMethod-8           1071717              1357 ns/op
BenchmarkJsonMarshal-8                   7063731               208.6 ns/op
BenchmarkJsonMarshalMethod-8             1000000              1126 ns/op
PASS
ok      benchmark       10.630s
```

実際の API で測定したレスポンスよりかなり小さい JSON でも同様に、**明らかなパフォーマンスの差**が確認できました。

### Issue を立ててみた

openapi-generator 起因でパフォーマンスが悪くなっていることが確認でき、また**この実装になってる原因も分からなかった**ため Issue を作成してみました（[Issue#16948](https://github.com/OpenAPITools/openapi-generator/issues/16948)）。
（OSS に Issue を立てるのが初めてだったため緊張しました。）

すると1日も経たないうちに

> カスタマイズされた MarshalJSON メソッドは、プロパティの oneOf/anyOf スキーマ、
> 追加プロパティ、nullableプロパティなどの usecase に対応するために追加されました。
> あなたのユースケースでこれらが必要ない場合、MarshalJSON メソッドの生成を
> スキップするオプションを追加するのはどうでしょうか？

とメンテナーの方から言われたため、オプションを追加してみることにしました。

### additional-properties に追加

openapi-generator の cli を使う時に [additional-properties を用いて生成内容をコントロールできる](https://openapi-generator.tech/docs/generators/go/)んですが、今回はそこに１つフラグを追加することにしました。

ベンチマークで UnmarshalJSON については差がなかったため、そちらの生成は残したままにすることにしました。

Java もマスタッシュ構文もわからない状況からだったんですが、なんとか [PR がマージ](https://github.com/OpenAPITools/openapi-generator/pull/16962)され、v7.1.0 にとり込まれました。

これにより、v7.1.0 では `generateMarshalJSON` フラグを false にすることで、MarshalJSON メソッドが生成されなくなります。

### v7.1.0 を使ってみる

新しく additional-properties を追加した v7.1.0 のバージョンを使って、同様の条件でベンチマーク比較してみます。

<details><summary>Makefile の追加</summary>

``` makefile
.PHONY: gen710
gen710: clear710
	docker run --rm -v $(current_dir):/project openapitools/openapi-generator-cli:v7.1.0 \
		generate -i /project/openapi.yaml -g go \
		--additional-properties generateMarshalJSON=false \
		--additional-properties packageName=component_710 -o /project/gen/component_710 -p enumClassPrefix=true

.PHONY: clear710
clear710:
	ls gen/component_710 | xargs -n1 | grep -v ".openapi-generator" | xargs -I{} rm -r "gen/component_710/{}"
```

</details>

<details><summary>Benchmark テストの追加（<code>main_test.go</code>）</summary>

``` go

func BenchmarkJsonUnMarshal710(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var res component_710.Pet
		json.Unmarshal(bytes, &res)
	}
}

func BenchmarkJsonMarshal710(b *testing.B) {
	bytes, _ := os.ReadFile("res.json")
	var res component_710.Pet
	json.Unmarshal(bytes, &res)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = json.Marshal(res)
	}
}
```

</details>

``` sh
$ make bench
go test -bench .
goos: darwin
goarch: arm64
pkg: benchmark
BenchmarkJsonUnMarshal-8                 1155070              1033 ns/op
BenchmarkJsonUnMarshalMethod-8           1206620              1010 ns/op
BenchmarkJsonUnMarshal710-8               374690              3348 ns/op
BenchmarkJsonMarshal-8                   7542001               176.8 ns/op
BenchmarkJsonMarshalMethod-8             1220074               988.1 ns/op
BenchmarkJsonMarshal710-8                8350143               123.1 ns/op
PASS
ok      benchmark       10.379s
```

BenchmarkJsonMarshalMethod (v7.0.0) と BenchmarkJsonMarshal710 (v7.1.0) に着目して比べると、1/8 ほどの実行時間になっていることがわかります。

### v7.1.0 で UnmarshalJSON が遅くなってそう？

ベンチマークをしてて思ったのですが、UnmarshalJSON が**３倍程度遅くなってそう**に見えます。

よくみてみると v7.1.0 で試した時は、構造体に以下のような UnmarshalJSON が追加されていました。


<details><summary>生成された UnmarshalJSON</summary>

``` go
func (o *Pet) UnmarshalJSON(bytes []byte) (err error) {
    // This validates that all required properties are included in the JSON object
	// by unmarshalling the object into a generic map with string keys and checking
	// that every required field exists as a key in the generic map.
	requiredProperties := []string{
		"id",
		"name",
	}

	allProperties := make(map[string]interface{})

	err = json.Unmarshal(bytes, &allProperties)

	if err != nil {
		return err;
	}

	for _, requiredProperty := range(requiredProperties) {
		if _, exists := allProperties[requiredProperty]; !exists {
			return fmt.Errorf("no value given for required property %v", requiredProperty)
		}
	}

	varPet := _Pet{}

	err = json.Unmarshal(bytes, &varPet)

	if err != nil {
		return err
	}

	*o = Pet(varPet)

	return err
}
```

</details>

これは [PR#16863](https://github.com/OpenAPITools/openapi-generator/pull/16863) により v7.1.0 から入った変更で、『**required がない時や anyOf が不適切な時などに validation エラーを吐く**』ためのものでした。

yaml のなかに AdditionalProperties がある場合などは、**構造体に生えてる UnmarshalJSON の中で json.UnmarshalJSON が 3 回も呼ばれており**、なんとか改善できるんじゃないかな〜と思ってますが、いい案は浮かんでません。

## おわりに

普通に使ってただけで JSON の取り扱いがめちゃくちゃ遅くなっててびっくりしましたが、**ライブラリの中が何をしてるかはきちんと理解しないとダメだなと思いました**。

nullable 属性の扱い方などはありますが、大きいレスポンスを扱う API 等では使ってみてください。
