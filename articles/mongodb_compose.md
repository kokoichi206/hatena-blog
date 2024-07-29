# mongodb 用の docker compose ファイル

[公式](https://hub.docker.com/_/mongo/)に書いてあるのでそれを使います。

下記の compose ファイルで mongodb と web UI である mongo-express が起動できます。

``` yaml
version: '3.1'

services:
  mongo:
    image: mongo
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: example
    ports:
      - 27017:27017

  mongo-express:
    image: mongo-express
    restart: always
    ports:
      - 8081:8081
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: root
      ME_CONFIG_MONGODB_ADMINPASSWORD: example
      ME_CONFIG_MONGODB_URL: mongodb://root:example@mongo:27017/
    depends_on:
      - mongo
```

express に入る時に Basic 認証が必要なのですが、そこのパスワードは環境変数に設定した値ではありません。

![](img/mongo-express-auth.png)

compose のログにも出てるのですが、以下の内容で入力してあげることが必要でした。

```
username: admin
password: pass
```

また、ついでに以下の Makefile とかあると便利かもしれないです。

``` makefile
.PHONY: mongosh
mongosh:
	docker-compose exec mongo mongosh -u root -p example
```
