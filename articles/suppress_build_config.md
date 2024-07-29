# Android のモジュールで BuildConfig を生成しない方法

この間マルチモジュールの対応をしたのですが、その際に `BuildConfig` について少し気になったので、今回はモジュールにおいて `BuildConfig` を生成しない方法についてメモしておきます。

各モジュールにおいても、標準では以下のようなファイルが `generated` フォルダに生成されます。  
（`build/generated/source/buildConfig/` の中にあります。）

```
package jp.mydns.kokoichi0206.common;

public final class BuildConfig {
  public static final boolean DEBUG = Boolean.parseBoolean("true");
  public static final String LIBRARY_PACKAGE_NAME = "jp.mydns.kokoichi0206.common";
  public static final String BUILD_TYPE = "debug";
}
```

これをモジュールで生成しないようにするには、**module の** `build.gradle` に以下のように設定します。

```
plugins {
    ...
}

android {
    ...
    libraryVariants.all {
        it.generateBuildConfig.enabled = false
    }
}
...
```
