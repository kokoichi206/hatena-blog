# git log を使って 1 日分のコード差分行数を計算

`git log` を使って、特定のユーザーが何行進捗を出したかを確認する例のメモです。

特に、`initial commit` などのコミットメッセージに代表される**プロジェクト（フレームワーク）の初期ファイル**を、**コミットメッセージから無視する**ようにしました。

- 特定のユーザーからのコミットのみ
- 特定のコミットメッセージを除外（下の例は case-ignore で initial commit,first commit）
- clone さえできれば token が不要

## 例

```sh
# 1日の変更分。
# 出力例: Nov21 24
cat <(git log \
        --numstat \
        --branches \
        --since=midnight \
        --no-merges \
        --author="$(git config user.name)" |\
    awk '$1 == "Date:" { date = $3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,$1,$2 }') \
    <(git log \
        --numstat \
        --branches \
        --since=midnight \
        --no-merges \
        --author="$(git config user.name)" \
        --all-match \
        -i --grep="initial commit" |\
 awk '$1 == "Date:" { date = $3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') \
    <(git log \
        --numstat \
        --branches \
        --since=midnight \
        --no-merges \
        --author="$(git config user.name)" \
        --all-match \
        -i --grep="first commit" |\
 awk '$1 == "Date:" { date = $3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') |\
awk '{ a[$1] += $2 + $3 } END { for(date in a) print date, a[date] }'
```

### 日ごとのコミット出力

```sh
# 出力例
# 2022/01/27 19
# 2022/01/28 389
# 2022/01/31 87
# 2022/02/04 1874
# 2022/02/05 1030
# 2022/02/06 94
cat <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges \
        --author="$(git config user.name)" |\
    awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,$1,$2 }') \
    <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges \
        --author="$(git config user.name)" \
        --all-match \
        -i --grep="initial commit" |\
 awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') \
    <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges \
        --author="$(git config user.name)" \
        --all-match \
        -i --grep="first commit" |\
 awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') |\
awk '{ a[$1] += $2 + $3 } END { for(date in a) print date, a[date] }' |\
sort
```

ユーザーを絞り込まない場合（上の例から `author` 部分を削除）

```sh
cat <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges |\
    awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,$1,$2 }') \
    <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges \
        -i --grep="initial commit" |\
 awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') \
    <(git log \
        --numstat \
        --branches \
        --date=format:'%Y/%m/%d' \
        --no-merges \
        -i --grep="first commit" |\
 awk '$1 == "Date:" { date = $2$3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,-$1,-$2 }') |\
awk '{ a[$1] += $2 + $3 } END { for(date in a) print date, a[date] }' |\
sort
```

- author と grep を両方指定する場合は、`--all-match`オプションも一緒に使う
- grep のところと author のところは同じパターンを使ってそうなので、**`author` と `invert-grep` を使ったときは、検索が期待値通りにいかない！**

```sh
# 失敗するパターン
git log \
 --numstat \
 --branches \
 --no-merges \
 --invert-grep -i --grep="initial commit" \
 --all-match \
 --author="gegege" |\
 awk '$1 == "Date:" { date = $3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,$1,$2 }' > res
cat res | awk '{ a[$1] += $2 + $3 } END { for(date in a) print date, a[date] }'

#
git log \
 --numstat \
 --branches \
 --no-merges \
 --author="afea" \
 --and \
 --invert-grep -i --grep="initial commit" --grep="first commit" |\
 awk '$1 == "Date:" { date = $3$4 } ( NF == 3 && $1 ~ /[0-9]+/ && $2 ~ /[0-9]+/ ) { print date,$1,$2 }' |\
 awk '{ a[$1] += $2 + $3 } END { for(date in a) print date, a[date] }'
```

## Links

- [Can 'git log' ignore certain commits based on commit message?](https://stackoverflow.com/questions/47081606/can-git-log-ignore-certain-commits-based-on-commit-message)
- [View commits in a specific date range](https://www.30secondsofcode.org/git/s/view-commits-in-date-range)
- [git log invert-grep](https://git-scm.com/docs/git-log#git-log---invert-grep)
