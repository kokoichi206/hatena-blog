# androidTest が表示されなくなった！
android でリリースに向けて色々といじってた際、左上のタブで`Android`を選択している状態で androidTest が表示されなくなりました。

Android Studio の再起動や、『File > Invalidate Cache / Restart』をやってみても解決しませんでした。

最終的には[こちらの Stack Overflow](https://stackoverflow.com/questions/30292783/androidtest-folder-doesnt-show-on-androidstudio) に従い、app/build. gradle に下記内容を加えることで解決しました（その後に Invalidate Cache / Restart ）

``` 
android {
    ...
    sourceSets {
        main { java.srcDirs = ['src/main/java'] }
        test { java.srcDirs = ['src/test/java'] }
        androidTest { java.srcDirs = ['src/androidTest/java'] }
    }
    ...
}
```

原因はわかってないですが、とりあえず解決したのでよしとします。


