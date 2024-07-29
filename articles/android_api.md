# API キーを安全に Android プロジェクトで管理する方法

API キーを（多少）安全に Android プロジェクトで管理する方法についてまとめておこうと思います。

## 前提
- Git でプロジェクトを管理していること
- Android Studio を使用していること

## 手順

### 1. gradle.properties(Project Properties)に API キーを記述キーを記述
以下のように最終行に API キーを追加します

```
...
android.enableJetifier=true
# Kotlin code style for this project: "official" or "obsolete":
kotlin.code.style=official
API_KEY="xxx-yyy-zzzz"
```

### 2. .gitignore に gradle.properties を追加
.gitignore ファイルに次の一文を追加します。（サイドバーのトップにある Android アイコンを、Project アイコンに変えると見つかると思います。）

こうすることで、先ほど API キーを記述したファイルが git の管理対象から外れるので、外部に漏れる心配が減ることとなります。

```
*.iml
.gradle
...
gradle.properties
```


### 3. build.gradle(Module)に読み込ませる設定をする
Module レベルの build.gradle > android > defaultConfig の中に buildConfigField を使って API キーを読み込まます

```
android {
    ...
    defaultConfig {
        ...
        buildConfigField("String", "API_KEY", API_KEY)
    }
    ...
}
```

### 4. 実際にプログラムから読み込む
以下のように BuildConfig から読み込んであげます。


```kotlin
apiKey: String = BuildConfig.API_KEY
```

BuildConfig は app/build/generated/... 以下のファイルに記述されるので、/build 以下を git 管理配下に含めないようにしましょう（デフォルトで除外されてるとは思います。）

### API_KEY が認識しない時
BuildConfig.API_KEY と打っても Android Studio に認識されない時は、１回 build を走らせると解決します。

これは BuildConfig が自動的には生成されず、build 時に生成されるためであります。


