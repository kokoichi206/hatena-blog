# VSCode で Python の Auto Import を有効にする

最近よく Python を使ってるのですが、ようやく手元の VSCode で Auto Import 設定を有効にしました。

以下、自分向けの備忘録として記録しておきます。

<!-- more -->

[settings.json](https://code.visualstudio.com/docs/getstarted/settings) に以下を追加します。

``` json
{
  // ... other settings

  // https://code.visualstudio.com/docs/python/editing#_enable-auto-imports
  "python.analysis.autoImportCompletions": true,
  // enable user files
  // https://github.com/microsoft/pylance-release/blob/main/docs/settings/python_analysis_indexing.md#what-is-pythonanalysisindexing
  "python.analysis.indexing": true,

  // ... other settings
}
```

## Links

- https://code.visualstudio.com/docs/python/editing#_enable-auto-imports
- https://github.com/microsoft/pylance-release/blob/main/docs/settings/python_analysis_indexing.md#what-is-pythonanalysisindexing

## おわりに

[VSCode の Python ユーザー向けドキュメント](https://code.visualstudio.com/docs/python/formatting)が思ったより充実してたので一通り眺めてみます！
