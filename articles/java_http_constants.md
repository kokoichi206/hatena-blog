# Java (Kotlin) で HTTP のステータスコードの定数を使う方法

Android (Kotlin) で Retrofit を使っていた時に、HTTP のステータスコードを使いたくなりました。  
直にベタ書きするのはいやだなーと思っていたところ、[`HttpURLConnection`](https://docs.oracle.com/javase/8/docs/api/java/net/HttpURLConnection.html) のクラスに用意されていました。

```kotlin
import java.net.HttpURLConnection

// int が求められている場所で、以下のように使える。
HttpURLConnection.HTTP_OK
```
