# k8s 内部でホスト名を指定するときのベストプラクティス

[『Kubernetes と名前解決』](https://zenn.dev/toversus/articles/d9faba80f68ea2)という記事が非常に面白くためになったため、自分なりに実験したものもまとめさせていただきます。

**[目次]**

```
* [まとめ](#まとめ)
* [DNS をみるための準備](#dns-をみるための準備)
  * [環境](#環境)
  * [サービスを持つ minimum の k8s 構成を kind と helm で作成する](#サービスを持つ-minimum-の-k8s-構成を-kind-と-helm-で作成する)
  * [サービス名で名前解決されるということ](#サービス名で名前解決されるということ)
* [tcpdump で DNS クエリをのぞく](#tcpdump-で-dns-クエリをのぞく)
* [おわりに](#おわりに)
```

## まとめ

- ドメインの最後の . は『ルートドメイン』を表し trailing dot ともいう
  - 付けなくてもよしなに補われたりする
  - 付けておくと FQDN を表すことを示すことになり、k8 内部のように dns resolver がカスタマイズされている状況では**挙動が変わることがある**
- k8s 内部での**理想的な**ホスト名指定（通常は無視できる範囲な気がする）
  - 外部 Host: trailing dot 付きで fqdn を指定する
  - Service 名: 『サービス名だけで指定する』or『trailing dot 付きで .local』まで含めて完全指定
- 微妙なホスト名指定の例
  - 外部 Host: `github.com`
  - Service 名: `dns-test.default.svc.cluster.local`

## DNS をみるための準備

自分は k8s 初心者であり色々と試行錯誤したため、実験のための最小構成をメモしておきます。

### 環境

kind と kubectl と helm があれば大丈夫だと思います。

自分は以下の環境でテストしました。

``` sh
❯ kind version
kind v0.20.0 go1.20.5 darwin/arm64

❯ kubectl version
Client Version: v1.28.4
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.27.3

❯ helm version
version.BuildInfo{Version:"v3.13.2", GitCommit:"2a2fb3b98829f1e0be6fb18af2f6599e0f4e8243", GitTreeState:"clean", GoVersion:"go1.21.4"}
```

### サービスを持つ minimum の k8s 構成を kind と helm で作成する

``` sh
# kind を使ってクラスターを作る。
kind create cluster --name dns-host-test

# コンテキストがクラスターを向いていることを確認。
❯ kubectl config get-contexts
CURRENT   NAME                 CLUSTER              AUTHINFO             NAMESPACE
*         kind-dns-host-test   kind-dns-host-test   kind-dns-host-test 

# helm を使ったプロジェクトの初期化。
helm create dns-test
# 何も変えずにとりあえず適応する。
helm install dns-test ./dns-test

# pod が起動していることを確認する。
❯ kubectl get po
NAME                       READY   STATUS              RESTARTS   AGE
dns-test-b5574b58d-s7ktf   1/1     Running             0          35s
```

helm create で作成された初期構成のチャートの適応により、以下のようにdns-test の [Service](https://kubernetes.io/ja/docs/concepts/services-networking/service/) が作成されます。

``` sh
❯ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
dns-test     ClusterIP   10.96.227.223   <none>        80/TCP    5m22s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   7m19s
```

今回はこの Service、『dns-test』に対する名前解決で遊んでみます。

### サービス名で名前解決されるということ

まずは dnsutils という pod を立ててみます。
[公式でも紹介されてる](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)ので安心して使っていきます。

``` sh
# 便利なツールを入れる。
kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml

# pod が立っていることを確認。
❯ kubectl get po
NAME                       READY   STATUS    RESTARTS   AGE
dns-test-b5574b58d-s7ktf   1/1     Running   0          21m
dnsutils                   1/1     Running   0          17m
```

exec することで外からコマンドを叩いてみます。

``` sh
❯ kubectl exec dnsutils -- nslookup dns-test
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   dns-test.default.svc.cluster.local
Address: 10.96.227.223
```

**サービス名として登録した名前が、DNS 名前解決できました。**

注目してほしいのが、Name が `dns-test.default.svc.cluster.local` となっているところです。
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) のページで詳しく書かれていますが、**pod と service には特別な A レコードが付与されます。**

今回のケースでは、dns-test というサービス名が default という Namespace に svc(service) という形で登録されていたことがわかります。

これらをうまく名前解決し、対象とする service/pod にシームレスにアクセスするために pod 内のコンテナは resolver の設定に特殊な加工が施されています！

``` sh
# pod 内のコンテナの resolver の設定をみてみる。
❯ kubectl exec dnsutils -- cat /etc/resolv.conf

search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

## tcpdump で DNS クエリをのぞく

pod に入って dns クエリを確認するために tcpdump の準備をします。
（nslookup, dig などだと service 名に対するクエリが正しく出なかった）

``` sh
# dnsutils のシェルに入る。
❯ kubectl exec -it dnsutils /bin/bash

# 立ち上げたシェルの中で操作。
# tcpdump をインストール。
root@dnsutils:/# apt install tcpdump
# DNS クエリに使われる 53 番ポートをのぞく。
root@dnsutils:/# tcpdump -n -i eth0 port 53
```

この状態で dnsutils から DNS 名前解決をしてみます。

``` sh
# host からで大丈夫。
❯ kubectl exec dnsutils -- nslookup dns-test
```

この時以下のような出力が**2行だけ**、tcpdump で待ち受けてる端末に表示されます。

``` sh
16:35:48.237948 IP 10.244.0.6.36450 > 10.96.0.10.53: 10671+ A? dns-test.default.svc.cluster.local. (52)
16:35:48.240955 IP 10.96.0.10.53 > 10.244.0.6.36450: 10671*- 1/0/0 A 10.96.227.223 (102)
```

`dns-test.default.svc.cluster.local.` で名前解決しに向かってることがわかります。

では、最初から `dns-test.default.svc.cluster.local.` で名前解決させることは可能でしょうか。

もちろんこの時も名前解決が完璧にされ、tcpdump の結果も2行だけです。

``` sh
❯ kubectl exec dnsutils -- nslookup dns-test.default.svc.cluster.local.
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   dns-test.default.svc.cluster.local
Address: 10.96.227.223
```

ではもしこの時、**最後の . (trailing dot) を忘れたらどうなるでしょうか？**

以下のように問題なく名前解決されます。

``` sh
❯ kubectl exec dnsutils -- nslookup dns-test.default.svc.cluster.local
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   dns-test.default.svc.cluster.local
Address: 10.96.227.223
```

しかし tcpdump には **8 行も表示され、見るからに不毛なクエリも発行**されています。
[Zenn の記事](https://zenn.dev/toversus/articles/d9faba80f68ea2)で説明されているように『**これ以上補完が必要ないことを明示』するために、最後に . をつける**ことが必要なことがわかります。

``` sh
16:42:04.943676 IP 10.244.0.6.34513 > 10.96.0.10.53: 60367+ A? dns-test.default.svc.cluster.local.default.svc.cluster.local. (78)
16:42:04.946116 IP 10.96.0.10.53 > 10.244.0.6.34513: 60367 NXDomain*- 0/1/0 (171)
16:42:04.946361 IP 10.244.0.6.34539 > 10.96.0.10.53: 43826+ A? dns-test.default.svc.cluster.local.svc.cluster.local. (70)
16:42:04.947851 IP 10.96.0.10.53 > 10.244.0.6.34539: 43826 NXDomain*- 0/1/0 (163)
16:42:04.948199 IP 10.244.0.6.51367 > 10.96.0.10.53: 2778+ A? dns-test.default.svc.cluster.local.cluster.local. (66)
16:42:04.948418 IP 10.96.0.10.53 > 10.244.0.6.51367: 2778 NXDomain*- 0/1/0 (159)
16:42:04.948717 IP 10.244.0.6.51560 > 10.96.0.10.53: 24312+ A? dns-test.default.svc.cluster.local. (52)
16:42:04.949399 IP 10.96.0.10.53 > 10.244.0.6.51560: 24312*- 1/0/0 A 10.96.227.223 (102)
```

つまり、サービスをホスト名に指定して利用するときは、以下のどちらかにすることが理想的といえそうです。

- Service 名のみ
  - `dns-test`
- `~svc.cluster.local` まで含めた完全な名称で指定し trailing dot を必ずつける
  - `dns-test.default.svc.cluster.local.`

ちなみに参考にした [Zenn の記事](https://zenn.dev/toversus/articles/d9faba80f68ea2)では**外部サービス名の末尾には trailing dot をつける**ことが勧められています。

- . をつける
  - `github.com.`

## おわりに

たかが . １つなのに、状況によっては挙動が全く変わるところが面白かったです。
（そういったところに注意を払えるエンジニアになりたい。）

この . の例のように、『普段は何気なく省略されているが、いい感じに補われてるために意識することがない』＋『ふとしたときに違いが現れてしまう』ような事象があれば知りたいです。
