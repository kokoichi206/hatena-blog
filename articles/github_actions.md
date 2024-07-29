# github actions で署名付きビルドをする際にハマったこと(gradle.properties & github actions)

Android で apk ファイルの署名付きビルドを行ったのですが、その際に少しハマったのでその点についてメモしておこうと思います

[目次]

[:contents]

## アプリレベルの build.gradle の記述
メインとなる build.gradle の記述を記載しておきます。

以下のように記述することで、CI ビルド時には環境変数（secrets）から、ローカルビルド時には gradle.properties の記述から keystore の設定値読み取るようにしています。

```
android {
    defaultConfig {
        ...
    }
    signingConfigs {
        release {
            storeFile file('release.keystore') // 指定パスに配置
            storePassword System.getenv('KEYSTORE_PASSWORD') ?: RELEASE_STORE_PASSWORD
            keyAlias System.getenv('KEY_ALIAS') ?: RELEASE_KEY_ALIAS
            keyPassword System.getenv('KEY_PASSWORD') ?: RELEASE_KEY_PASSWORD
        }
    }
    buildTypes {
        release {
            // ここの記述を忘れないようにする
            signingConfig signingConfigs.release
        }
        debug {
        }
    }
```

## ハマったこと

### gradle.properties の記述は ' や " がいらない！
gradle.properties の記述には、文字列に対してつけるような「' （シングルクォーテーション）」や「" （ダブルクォーテーション）」は不要です。

```
RELEASE_STORE_PASSWORD=store_password_with_no_quote
RELEASE_KEY_ALIAS=alias_with_no_quote
RELEASE_KEY_PASSWORD=password_with_no_quote
```

上記を例えば下のように、文字列のような記述をすると、"a bad key is used during decryption."のようなエラーが出ます。

```
RELEASE_STORE_PASSWORD='store_password_with_singlequote'
RELEASE_KEY_ALIAS="alias_with_doublequotes"
RELEASE_KEY_PASSWORD="password_with_doublequotes"
```

苦しめられたエラー

```
Given final block not properly padded. 
Such issues can arise if a bad key is used during decryption.
```

gradle.properties の他の箇所で、「"」で囲んでる部分があったので、発見が遅れてしまいました。。。


### signingConfigs の記述をしたのにビルドできない
keystore の生成を行った後に signingConfigs の記述をしたのにも関わらず、app の部分が赤いままでビルドできず以下のようなエラーが発生しました。

```
Error: The apk for your currently selected variant (xxx) is not signed. 
Please specify a signing configuration for this variant (release).
```

signingConfig の設定をビルドの設定に指定してあげる必要がありました！

``` gradle
android {
    signingConfigs {
        release {
            ...
        }
    }
    buildTypes {
        release {
            // ここの記述を忘れないようにする
            signingConfig signingConfigs.release
        }
        debug {
        }
    }
```



### Actions で secrets が読み取れない
しっかりドキュメントを読んでなかったからかと思われるのですが、環境変数が全く読み込めない事態が発生しました。

environment を設定したら読み込めるようになりました。

environment の値は`settings > Environments`から作成した値（読み込みたいキーが入っているもの）とします。

``` yaml
jobs:
  build:
    environment: production
    steps:
      - name: Check out
        uses: actions/checkout@v2
      ...
```


### Actions で keystore ファイルが見つからない
Actions で署名付きビルドを行う際は、Github actions の environment secrets を使ってキーを保存します。

keystore の値は、文字列として保存するために一旦 base64 変換をかけています。

``` sh
# ここで出力される値を、environment/secrets に保存する
$ cat release.keystore | base64
```

その上で、環境変数から読み取った後に、`-d`で decrypt してあげて元ファイルに戻してます。

```
echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > release.keystore
```

この記述だと、ビルドを走らせたタイミングで以下のようなエラーが出ました。

```
Run if [[ -n "***" ]]; then
  if [[ -n "***" ]]; then
    echo "***" | base64 -d > ***
    export KEYSTORE_PASSWORD="***"
    export KEY_ALIAS="***"
    export KEY_PASSWORD="***"
  fi
  export ENV_API_KEY="***"
  ./gradlew assembleRelease
Execution failed for task ':app:validateSigningRelease'.
> Keystore file '/home/runner/work/android/android/app/***' not found for signing config 'release'.
```

pwd を run の中に仕込んで確認すると保存するパスが間違っており、`app/release.keystore`先に変更したところ解決しました。

``` yaml
# secrets の値を環境変数に変換する！
- name: Build with Gradle
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > app/release.keystore
    export KEYSTORE_PASSWORD="${{ secrets.KEYSTORE_PASSWORD }}"
    export KEY_ALIAS="${{ secrets.KEY_ALIAS }}"
    export KEY_PASSWORD="${{ secrets.KEY_PASSWORD }}"
    ./gradlew assembleRelease
```


### Links
- [リリースの準備](https://developer.android.com/studio/publish/preparing?hl=ja)
- [Environment を登録しろおおおお](https://stackoverflow.com/questions/66521958/how-to-access-environment-secrets-from-a-github-workflow)
  - [公式](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#referencing-an-environment)
- [key を実際に署名に使うようにする手順](https://stackoverflow.com/questions/18328730/how-to-create-a-release-signed-apk-file-using-gradle)
- [Actions で署名を行う方法](https://qiita.com/hkusu/items/cadb572c979c4d729567)


## おわりに
今回初めて Github Actions を使って CI/CD を書いてみました。

その際普段コードを書く時とは別の視点でつまづくことが多かったので、次回また迷わないようにしたいと思います！
