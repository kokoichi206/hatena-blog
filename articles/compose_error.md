# Jetpack compose で Back-end (JVM) Internal error

Jetpack compose で開発中、以下のようなエラーが出ました。

エラーメッセージから何のことか自分には特定に時間がかかったため、こちらにメモしておきます。

```
Caused by: org.jetbrains.kotlin.codegen.CompilationException: 
	Back-end (JVM) Internal error: Couldn't inline method call: 
	CALL 'public final fun Column (modifier: androidx.compose.ui.Modifier, 
	verticalArrangement: androidx.compose.foundation.layout.Arrangement.Vertical, 
	horizontalAlignment: androidx.compose.ui.Alignment.Horizontal, content: 
	@[Composable] @[ExtensionFunctionType] kotlin.Function1<androidx.compose.foundation.layout.ColumnScope, kotlin.Unit>):
	kotlin.Unit [inline] declared in androidx.compose.foundation.layout.ColumnKt' type=kotlin.Unit origin=null
Method: null
File is unknown
The root cause java.lang.IllegalStateException was thrown at: 
org.jetbrains.kotlin.codegen.inline.SourceCompilerForInlineKt.getMethodNode(SourceCompilerForInline.kt:118)
	at org.jetbrains.kotlin.codegen.inline.InlineCodegen.performInline(InlineCodegen.kt:63)
	at org.jetbrains.kotlin.backend.jvm.codegen.IrInlineCodegen.genInlineCall(IrInlineCodegen.kt:163)
	...
```

## 原因

[buildFeatures に compose が設定されてない。](https://developer.android.com/reference/tools/gradle-api/7.0/com/android/build/api/dsl/BuildFeatures#compose)

途中から compose に切り替えた場合や Module を作成した場合ではこちらが入ってないので、`build.gradle` に入れてやる必要があります。



```gradle
plugins {
	...
}

android {
    ...
	// 追加
    buildFeatures {
        compose true
    }
	...
}
...
```

