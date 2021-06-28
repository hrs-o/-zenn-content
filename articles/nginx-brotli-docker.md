---
title: "nginx+brotliをDockerで確認"
emoji: "🌐"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nginx","brotli","docker"]
published: true
---

## まえがき

- Brotliがgzipよりいい感じらしいよ、と小耳に挟んだので試してみようと思った
- docker上のnginxへのmodule追加方法を知らなかったので結構調べた

## Docker環境構築

- nginx公式のdockerイメージでmoduleを追加するには公式のDockerfile利用してENABLED_MODULESを指定する必要がある
  - 基本的には [Adding third-party modules to nginx official image](https://github.com/nginxinc/docker-nginx/tree/master/modules)を読めば解決


### Dockerfileのコピー

```bash
$ mkdir -p /path/to/project-root/docker/nginx
$ cd /path/to/project-root/
$ curl -o docker/nginx/Dockerfile https://raw.githubusercontent.com/nginxinc/docker-nginx/master/modules/Dockerfile
```

### docker-compose ファイルの設定

```bash
$ vim docker-compose.yml
```

```yaml:docker-compose.yml
version: '3.7'
services:
  nginx:
    build:
      context: docker/nginx
      args:
        ENABLED_MODULES: brotli
    image: nginx-with-brotli:v1
    container_name: "brotli-nginx"
    ports:
      - "80:80"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf
```

### nginx.confの設定

- とりあえず確認用なのでonにしているだけ、きちんとやるならtypesとか指定したほうがいいです
  - https://github.com/google/ngx_brotli/blob/master/README.md

```diff:docker/nginx/nginx.conf
 user  nginx;
 worker_processes  1;
 
 error_log  /var/log/nginx/error.log warn;
 pid        /var/run/nginx.pid;
 
+ load_module modules/ngx_http_brotli_filter_module.so;
+ load_module modules/ngx_http_brotli_static_module.so;
 
 events {
     worker_connections  1024;
 }
 
 http {
     include       /etc/nginx/mime.types;
     default_type  application/octet-stream;
 
     log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                       '$status $body_bytes_sent "$http_referer" '
                       '"$http_user_agent" "$http_x_forwarded_for"';
 
     access_log  /var/log/nginx/access.log  main;
 
     sendfile        on;
     #tcp_nopush     on;
 
     keepalive_timeout  65;
 
     #gzip  on;
+     brotli on;
     include /etc/nginx/conf.d/*.conf;
 }

```

## 実行と確認

```bash
$ docker-compose build
$ docker-compose up -d
```

### レスポンスヘッダーを確認

- `Accept-Encoding: br`を指定して、`Content-Encoding: br` が返ってくればOK

```bash
$  curl -H "Accept-Encoding: br" -I http://localhost
HTTP/1.1 200 OK
Server: nginx/1.21.0
Date: Mon, 28 Jun 2021 09:41:36 GMT
Content-Type: text/html
Last-Modified: Tue, 25 May 2021 12:28:56 GMT
Connection: keep-alive
ETag: W/"60aced88-264"
Content-Encoding: br
```

## 参考
- [google/brotli](https://github.com/google/brotli/)
- [google/ngx_brotli](https://github.com/google/ngx_brotli)
- [How to add modules? #332](https://github.com/nginxinc/docker-nginx/issues/332)
