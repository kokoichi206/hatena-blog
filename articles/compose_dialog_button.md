# jetpack compose の alertDialog でボタンをいい感じに配置する
今回は、jetpack compose の alertDialog を使って、以下のようにボタンを中央から均等に配置させる方法について紹介したいと思います。

[f:id:kokoichi206:20211119014754p:plain]


## 環境
```
- compose_version = '1.0.1'
- targetSdk 26
- kotlinCompilerVersion '1.5.21'
```

## 実装方法
「compose alertDialog」とかで調べると、confirmButton と dismissButton を使って２つのボタンを使うやり方がよく出てくると思います。

ですが、その方法だとカスタマイズが難しいと思われます。

### 方針
confirmButton と dismissButton の２つでボタンを指定する代わりに、buttons を使って一括でボタンを指定してあげます。

```kotlin
AlertDialog(
    onDismissRequest = {},
    title = {
        Text(text = "??")
    },
    text = {
        Text("")
    },
    buttons = {
        // 好きな composable を配置できる！！
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(all = buttonPaddingValue),
        ) {
    ...
```


### 全コード
今回の dialog を表示させるのに必要な全コードを載せておきます。

```kotlin
@Composable
fun TestDialog() {
    Surface(
        modifier = Modifier
            .fillMaxSize()
    ) {
        AlertDialog(
            onDismissRequest = {},
            title = {
                Text(text = "キャッシュ情報を削除しますか？")
            },
            text = {
                Text("一時的な情報を削除することでストレージに多少の余裕を持たせることができます。")
            },
            buttons = {
                val buttonPaddingValue = 12.dp
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(all = buttonPaddingValue),
                ) {
                    val context = LocalContext.current
                    TextButton(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(5.dp))
                            .background(SubColorS),
                        onClick = {
                            openDialog.value = false

                            deleteCache(context)
                            navController.navigateUp()
                        }
                    ) {
                        Text(
                            modifier = Modifier,
                            text = "削除",
                            color = Color.White,
                        )
                    }
                    // Some space same as the start, end and bottom
                    Spacer(modifier = Modifier.width(buttonPaddingValue))
                    TextButton(
                        modifier = Modifier
                            .weight(1f)
                            .border(
                                width = 1.dp,
                                color = SubColorS,
                                shape = RoundedCornerShape(5.dp)
                            ),
                        onClick = {
                            openDialog.value = false
                        },
                    ) {
                        Text(
                            text = "キャンセル",
                            color = SubColorS,
                        )
                    }
                }
            }
        )
    }
}
```


## おわりに
なんとか今回は自分の思った形の UI に実装することができました。

Jetpack compose の勉強を引き続き行なっていきます！
