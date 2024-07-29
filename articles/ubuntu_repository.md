# ubuntu で Package graphviz is not available, but is referred to by another package.

`apt update` しても解決しない場合、デフォルトのリポジトリに `graphviz` が存在しないことが考えられます。

ubuntu のリポジトリとしては `main`, `restricted`, `universe`, `multiverse` がありますが、ここでは~~なんとなく~~ universe を追加してみます。

universe は、コミュニティがセキュリティアップデートを提供するソフトウェアらしいです。

追加するには以下のようにします。

``` sh
sudo add-apt-repository universe

sudo apt update
```

その後、希望するパッケージをインストールできるようになります。

``` sh
sudo apt install graphviz
```
