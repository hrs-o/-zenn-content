---
title: "Unity+MagicOnion4.1.xを試す 環境構築&サービスでの通信編"
emoji: "🔖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["magiconion","grpc","unity","aspnetcore"]
published: false
---


## まえがき

- リアルタイム通信をするにあたって[MagicOnion](https://github.com/Cysharp/MagicOnion)が良さそうだったので調査と環境構築
- サンプルで利用しているコードはMagicOnionのREADMEをほぼ利用しています
- この記事ではServiceのみ取り扱い、StreamingHubに関しては取り扱わない
- ディレクトリやプロジェクト名は適宜読み替えてください

## 環境

- Windows 10
- Visual Studio 2019
- Unity 2020.2.3f1
- [MagicOnion 4.1.2](https://github.com/Cysharp/MagicOnion/releases/tag/4.1.2)
- [MessagePack-CSharp 2.2.85](https://github.com/neuecc/MessagePack-CSharp/releases/tag/v2.2.85)
- [gRPC 2.37.0](https://packages.grpc.io/archive/2021/02/6102f67adeccb95afb32c2cef4198e50a5d77ee0-e2604501-c4b3-453d-bd11-fb9374a2fed8/index.xml)


## ディレクトリ構成

- 相対パスで参照する箇所があるので、クライアント、サーバーすべて同ディレクトリ内に入れる

```
MyApp
  └┬MyApp-Client
   ├MyApp-Server
   └MyApp-Shared
```

## クライアント（Unity）の環境構築

### 新しいプロジェクトを作成

![](https://storage.googleapis.com/zenn-user-upload/kt6qo4j7p6hrxk6dlms1bmy71bz6)

### Api Compatibility Levelの変更

- Player Settings > Other Settings > Api Compatibility Level 4.xに変更する

![](https://storage.googleapis.com/zenn-user-upload/0n5kq6j5el1tnmeyzc64qsv29uro)

### MagicOnionをimport

 - [GitHubのReleases](https://github.com/Cysharp/MagicOnion/releases/tag/4.1.2)から`MagicOnion.Client.Unity.unitypackage`をDLしてプロジェクトにimport

 
![](https://storage.googleapis.com/zenn-user-upload/et9gtiwyonfjrtdm66zzkbfuflrm)


### MessagePack-CSharpをimport

- [GitHubのReleases](https://github.com/neuecc/MessagePack-CSharp/releases/tag/v2.2.85)から`MessagePack.Unity.2.2.85.unitypackage`をDLしてプロジェクトにimport

![](https://storage.googleapis.com/zenn-user-upload/br1kvkdcc4h56hgcv2i6grxme7dj)

### gRCPをimport

- [gRCPのビルド](https://packages.grpc.io/archive/2021/02/6102f67adeccb95afb32c2cef4198e50a5d77ee0-e2604501-c4b3-453d-bd11-fb9374a2fed8/index.xml)から`grpc_unity_package.2.37.0-dev202102141315.zip`をDL
  - 最新のビルドが必要であれば[Daily Builds](https://packages.grpc.io/)から最新のTimestampの`Build ID`からDL

![](https://storage.googleapis.com/zenn-user-upload/g3hs7p610jpdklsz92qiy2rzia7p)

- zipを解凍してPluginsの中にあるディレクトリをUnity側にコピー

![](https://storage.googleapis.com/zenn-user-upload/a9tk6zf23s7f12lrjf485f0qv644)

### 必要なディレクトリを作成

- Assets > Scripts > MyApp > Shared > Service

### サーバーと接続するためのインタフェースを作成

```cs:Assets/Scripts/MyApp/Shared/Services/IMyFirstService.cs
using MagicOnion;

namespace MyApp.Shared.Services
{
    // Defines .NET interface as a Server/Client IDL.
    // The interface is shared between server and client.
    public interface IMyFirstService : IService<IMyFirstService>
    {
        // The return type must be `UnaryResult<T>`.
        UnaryResult<int> SumAsync(int x, int y);
    }
}
```

### コントローラーを作成

```cs:Assets/Scripts/MyApp/MyFirstController.cs
using Grpc.Core;
using MagicOnion.Client;
using MyApp.Shared.Services;
using UnityEngine;

namespace MyApp
{
    public class MyFirstController : MonoBehaviour
    {
        private Channel _channel;
        private IMyFirstService _service;

        void Awake()
        {
            _channel = new Channel("localhost", 5000, ChannelCredentials.Insecure);
            _service = MagicOnionClient.Create<IMyFirstService>(_channel);
        }

        async void Start()
        {
            var x = Random.Range(0, 1000);
            var y = Random.Range(0, 1000);
            var result = await _service.SumAsync(x, y);
            Debug.Log($"Result: {result}");
        }

        async void OnDestroy()
        {
            if (_channel != null)
            {
                await _channel.ShutdownAsync();
            }
        }
    }
}

```

### Sceneにスクリプトを追加

- 適当なScene（今回はお試しなのでデフォで存在しているSampleScene）に空のゲームオブジェクトを追加してMyFirstController.csをAdd Compornentする

![](https://storage.googleapis.com/zenn-user-upload/wap74mti8h8hycjt7gzvrs4ivdby)


ここまでで一旦、クライアント（Unity）側の作業は終了

## サーバー側の環境構築

### プロジェクトの作成

- VisualStudioで新しいプロジェクトをgRPCサービスを作成
- .NET 5.0を利用するように変更

![](https://storage.googleapis.com/zenn-user-upload/4e8ezy8s4axqrbydzeh1dg4hk4fw)

![](https://storage.googleapis.com/zenn-user-upload/zx6k510oe4re3nn9lv5yhyf22ynw)

![](https://storage.googleapis.com/zenn-user-upload/qrj6wchbaafzy8bdbnkbka5w98fv)

### 不要なファイルの削除

- Protos、ServicesはMagicOnionを利用する上で不要なので削除

![](https://storage.googleapis.com/zenn-user-upload/eahcebl2uvan76xf3sv51xnj5ymp)

### MagicOnion.Serverを追加

- NuGetで`MagicOnion.Server`を`MyApp-Server`に対して追加

![](https://storage.googleapis.com/zenn-user-upload/41dzv1jtnwt8kbafir39fl0gd9oc)


### Startup.csの修正

```diff:Startup.cs
 using Microsoft.AspNetCore.Builder;
 using Microsoft.AspNetCore.Hosting;
 using Microsoft.AspNetCore.Http;
 using Microsoft.Extensions.DependencyInjection;
 using Microsoft.Extensions.Hosting;

 namespace MyApp
 {
     public class Startup
     {
         public void ConfigureServices(IServiceCollection services)
         {
             services.AddGrpc();
+            services.AddMagicOnion(); // Add this line
         }
         public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
             if (env.IsDevelopment())
             {
                 app.UseDeveloperExceptionPage();
             }
             app.UseRouting();
             app.UseEndpoints(endpoints =>
             {
                 // Replace to this line instead of MapGrpcService<GreeterService>()
+                endpoints.MapMagicOnionService();
-                endpoints.MapGrpcService<GreeterService>();
                 endpoints.MapGet("/", async context =>
                 {
                     await context.Response.WriteAsync("Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");
                 });
             });
         }
     }
 }
```

### 共有プロジェクトの作成

- ソリューションエクスプローラーから新しいプロジェクトを追加
  - MyApp-Shared
![](https://storage.googleapis.com/zenn-user-upload/lp19azyt95y0n2izqaxmtrs0qm19)

- クラスライブラリ(.NET Standard)で作成

![](https://storage.googleapis.com/zenn-user-upload/ox4x10dbu1gifktto870ejh92rw8)

![](https://storage.googleapis.com/zenn-user-upload/e0el3aj3rboe9srs03xf8pwp38yj)


### MagicOnion.Abstractionsを追加

- NuGetで`MagicOnion.Abstractions`を`MyApp-Shared`に対して追加

![](https://storage.googleapis.com/zenn-user-upload/x9cr1sd70p7zmr8um35mt7dgmbhq)

### MessagePack.UnityShimsを追加

- NuGetで`MessagePack.UnityShims`を`MyApp-Shared`に対して追加

![](https://storage.googleapis.com/zenn-user-upload/9eyy9f3h62b6q1r2u3jlenzdjg5n)

### クライアント（Unity）のShared配下を参照

- MyApp-Shared.csprojを開いてクライアントで作成したShared配下を参照する

![](https://storage.googleapis.com/zenn-user-upload/3h2bra3gzr6st4vqdz2skjg0dhq0)

```diff:MyApp-Shared.csproj
 <Project Sdk="Microsoft.NET.Sdk">

   <PropertyGroup>
     <TargetFramework>netstandard2.0</TargetFramework>
     <RootNamespace>MyApp.Shared</RootNamespace>
   </PropertyGroup>

   <ItemGroup>
     <PackageReference Include="MagicOnion.Abstractions" Version="4.1.2" />
     <PackageReference Include="MessagePack.UnityShims" Version="2.2.85" />
   </ItemGroup>

+  <ItemGroup>
+    <Compile Include="..\MyApp-Client\Assets\Scripts\MyApp\Shared\**\*.cs" />
+  </ItemGroup>
</Project>
```

### MyApp-ServerにMyApp-Sharedの参照を追加

- ソリューションエクスプローラーからプロジェクを参照でMyApp-Sharedを選択

![](https://storage.googleapis.com/zenn-user-upload/ofmkx9lfy49iesd3hen5jtjmpq6k)

![](https://storage.googleapis.com/zenn-user-upload/0okvlhptqg9wdwf736vmreuwswjh)


### Serviceの作成


```cs:services/MyFirstService.cs
using System;
using MagicOnion;
using MagicOnion.Server;
using MyApp.Shared.Services;

namespace MyApp.Services
{
    // Implements RPC service in the server project.
    // The implementation class must inehrit `ServiceBase<IMyFirstService>` and `IMyFirstService`
    public class MyFirstService : ServiceBase<IMyFirstService>, IMyFirstService
    {
        // `UnaryResult<T>` allows the method to be treated as `async` method.
        public async UnaryResult<int> SumAsync(int x, int y)
        {
            Console.WriteLine($"Received:{x}, {y}");
            return x + y;
        }
    }
}
```

## 接続確認

### サーバーの起動

- F5などでサーバーを起動
- 下記のようなログが出れば起動OK

```
"C:\Program Files\dotnet\dotnet.exe" D:/MagicOnion/MyApp/MyApp-Server/bin/Debug/net5.0/MyApp-Server.dll
info: Microsoft.Hosting.Lifetime[0]
      Now listening on: http://localhost:5000
info: Microsoft.Hosting.Lifetime[0]
      Now listening on: https://localhost:5001
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Development
info: Microsoft.Hosting.Lifetime[0]
      Content root path: D:\MagicOnion\MyApp\MyApp-Server
```

### クライアント（Unity）のシーンを実行

- SampleSceneを実行してコンソールにログが出ればOK

![](https://storage.googleapis.com/zenn-user-upload/m68ds50385kg6bhkcnh7zceoc8hh)

- サーバー側にもログが出力されているはず

```
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[0]
      Executing endpoint 'gRPC - /IMyFirstService/SumAsync'
Received:750, 621
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[1]
      Executed endpoint 'gRPC - /IMyFirstService/SumAsync'
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/2 POST http://localhost:5000/IMyFirstService/SumAsync application/grpc - - 200 - application/grpc 78.6627ms
```


## 参考

- [Unity + .NET Core + MagicOnion v3 環境構築ハンズオン](https://qiita.com/_y_minami/items/db7b19eb5979ef1d6fe9)
- [Amazon Linux 2 上に .NET 5 と MagicOnion を使ったゲームサーバー開発環境作ってみた](https://dev.classmethod.jp/articles/create-dev-env-for-dotnet-5-and-magiconion-on-amazon-linux-2-ec2/)
- @[slideshare](HsFf8no1fEhBST)
- @[slideshare](Gfd2wf6fsBsj3y)
