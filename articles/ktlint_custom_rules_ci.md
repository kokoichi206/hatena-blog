# ktlint カスタムルールの作り方：禁止 import を Gradle・CI で検査する

Android のウィジェットを作っています。入力と認証は外部ブラウザに任せ、アプリ側には WebView や直接の通信処理を持たせない方針です。

この方針をコードでも検査できるように、`android.webkit` や `java.net` の import を検出する ktlint のカスタムルールを追加しました。ルールの実装から `RuleSetProviderV3` による登録、Gradle と GitHub Actions での実行までを残しておきます。

<!-- more -->

## 環境と全体のコード

実装は公開リポジトリ [Life Console の lint-rules](https://github.com/kokoichi206/life-console/tree/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/lint-rules)にあります。記事では要点を抜粋します。

| 対象 | バージョン |
| --- | --- |
| ktlint | 1.8.0 |
| ktlint-gradle | 14.0.1 |
| Kotlin | 2.2.21 |
| Gradle | 8.13 |
| Java | 17 |

ここで作るのは ktlint のルールです。Android Lint の独自 `Detector` とは別で、Kotlin の構文を検査します。

以降のパスは、特記がなければ `clients/android/` からの相対パスです。

## 禁止する import を .editorconfig に書く

ウィジェットの実装で次の import が追加されたら、lint を失敗させます。

```kotlin
import android.webkit.WebView
import java.net.URL
```

禁止対象はルール本体に埋め込まず、`.editorconfig` の独自プロパティにしました。アプリのソースだけに設定しています。

```editorconfig
[app/src/**.kt]
life_console_forbidden_import_prefixes = android.webkit, java.net, javax.net, okhttp3, retrofit2
```

`android.webkit` を設定した場合、`android.webkit.WebView` や `android.webkit.*` を検出します。名前が似ている `android.webkitextra.SomeClass` は対象外です。

単純な文字列の前方一致では、後者まで巻き込んでしまいます。完全一致、またはプレフィックスの直後が `.` であることを条件にしました。

## Rule で import の構文を調べる

[NoForbiddenImportRule.kt](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/lint-rules/src/main/kotlin/dev/kokoichi/lifeconsole/lintrules/NoForbiddenImportRule.kt) は `Rule` を継承し、ルール ID を `life-console:no-forbidden-import` として登録しています。

独自プロパティは `EditorConfigProperty<String>` で定義します。プロパティ名は `life_console_forbidden_import_prefixes`、既定値は空文字です。これを `Rule` の `usesEditorConfigProperties` に渡しておきます。

ファイルの検査が始まるときに、カンマ区切りの設定をリストにします。

```kotlin
override fun beforeFirstNode(editorConfig: EditorConfig) {
    forbiddenPrefixes =
        editorConfig[FORBIDDEN_IMPORT_PREFIXES_PROPERTY]
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
}
```

検出の中心は `beforeVisitChildNodes` の中にある次の処理です。

```kotlin
if (node.elementType != ElementType.IMPORT_DIRECTIVE || forbiddenPrefixes.isEmpty()) return
val importPath = (node.psi as KtImportDirective).importPath?.pathStr ?: return
val matched =
    forbiddenPrefixes.firstOrNull { importPath == it || importPath.startsWith("$it.") }
        ?: return
emit(node.startOffset, errorMessage(importPath, matched), false)
```

import のノードだけを調べ、設定に一致したら `emit` で違反を報告します。`emit` の最後の引数は、自動修正できるかどうかです。WebView を何に置き換えるかは設計上の判断が必要なので、`false` にしています。

クラス全体では `RuleAutocorrectApproveHandler` も実装しています。コールバックの型や import を含む全体は、上のソースへのリンクから確認できます。

## RuleSetProviderV3 とサービスファイルで登録する

ルールを作ったら、ktlint が読み込めるように ruleset へ登録します。[LifeConsoleRuleSetProvider.kt](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/lint-rules/src/main/kotlin/dev/kokoichi/lifeconsole/lintrules/LifeConsoleRuleSetProvider.kt) の実装は次の形です。

```kotlin
class LifeConsoleRuleSetProvider : RuleSetProviderV3(RuleSetId("life-console")) {
    override fun getRuleProviders(): Set<RuleProvider> =
        setOf(
            RuleProvider { NoErrorMessageStringMatchingRule() },
            RuleProvider { NoForbiddenImportRule() },
        )
}
```

このリポジトリには別のルールもあるため、`setOf` に 2 つ並んでいます。今回の禁止 import は `NoForbiddenImportRule` です。

もう 1 つ必要なのが、次のサービスファイルです。

```text
lint-rules/src/main/resources/META-INF/services/com.pinterest.ktlint.cli.ruleset.core.api.RuleSetProviderV3
```

中身には Provider の完全修飾クラス名を 1 行で書きます。

```text
dev.kokoichi.lifeconsole.lintrules.LifeConsoleRuleSetProvider
```

クラスを定義するだけでなく、このファイルを JAR に含めて `ServiceLoader` から見つけられるようにします。登録方法は [ktlint 1.8.0 のカスタムルールのドキュメント](https://ktlint.github.io/ktlint/1.8.0/api/custom-rule-set/)に沿っています。

## Gradle から ruleset を読み込む

`settings.gradle.kts` に `include(":lint-rules")` を追加し、ルールを Kotlin/JVM の独立したモジュールにします。

[lint-rules/build.gradle.kts](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/lint-rules/build.gradle.kts) では、ktlint の API を `compileOnly` で参照しています。実行側と API のバージョンをそろえ、ruleset の JAR に同梱しないためです。

```kotlin
dependencies {
    compileOnly(libs.ktlint.rule.engine.core)
    compileOnly(libs.ktlint.cli.ruleset.core)
    testImplementation(libs.ktlint.rule.engine.core)
    testImplementation(libs.ktlint.test)
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:1.11.4")
    testRuntimeOnly("org.slf4j:slf4j-simple:2.0.16")
}
```

`libs.ktlint.*` は [バージョンカタログ](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/gradle/libs.versions.toml)の定義です。`ktlint-rule-engine-core`、`ktlint-cli-ruleset-core`、`ktlint-test` をすべて `1.8.0` にそろえています。

[ルートの build.gradle.kts](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/build.gradle.kts) では、各プロジェクトに ktlint-gradle を適用し、実行する ktlint のバージョンも同じカタログから渡します。

```kotlin
val ktlintVersion = libs.versions.ktlint.get()

allprojects {
    apply(plugin = "org.jlleitschuh.gradle.ktlint")
    extensions.configure<org.jlleitschuh.gradle.ktlint.KtlintExtension> {
        version.set(ktlintVersion)
        filter {
            exclude("**/build/**")
        }
    }
}
```

最後に、検査するモジュールの `ktlintRuleset` に依存を追加します。

```kotlin
subprojects {
    if (path != ":lint-rules") {
        dependencies.add("ktlintRuleset", project(":lint-rules"))
    }
}
```

`:lint-rules` 自身は除外します。ここにも自作 ruleset を読み込ませると、自分自身への依存になります。

`ktlintRuleset` にプロジェクト依存を追加する方法は、[ktlint-gradle 14.0.1 の README](https://github.com/JLLeitschuh/ktlint-gradle/tree/v14.0.1#custom-rules)でも案内されています。

## 検出する例・しない例をテストする

[NoForbiddenImportRuleTest.kt](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/clients/android/lint-rules/src/test/kotlin/dev/kokoichi/lifeconsole/lintrules/NoForbiddenImportRuleTest.kt) では、`ktlint-test` の `assertThatRule` を使っています。

例えば、完全一致の import を検出するテストです。

```kotlin
private val ruleAssertThat = assertThatRule { NoForbiddenImportRule() }

@Test
fun rejectsExactImportMatch() {
    ruleAssertThat("import android.webkit.WebView\n")
        .withEditorConfigOverride(
            FORBIDDEN_IMPORT_PREFIXES_PROPERTY to "android.webkit.WebView",
        )
        .hasLintViolationWithoutAutoCorrect(
            1,
            1,
            NoForbiddenImportRule.errorMessage(
                "android.webkit.WebView",
                "android.webkit.WebView",
            ),
        )
}
```

先頭の `1, 1` は、違反を報告する行と列です。自動修正をしないことも検証しています。

禁止プレフィックスを `android.webkit` としたときの境界もテストしました。

| コード・設定 | 結果 |
| --- | --- |
| `import android.webkit.WebView` | 検出する |
| `import android.webkit.WebView as Browser` | 検出する |
| `import android.webkit.*` | 検出する |
| `import android.webkitextra.SomeClass` | 検出しない |
| 禁止リストを未設定にする | 検出しない |
| ルール ID を指定してファイル単位で抑制する | 検出しない |

検出したいコードだけでなく、通してよいコードを含めて 9 ケースです。実装変更でパッケージ境界の条件を落としたら、非検出側のテストで気付けます。

## ローカルと GitHub Actions で実行する

`clients/android/` で、次のコマンドを実行します。

```bash
./gradlew ktlintCheck :lint-rules:test --no-daemon
```

`ktlintCheck` はアプリのソースを検査し、`:lint-rules:test` は自作ルールのテストを実行します。

記事を書く際にも、公開コードを別のフォルダへ取り出してこのコマンドを実行しました。禁止 import の 9 ケースと、もう一方のルールの 11 ケースが通りました。

さらにアプリのソースに `import android.webkit.WebView` とその型を使うコードを追加すると、`:app:ktlintMainSourceSetCheck` が失敗しました。違反コードを取り除き、`--rerun-tasks` を付けて再実行すると成功します。ルール単体のテストに加えて、Gradle から読み込まれるところまで確認できました。

GitHub Actions でも、JDK 17 と Android SDK を準備した後に同じコマンドを実行します。

```yaml
- name: Run Kotlin lint and custom rule tests
  run: ./gradlew ktlintCheck :lint-rules:test --no-daemon
```

[実際の workflow](https://github.com/kokoichi206/life-console/blob/9854380f51c2a209c28d758d5b5baf658ddc2e37/.github/workflows/ci-android.yml)では、`working-directory` を `clients/android` に設定しています。Android Lint やビルドは別のステップで実行しています。

## このルールで検出できる範囲

検査しているのは import の構文です。例えば `android.webkit.WebView` とコード中に完全修飾名で書き、import を使わなければ、このルールでは検出できません。型解決を伴う利用箇所の検査まではしていません。

また、プロパティ未設定のファイルは検査対象外で、`@file:Suppress("ktlint:life-console:no-forbidden-import")` による抑制もできます。通信処理をすべて禁止する仕組みとしてではなく、決めた階層に禁止 import が入ったことを CI で知らせる用途にしています。

以前書いた [CLAUDE.md の規約を ESLint カスタムルールにする記事](https://koko206.hatenablog.com/entry/2026/07/08/173341)と同じく、今回も構文で判断できる規約を 1 つ選びました。レビューでは、lint が見ていない完全修飾名での参照や、例外を認める理由を確認します。
