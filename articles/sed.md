# mac と Linux の違い [sed command]

手元の mac で動作確認をし、リモートマシン（GitHub Actions）で実行したところ、上手くいかないことがありました。

過去にも同じこと調べたな〜と思ったので、メモしておきます。

## やりたいこと

ファイルの中の

```
<link href="https://your.domain/style.css?20220720-1408">
```

という文字列から、`style.css?20220720-1408`を削除したい。

**要点**

- 正規表現による置換（削除）
- ファイルの書き換え

## ファイル書き換え時のオプションの違い

sed では `-i` オプションをつけることで in-place でファイルを置き換えることが可能となってます。

Mac の場合は別途 `-e` オプションが必要です。

```sh
# Linux
sed -i -E "s@style.css\?[0-9]*-[0-9]*@@g" test_file

# For Mac (BSD)
## -e が必要
sed -i -e "s@style.css\?[0-9]*-[0-9]*@@g" test_file
```

## 正規表現の違い

Mac ではオプションなしで基本正規表現は使えそうですが、Linux で正規表現を使うには `-r`（正規表現を使う）や `-E`（拡張正規表現を使う）のオプションが必要そうです。

```sh
# Linux
## -r や -E などをつける必要がある
sed -i -r "s@style.css\?[0-9]*-[0-9]*@@g" test_file
sed -i -E "s@style.css\?[0-9]*-[0-9]*@@g" test_file

# For Mac (BSD)
## 追加オプションは不要
sed -i -e "s@style.css\?[0-9]*-[0-9]*@@g" test_file
```

## おわりに

BSD ベース（Mac）と GNU ベース（Linux）のコマンドの違いをこれからは意識していきたいです。

それはそうと、移植性の高いスクリプトを書けるようになります。
