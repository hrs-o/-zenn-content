---
title: "Unity+MagicOnion4.1.xを試す サーバーをEC2環境で動かす編"
emoji: "🔖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["magiconion","grpc","aspnetcore","ec2","nginx"]
published: true
---

## チャプター

- [環境構築&サービスでの通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-service)
- [StreamingHubでのリアルタイム通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-streaming-hub)
- [サーバーをEC2環境で動かす編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-aws-ec2-nginx)
- [IL2CPPでスマホ実機ビルド編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-il2cpp)

## まえがき

- [StreamingHubでのリアルタイム通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-streaming-hub)の続きになります
- 環境構築、前提等は上記の記事を参照してください

## サーバーアプリのビルド

```bash
$ dotnet publish --configuration Release
  MyApp-Server -> D:\MagicOnion\MyApp\MyApp-Server\bin\Release\net5.0\MyApp-Server.dll
  MyApp-Server -> D:\MagicOnion\MyApp\MyApp-Server\bin\Release\net5.0\publish\
```

- 後ほど、`MyApp\MyApp-Server\bin\Release\net5.0` 配下をEC2に持っていく

## EC2の構築

### 環境

- t2.micro
- Amazon Linux2
- セキュリティグループの設定漏れで接続出来ないとかありがちなので注意

### .NET SDKの追加

```bash
$ sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
$ sudo yum install -y dotnet-sdk-5.0
```

### サーバーアプリのデプロイ

- サーバーアプリのビルドで作成したディレクトリをデプロイする
- デプロイ方法はお好みで（とりあえずscpとかなんでも）
- ここでは `/var/www/onion` にアプリを配置

```bash
$ sudo mkdir -p /var/www/onion
```

### Nginxの追加

```bash
$ sudo amazon-linux-extras enable nginx1
$ sudo yum install nginx
```

### Nginxの設定

```bash
$ sudo vim /etc/nginx/conf.d/onion.conf
```

```nginx:/etc/nginx/conf.d/onion.conf
server {
  listen 8080 http2 default_server;
  listen [::]:8080 http2 default_server;
  location / {
    grpc_pass grpc://localhost:5000;
  }
}
```

### Nginxの起動

```bash
$ sudo service nginx start
```

### サーバーアプリの起動

```bash
$ cd /vaw/www/onion
$ dotnet MyApp-Server.dll
info: Microsoft.Hosting.Lifetime[0]
      Now listening on: http://localhost:5000
info: Microsoft.Hosting.Lifetime[0]
      Now listening on: https://localhost:5001
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Production
info: Microsoft.Hosting.Lifetime[0]
      Content root path: /var/www/onion/
```


## クライアントの修正

### コントローラーを修正

- 大本は[こちら](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-streaming-hub)にあります
- 修正といっても接続先とポートを変更するだけ

```diff:Assets/Scripts/MyApp/MyFirstController.cs
         void Awake()
         {
+            _channel = new Channel("EC2のPublicIPなど", 8080, ChannelCredentials.Insecure);
-            _channel = new Channel("localhost", 5000, ChannelCredentials.Insecure);
             _service = MagicOnionClient.Create<IMyFirstService>(_channel);
         }
```

## 接続確認

### クライアント（Unity）のシーンを実行

- 動作してればOK

## 参考

https://docs.microsoft.com/ja-jp/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-5.0

https://www.nginx.co.jp/blog/nginx-1-13-10-grpc/
