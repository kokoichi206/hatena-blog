# adb コマンドで今の activity を立ち上げる

[目次]

[:contents]

## 現在起動中のアクティビティを調べる

```bash
$ adb shell dumpsys activity activities
```

このコマンドを実行すると、起動中のアクティビティがいっぱい出てくると思います。

その中で一番上の`Display #0 (activities from top to bottom):`が現在一番上にある（目から見えている）アクティビティとなります。

```sh
$ adb shell dumpsys activity activities | head -n 20

ACTIVITY MANAGER ACTIVITIES (dumpsys activity activities)
Display #0 (activities from top to bottom):
  RootTask #4521: type=standard mode=fullscreen
  isSleeping=false
  mBounds=Rect(0, 0 - 0, 0)
  mCreatedByOrganizer=false
    mResumedActivity: ActivityRecord{f444616 u0 com.android.settings/.Settings$DevelopmentSettingsDashboardActivity t4521}
    mLastPausedActivity: ActivityRecord{73ca1e4 u0 com.android.settings/.SubSettings t-1 f}}
    * Task{a7b7a33 #4521 type=standard A=1000:com.android.settings U=0 visible=true mode=fullscreen translucent=false sz=1}
      mBounds=Rect(0, 0 - 0, 0)
      mMinWidth=-1 mMinHeight=-1

      affinity=1000:com.android.settings
      intent={act=android.service.quicksettings.action.QS_TILE_PREFERENCES flg=0x14000000 cmp=com.android.settings/.Settings$DevelopmentSettingsDashboardActivity}
      ...
      * Hist #1: A ...
```

この中からそれっぽいものを（頑張って）探してきます！

## adb コマンドでアクティビティを起動する

### adb start -a: インテントを起動
```sh
$ adb shell am start -a android.settings.BLUETOOTH_SETTINGS
Starting: Intent { act=android.settings.BLUETOOTH_SETTINGS }
```

### adb start -n: アクティビティを起動
package_name/acrivity_name の形で指定します

```sh
# 自分の作ったアプリでももちろん可能です
$ adb shell am start -n io.kokoichi.sample.sakamichiapp/.presentation.MainActivity
```



