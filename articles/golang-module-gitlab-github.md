# GitLab プロジェクトの go get で『The project you were looking for could not be found or you don't have permission to view it.』

## まとめ

- GitLab の Go module には、リポジトリの終わりに `.git` をつける
- GitHub の Go module には `.git` をつけない

## 遭遇した問題と解決方法

GitLab で管理する Go module を go get しようとした際、以下のようなエラーが出る場合があります。
（自分が遭遇したのは private なリポジトリでした。）

```sh
# gitlab.com/my-awesome-company1/sg/pi までがリポジトリのパス、
# gen/components がそこから go.mod までのパス。
$ go get gitlab.com/my-awesome-company1/sg/pi/gen/components
remote:
remote: ========================================================================
remote:
remote: The project you were looking for could not be found or you don't have permission to view it.
remote:
remote: ========================================================================
remote:
fatal: Could not read from remote repository.
Please make sure you have the correct access rights
and the repository exists.go list
```

自分の場合は go.mod のモジュール名を変更してあげると解決しました。

|  | モジュール名 |
| :---: | :---: |
| 旧 | gitlab.com/my-awesome-company1/sg/pi/gen/components | 
| 新 | gitlab.com/my-awesome-company1/sg/pi.git/gen/components | 

GitLab はサブグループをいくつも作ることができるため、どこまでが Git のリポジトリを表すのかが分からない時があるのかなと思っています。
（ただ .git をつけないままでもうまく行く人もいるので、そこは謎となってます。。。）

## GitHub の場合

GitHub の場合は逆に `.git` をつけていると以下のように怒られます。

``` sh
$ go get github.com/kokoichi206/cloud-prac.git/kube/kind/protobuf/gen/go/protobuf@e8400cb37cbe91162bd11d147ebaf4630f6c80de
go: github.com/kokoichi206/cloud-prac.git/kube/kind/protobuf/gen/go/protobuf@e8400cb37cbe91162bd11d147ebaf4630f6c80de: invalid version control suffix in github.com/ path
```

GitLab とは逆に、個人のリポジトリであろうと組織のリポジトリであろうと『<アカウント名>/<リポジトリ名>』の2つで特定でき、それ以上続くことも名称がそれ以下になることもないからと考えています。
