# Android: coil でアプリ全体の画像キャッシュ戦略を決める

Android の ImageLoader ライブラリとしては Picasso や Glide などがありますが、今回は Compose と相性がいい [Coil](https://github.com/coil-kt/coil) を使います。

**環境**

```
io.coil-kt:coil-compose:2.4.0
compose-bom:2023.06.01
```

Compose で Coil を使うには以下のようにします。
（[基本的な使い方](https://coil-kt.github.io/coil/compose/)）

``` kotlin
@Composable
fun CoilCacheImage(
    clear: () -> Unit,
) {
    val imgUrl = "https://avatars.githubusercontent.com/u/52474650?v=4"

    AsyncImage(
        model = imgUrl,
        contentDescription = null,
        modifier = Modifier
            .fillMaxWidth(),
    )
}
```

Coil のキャッシュ戦略には [disk cache と memory cache の2つがあり](https://coil-kt.github.io/coil/image_loaders/#caching)、デフォルトでもよしなにキャッシュしてくれますが明示的に設定することも可能です。

今回はその中でも [Singleton として設定](https://coil-kt.github.io/coil/getting_started/#image-loaders)し、アプリ全体の ImageLoader を一括で変更してみます。

アプリ全体にわたる挙動を制御するには [Application クラス](https://developer.android.com/guide/topics/manifest/application-element?hl=ja)を使うのが一般的であるため、次の内容の `MyApplication.kt` を `MainActivity.kt` と同じ階層に作成します。

``` kotlin
import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import coil.util.DebugLogger

// ImageLoaderFactory を実装する。
class MyApplication: Application(), ImageLoaderFactory {

    override fun newImageLoader(): ImageLoader {
        return ImageLoader(this).newBuilder()
            .memoryCachePolicy(CachePolicy.ENABLED)
            .memoryCache {
                MemoryCache.Builder(this)
                    // max で全メモリの 10% まで使う。
                    .maxSizePercent(0.1)
                    .strongReferencesEnabled(true)
                    .build()
            }
            .diskCachePolicy(CachePolicy.ENABLED)
            .diskCache {
                DiskCache.Builder()
                    // max でディスク容量の 5% まで使う。
                    .maxSizePercent(0.05)
                    .directory(cacheDir)
                    .build()
            }
            // logger の変更が可能。
            .logger(DebugLogger())
            .build()
    }
}
```

あとは `AndroidManifest.xml` に、独自で定義した Application を読み込ませてあげれば（`android:name` の部分）完成です。

``` xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    ...

    <application
        android:name=".MyApplication"
        ...
        tools:targetApi="33">
        ...
```
