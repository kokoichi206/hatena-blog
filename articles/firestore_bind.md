# Kotlin で Cloud Firestore にアクセスする際の注意
Kotlin を使って Firebase の Cloud Firestore からデータを取得する際、データクラスのバインドでエラーが出たのでその解決策をメモしておきます。

[目次]

[:contents]

## クエリで取得したデータをクラスにバインドさせる
[Cloud Firestore でのクエリ](https://firebase.google.com/docs/firestore/query-data/queries?hl=ja)を元に、Firebase からデータを取得していました。

ただ Kotlin で扱う上でクラスで持っていた方が扱いやすいです。そこで、次のようにデータクラスにバインドさせます。


```kotlin
// あるコレクション以下の全てのデータ（メンバー情報）を取得
fun getMemberFromDB() {
    db.collection(collectionName)
        .get()
        .addOnSuccessListener { querySnapshot ->

            // 複数取得した行をループで回す
            for (document in querySnapshot) {

                // MemberPayload クラスにバインドする
                val userInfo = document.toObject(MemberPayload::class.java)
            }
        }.addOnFailureListener { exception ->
            // Do something when the query failed
        }
}
```

MemberPayload のデータクラスの定義について、気をつける点があったのでメモしておきます。

### MemberPayload のデータクラスの定義

#### データクラス定義の上手くいかない例

```kotlin
// PropertyName は、json などの key に使う値を入れる。
// ここでは Cloud Firestore に登録した際のフィールドのキー名を入れる
data class MemberPayload (
    @PropertyName("name_en") val name_en: String,
    @PropertyName("name_ja") val name_ja: String,
    @PropertyName("birthday") val birthday: String,
)
```

#### エラーメッセージ
このクラスでは、バインドのタイミングで次のようなエラーが出ます

```
E/AndroidRuntime: FATAL EXCEPTION: main
    Process: io.kokoichi.sample.sakamichiapp, PID: 24378
    java.lang.RuntimeException: Could not deserialize object. Class ~~~
    does not define a no-argument constructor. 
    If you are using ProGuard, make sure these constructors are not stripped
    ...
```

#### 解決策
データクラスのコンストラクタにはデフォルト値を設定する

```kotlin
data class MemberPayload (
    @PropertyName("name_en") val name_en: String? = null,
    @PropertyName("name_ja") val name_ja: String? = null,
    @PropertyName("birthday") val birthday: String? = null,
)
```

## おわりに
