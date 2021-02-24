---
title: "Unity+MagicOnion4.1.xを試す StreamingHubでのリアルタイム通信編"
emoji: "🔖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["magiconion","grpc","unity","aspnetcore"]
published: true
---

## チャプター

- [環境構築&サービスでの通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-service)
- [StreamingHubでのリアルタイム通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-streaming-hub)
- [サーバーをEC2環境で動かす編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-aws-ec2-nginx)


## まえがき

- [環境構築&サービスでの通信編](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-service)の続きになります
- 環境構築、前提等は上記の記事を参照してください
- サンプルで利用しているコードはMagicOnionのREADMEをほぼ利用しています

:::message alert
接続の動作確認として作成しているのでマジックナンバーを利用していたり、エラーハンドリングをきちんと行っていないですがご了承ください
:::

## クライアント（Unity）の環境構築


### クライアント <-> サーバー共通クラスの作成

```cs:Assets/Scripts/MyApp/Shared/MessagePackObjects/Player.cs
using MessagePack;
using UnityEngine;

namespace MyApp.Shared.MessagePackObjects
{
    [MessagePackObject]
    public class Player
    {
        [Key(0)] public string Name { get; set; }
        [Key(1)] public Vector3 Position { get; set; }
        [Key(2)] public Quaternion Rotation { get; set; }
    }
}
```

### サーバーと接続するためのインタフェースを作成

```cs:Assets/Scripts/MyApp/Shared/Hubs/IGamingHub.cs
using System.Threading.Tasks;
using MagicOnion;
using MyApp.Shared.MessagePackObjects;
using UnityEngine;

namespace MyApp.Shared.Hubs
{
    public interface IGamingHubReceiver
    {
        // return type shuold be `void` or `Task`, parameters are free.
        void OnJoin(Player player);
        void OnLeave(Player player);
        void OnMove(Player player);
    }

// Client -> Server definition
// implements `IStreamingHub<TSelf, TReceiver>`  and share this type between server and client.
    public interface IGamingHub : IStreamingHub<IGamingHub, IGamingHubReceiver>
    {
        // return type shuold be `Task` or `Task<T>`, parameters are free.
        Task<Player[]> JoinAsync(string roomName, string userName, Vector3 position, Quaternion rotation);
        Task LeaveAsync();
        Task MoveAsync(Vector3 position, Quaternion rotation);
    }
}
```

### サーバーとの接続用クラス作成

```cs:Assets/Scripts/MyApp/GamingHubClient.cs
using System.Collections.Generic;
using System.Threading.Tasks;
using Grpc.Core;
using MagicOnion.Client;
using MyApp.Shared.Hubs;
using MyApp.Shared.MessagePackObjects;
using UnityEngine;

namespace MyApp
{
    public class GamingHubClient : IGamingHubReceiver
    {
        Dictionary<string, GameObject> _players = new Dictionary<string, GameObject>();
        IGamingHub _client;

        public async Task<GameObject> ConnectAsync(Channel grpcChannel, string roomName, string playerName)
        {
            _client = StreamingHubClient.Connect<IGamingHub, IGamingHubReceiver>(grpcChannel, this);

            var roomPlayers = await _client.JoinAsync(roomName, playerName, Vector3.zero, Quaternion.identity);
            foreach (var player in roomPlayers)
            {
                (this as IGamingHubReceiver).OnJoin(player);
            }

            return _players[playerName];
        }

        // methods send to server.

        public Task LeaveAsync()
        {
            return _client.LeaveAsync();
        }

        public Task MoveAsync(Vector3 position, Quaternion rotation)
        {
            return _client.MoveAsync(position, rotation);
        }

        // dispose client-connection before channel.ShutDownAsync is important!
        public Task DisposeAsync()
        {
            return _client.DisposeAsync();
        }

        // You can watch connection state, use this for retry etc.
        public Task WaitForDisconnect()
        {
            return _client.WaitForDisconnect();
        }

        // Receivers of message from server.

        void IGamingHubReceiver.OnJoin(Player player)
        {
            Debug.Log("Join Player:" + player.Name);

            var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.name = player.Name;
            cube.transform.SetPositionAndRotation(player.Position, player.Rotation);
            _players[player.Name] = cube;
        }

        void IGamingHubReceiver.OnLeave(Player player)
        {
            Debug.Log("Leave Player:" + player.Name);

            if (_players.TryGetValue(player.Name, out var cube))
            {
                GameObject.Destroy(cube);
                _players.Remove(player.Name);
            }
        }

        void IGamingHubReceiver.OnMove(Player player)
        {
            Debug.Log("Move Player:" + player.Name);

            if (_players.TryGetValue(player.Name, out var cube))
            {
                cube.transform.SetPositionAndRotation(player.Position, player.Rotation);
            }
        }
    }
}
```

### コントローラーを修正

