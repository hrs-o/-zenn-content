---
title: "Go+gin+Air環境をDockerで構築"
emoji: "🐇"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Go","gin","Air","docker"]
published: true
---

## まえがき

- いい加減Goを触ってみたかったのでDockerで試してみた
- JetBrainsのGoLandがDocker使ったリモート開発にあんまり向いてなさそうなのが残念な気持ち


## ディレクトリ構成

- 参考用にGitHubにコードあげてあります
  - https://github.com/hrs-o/docker-go

```
.
├── docker
│   └── app
│       └── Dockerfile
├── src
│   ├── tmp
│   │   └── main
│   ├── go.mod
│   ├── go.sum
│   └── main.go
├── docker-compose.yml

```

## ホスト環境

- Windows+WSL2(ubuntu)

## go.modを事前に作成

- Docker環境でgo getしたりして必要になるので事前に作成
- `$ go mod init github.com/hrs-o/docker-go` を行っているのと変わらないはず

```bash
$ vim src/go.mod
```

```text:go.mod
module github.com/hrs-o/docker-go

go 1.16
```

## main.goの作成

- ginのQuick startからコピペ
  - https://github.com/gin-gonic/gin#quick-start
- 8080で受ける（最終的にはdocker-compose.ymlでポート変えてます）

```go:src/main.go
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
	r.Run() // listen and serve on 0.0.0.0:8080 (for windows "localhost:8080")
}
```

## Docker周りの設定

### Dockerfile

- go getでgitを使うようなのでgitを追加
- CMDでairを指定してホットリロード出来るようにしている
  - そのため、事前にgo.modが必要

```dockerfile:docker/app/Dockerfile
FROM golang:1.16-alpine

WORKDIR /go/src
COPY ./src .

RUN apk upgrade --update && \
    apk --no-cache add git

RUN go get -u github.com/cosmtrek/air && \
    go build -o /go/bin/air github.com/cosmtrek/air

CMD ["air", "-c", ".air.toml"]
```

### docker-compose.yml

- 3000ポートでアクセスを受けるようにしている

```yaml:dockre-compose.yml
version: '3.9'

services:
  app:
    build:
      context: .
      dockerfile: ./docker/app/Dockerfile
    ports:
     - "3000:8080"
    volumes:
      - ./src/:/go/src
    tty: true
```

### ビルド

```bash
$ docker-compose buid
```

## .air.tomlの生成

- ビルドした後、runで .air.tomlを生成
- 公式のexampleからコピペしてもとりあえずは良さそう
  - https://github.com/cosmtrek/air/blob/master/air_example.toml

```bash
$ docker-compose run --rm app air init
```

## go mod tidyで依存関係をよしなに

- go.sumが生成される

```bash
$ docker-compose run --rm app go mod tidy
go: downloading github.com/stretchr/testify v1.4.0
go: downloading golang.org/x/sys v0.0.0-20200116001909-b77594299b42
go: downloading gopkg.in/yaml.v2 v2.2.8
go: downloading github.com/go-playground/assert/v2 v2.0.1
go: downloading gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405
go: downloading github.com/pmezard/go-difflib v1.0.0
go: downloading github.com/davecgh/go-spew v1.1.1
```

## 起動

- ここまでやってやっと起動

```bash
$ docker-compose up -d
```

## 確認

- pingを打ったらpongを返す

```bash
$ curl http://localhost:3000/ping
{"message":"pong"}
```

## 参考

- gin
  - https://gin-gonic.com/
  - Goの軽量Webフレームワーク
  - ドメイン名おしゃれ
- cosmtrek/air
  - https://github.com/cosmtrek/air
  - Goにホットリロードを提供してくれる
- Go / Gin / air / DockerでHello woldする
  - https://blog.junkata.com/posts/go-gin-air-docker-hello-wold
