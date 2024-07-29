# 【AWS-CLI】Lightsail の push-container-image 実行時に Is the docker daemon running? エラー

**[目次]**

```
* [環境](#環境)
* [まとめ](#まとめ)
* [背景](#背景)
* [おわりに](#おわりに)
```

## 環境

```
Host: mac m1
Docker: v24.0.6
Docker context: Docker Desktop
AWS CLI: aws-cli/2.13.25 Python/3.11.6 Darwin/22.1.0 source/arm64 prompt/off
```

## まとめ

**エラー内容**

``` sh
$ aws lightsail push-container-image --region ap-northeast-1 --service-name Amazon_Linux_2-1 --service-name container-service-1 --label testlabel --image web-backend:ee0e066df842

Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
Command '['lightsailctl', '--plugin', '--input-stdin']' returned non-zero exit status 1.
```

**原因**

Docker context の指す endpoint がデフォルト値（`unix:///var/run/docker.sock`）と異なること。

``` sh
$ docker context ls
NAME                TYPE                DESCRIPTION                               DOCKER ENDPOINT                                  KUBERNETES ENDPOINT   ORCHESTRATOR
default             moby                Current DOCKER_HOST based configuration   unix:///var/run/docker.sock                                            
desktop-linux *     moby                Docker Desktop                            unix:///Users/kokoichi/.docker/run/docker.sock 
```

**解決方法**

コマンド実行時に HOST を明示して上書きしてあげる。

``` sh
$ DOCKER_HOST=unix:///Users/kokoichi/.docker/run/docker.sock aws lightsail push-container-image --region ap-northeast-1 --service-name Amazon_Linux_2-1 --service-name container-service-1 --label testlabel --image sns-app-backend:ee0e066df842
```

## 背景

Lightsail に cli からアップロードするためにプラグインをインストールして使っていました。

``` sh
brew install aws/tap/lightsailctl
```

[ドキュメント](https://lightsail.aws.amazon.com/ls/docs/en_us/articles/amazon-lightsail-install-software#install-software-aws-cli)に沿って進めていたのですが、push するタイミングで
『Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?』のようなエラーが出ました。

``` sh
$ aws lightsail push-container-image --region ap-northeast-1 --service-name Amazon_Linux_2-1 --service-name container-service-1 --label testlabel --image web-backend:ee0e066df842

Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
Command '['lightsailctl', '--plugin', '--input-stdin']' returned non-zero exit status 1.
```

そこで Docker の context を見ると、現在（Docker Desktop によって）使用中の ENDPOINT がエラー文に記載のものと異なっていました。

``` sh
$ docker context ls
NAME                TYPE                DESCRIPTION                               DOCKER ENDPOINT                                  KUBERNETES ENDPOINT   ORCHESTRATOR
default             moby                Current DOCKER_HOST based configuration   unix:///var/run/docker.sock                                            
desktop-linux *     moby                Docker Desktop                            unix:///Users/kokoichi/.docker/run/docker.sock
```

[aws-cli](https://github.com/aws/aws-cli/issues?q=is%3Aissue+docker%2Frun%2Fdocker.sock+) や [lightsailctl](https://github.com/aws/lightsailctl/issues) には関連 issue はなさそうだったため、lightsail の cli 側で docker をどのように参照してるのかみてみます。

[pushContainer の中](https://github.com/aws/lightsailctl/blob/1c7c4c9670fd201d9c8e1811c722eff43ab30def/internal/plugin/plugin.go#L149-L171)で [DockerEngine を作成](https://github.com/aws/lightsailctl/blob/1c7c4c9670fd201d9c8e1811c722eff43ab30def/internal/cs/dockerengine.go#L41-L48)していて、
ここの client.Fromenv とは[これ](https://github.com/moby/moby/blob/86b86412a1b7df7dcecc81aa6ba795ff6b0c3ce3/client/options.go#L20-L45)のことで、DOCKER_API_VERSION や DOCKER_HOST が環境変数により設定できそうなことが分かりました。

そこで、以下のように**シェル変数を使って DOCKER の HOST 情報を更新**してあげたらうまくいきました。

``` sh
$ DOCKER_HOST=unix:///Users/kokoichi/.docker/run/docker.sock aws lightsail push-container-image --region ap-northeast-1 --service-name Amazon_Linux_2-1 --service-name container-service-1 --label testlabel --image sns-app-backend:ee0e066df842

8968b52d5591: Pushed 
a83c9b56bbe0: Pushed 
77192cf194dd: Pushed 
Digest: sha256:9136b6f88b47379a32a8388a742e41b5d0c26a7f8c3add7ff47653d48cb77a88
Image "sns-app-backend:ee0e066df842" registered.
Refer to this image as ":container-service-1.testlabel.1" in deployments.
```

## おわりに

環境変数を参照するロジックが本家の docker repository の client パッケージにあったため、多くの cli で応用が効きそうだと思いました。

ただ、docker context コマンドで出てくる情報くらいは、CLI 側で勝手に読み取って設定してほしさがあるので、どうにかできないか CLI 側をのぞいてみようと思います。