- 大本は[こちら](https://zenn.dev/hrs/articles/magiconion-v4-1-x-unity-service)にあります

```diff:Assets/Scripts/MyApp/MyFirstController.cs
     public class MyFirstController : MonoBehaviour
     {
         private Channel _channel;
         private IMyFirstService _service;
+        private GamingHubClient _hub;
+        private float _moveTimer;
+        private float _leaveTimer;
```

```diff:Assets/Scripts/MyApp/MyFirstController.cs
         async void Start()
         {
             var x = Random.Range(0, 1000);
             var y = Random.Range(0, 1000);
             var result = await _service.SumAsync(x, y);
             Debug.Log($"Result: {result}");

+            var id = Random.Range(0, 10000);
+            _hub = new GamingHubClient();
+            await _hub.ConnectAsync(_channel, "Room", $"Player-{id}");
        }
```

```diff:Assets/Scripts/MyApp/MyFirstController.cs
+        async void Update ()
+        {
+            if (_hub == null)
+            {
+                return;
+            }
+            _moveTimer += Time.deltaTime;
+
+            if(_moveTimer > 1f){
+                _moveTimer = 0f;
+                var x = Random.Range(-10, 10);
+                var y = Random.Range(-5, 5);
+                await _hub.MoveAsync(new Vector3(x, y), new Quaternion());
+            }
+            if (_leaveTimer > 30f)
+            {
+                await _hub.LeaveAsync();
+            }
+        }
```

```diff:Assets/Scripts/MyApp/MyFirstController.cs
         async void OnDestroy()
         {
+            if (_hub != null)
+            {
+                await _hub.DisposeAsync();
+            }
             if (_channel != null)
             {
                 await _channel.ShutdownAsync();
             }
         }
```

- 完成したクラス

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
        private GamingHubClient _hub; // 追加
        private float _moveTimer;
        private float _leaveTimer;

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

            // 追加
            var id = Random.Range(0, 10000);
            _hub = new GamingHubClient();
            await _hub.ConnectAsync(_channel, "Room", $"Player-{id}");
        }
        
        // 追加
        async void Update ()
        {
            if (_hub == null)
            {
                return;
            }
            _moveTimer += Time.deltaTime;
            _leaveTimer += Time.deltaTime;

            if(_moveTimer > 1f){
                _moveTimer = 0f;
                var x = Random.Range(-10, 10);
                var y = Random.Range(-5, 5);
                await _hub.MoveAsync(new Vector3(x, y), new Quaternion());
            }

            if (_leaveTimer > 30f)
            {
                await _hub.LeaveAsync();
            }
        }

        async void OnDestroy()
        {
            // 追加
            if (_hub != null)
            {
                await _hub.DisposeAsync();
            }
            if (_channel != null)
            {
                await _channel.ShutdownAsync();
            }
        }
    }
}

```

ここまでで一旦、クライアント（Unity）側の作業は終了

## サーバー側の環境構築


### StreamingHubの作成


```cs:hubs/GamingHub.cs
using System.Linq;
using System.Threading.Tasks;
using MagicOnion.Server.Hubs;
using MyApp.Shared.Hubs;
using MyApp.Shared.MessagePackObjects;
using UnityEngine;

namespace MyApp.Hubs
{
    public class GamingHub : StreamingHubBase<IGamingHub, IGamingHubReceiver>, IGamingHub
    {
        // this class is instantiated per connected so fields are cache area of connection.
        IGroup _room;
        Player _self;
        IInMemoryStorage<Player> _storage;

        public async Task<Player[]> JoinAsync(string roomName, string userName, Vector3 position, Quaternion rotation)
        {
            _self = new Player {Name = userName, Position = position, Rotation = rotation};

            // Group can bundle many connections and it has inmemory-storage so add any type per group. 
            (_room, _storage) = await Group.AddAsync(roomName, _self);

            // Typed Server->Client broadcast.
            BroadcastExceptSelf(_room).OnJoin(_self);

            return _storage.AllValues.ToArray();
        }

        public async Task LeaveAsync()
        {
            Broadcast(_room).OnLeave(_self);
            await _room.RemoveAsync(Context);
        }

        public async Task MoveAsync(Vector3 position, Quaternion rotation)
        {
            _self.Position = position;
            _self.Rotation = rotation;
            Broadcast(_room).OnMove(_self);
        }

        // You can hook OnConnecting/OnDisconnected by override.
        protected override async ValueTask OnDisconnected()
        {
            // on disconnecting, if automatically removed this connection from group.
            await CompletedTask;
        }
    }
}
```

## 接続確認

### クライアント（Unity）のシーンを実行

- 出来ればビルドしてクライアントが複数ある状態にしたほうがわかりやすいです
- サーバーに座標が届いて、すべてのクライアントに移動処理が走っていればOK

![](https://storage.googleapis.com/zenn-user-upload/zx7u4og6z4h1d01dl1o34u2bqn5x)