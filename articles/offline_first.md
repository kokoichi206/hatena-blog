[Dev Summit: Create offline-first apps](https://www.youtube.com/watch?v=jaZ2gLMGUsM&list=PLWz5rJ2EKKc92MGTd1CgUtXZfhA74nUpb&index=7&ab_channel=AndroidDevelopers) を試聴したのでそのメモです（）。

## repository 層の役割

リポジトリー層の役割として、少なくとも 2 つのデータソース（LocalDataSource と NetworkDataSource）からデータを取得することを考える。

この際、取得できるエンティティが異なるかもしれないが（`AuthorEntity`と`NetworkAuthor`など）、それを整形して統一して返してあげるのも**Data Layer の役割**。

- Read は Flow を使って
- Write は suspend fun で

## ネットワークのモニター

- ネットワーク接続がとれるまで**キューに貯めておく必要がある！**
  - 書き込みについて
- ネットワークをモニターし、接続が取れたらキューからジョブを実行させる

LocalDataSource については、データの一貫性のために**常に読み込みできることが大切！**

失敗時にリトライが必要そうなら、再度キューに入れる作戦で！

## Synchronization

ローカルデータとリモートデータを統一させること。

- Pull-based
  - on demand で取得する
  - 実装が簡単
- Push-based
  - データ使用量が最小ですむ
  - must be supported by the network.

## Links

- [Build an offline-first app](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Dev Summit: Create offline-first apps](https://www.youtube.com/watch?v=jaZ2gLMGUsM&list=PLWz5rJ2EKKc92MGTd1CgUtXZfhA74nUpb&index=7&ab_channel=AndroidDevelopers)

## おわりに

なんとなくやりたいことはわかったけど、実際に手動かしてみないと！
