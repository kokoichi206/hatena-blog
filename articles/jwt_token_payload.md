# JWT トークンのペイロードをターミナル上で確認する

## JWT トークンの構成

JWT トークンとは、以下のような eyJ から始まるトークンのことです。

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwbHFQUTBkdHZpaEtWczI4T0dPVjg4eUZ0bnQwIiwibmFtZSI6Imtva29pY2hpMjA2IiwiaWF0IjoxNzE2OTkxNzU3LCJleHAiOjE3MTY5OTUzNTcsInVzZXJfcm9sZSI6Im9wZXJhdG9yIiwiY29tcGFuaWVzIjpbImEiLCJiIl0sImVtYWlsIjoia29rb2ljaGkyMDZAZXhhbXBsZS5jb20ifQ.cpsYjKAM_YQksiTCV0EheKTM4oo47RYruUXzZYLn-7M
```

`.` 区切りで3部の構成となっており（eyJxxx.yyyy.zzz のような形式）、それぞれ json の Header, Payload, Signature を base64 エンコードしたものとなっております。  
（通常の base64 エンコードではなく、**最後の = 部分が取り除かれている**ことに注意。）

特に Payload 部分は claims とも呼ばれており、カスタマイズした項目を入れることが可能です（[Firebase の例](https://firebase.google.com/docs/auth/admin/custom-claims#set_and_validate_custom_user_claims_via_the_admin_sdk)）。

今回はこの部分のみを抜き出して元の json を取り出してみます。

ちなみに `eyJ` とみたら `{"a` くらいが予想され、JWT token の可能性が出てきます。

``` sh
$ echo { | base64   
ewo=
$ echo '{"' | base64
eyIK
$ echo '{"a' | base64
eyJhCg==
```

## ペイロードの取り出し

先ほど軽く触れたように **base64 エンコードから最後の = 部分が取り除かれている**ため、復元する時には逆にそれをつけてあげる必要があります。

``` sh
# base64 エンコードされた文字列は4の倍数であるため、そうなるように = を付与している
$ echo $jwt | awk -F. '(l = length($2)){printf $2} END {if (l%4 != 0) {for(i=1; i<=(4-l%4); i++){printf "="}}}' | base64 -d | jq

{
  "sub": "plqPQ0dtvihKVs28OGOV88yFtnt0",
  "name": "kokoichi206",
  "iat": 1716991757,
  "exp": 1716995357,
  "user_role": "operator",
  "companies": [
    "a",
    "b"
  ],
  "email": "kokoichi206@example.com"
}
```

適当に `.zshrc` などに追加してあげると、関数として便利に呼び出すことも可能です。

``` sh
# .zshrc などに追記
jwt-claims () {
        awk -F. '(l = length($2)){printf $2} END {if (l%4 != 0) {for(i=1; i<=(4-l%4); i++){printf "="}}}' | base64 -d
}
```

``` sh
# 呼び出し方
$ echo $jwt | jwt-claims | jq
{
  "sub": "plqPQ0dtvihKVs28OGOV88yFtnt0",
  "name": "kokoichi206",
  "iat": 1716991757,
  "exp": 1716995357,
  "user_role": "operator",
  "companies": [
    "a",
    "b"
  ],
  "email": "kokoichi206@example.com"
}
```
