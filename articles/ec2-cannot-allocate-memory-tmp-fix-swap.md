---
title: "EC2のメモリ不足をスワップファイル作って一時的に対応！！"
emoji: "🧠"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["ec2","linux"]
published: true
---

## まえがき

- nanoやmicroインスタンスを利用していると、yumやcomposerがメモリ不足で動かないことがある
- そのためだけに、インスタンスタイプを変えるのは大変なので一時しのぎをしていく
- EC2って書いてあるけど、EC2に限った話じゃないはずです

## 確認環境

## 手順

### スワップ用ファイルを作成

```bash
$ sudo fallocate -l 512M /swapfile
$ sudo chmod 600 /swapfile
```

- `dd` でも良いはず？

### スワップの作成と有効化

```bash
$ sudo mkswap /swapfile
$ sudo swapon /swapfile
```

### スワップの確認

```bash
$ sudo swapon -s
ファイル名                              タイプ          サイズ  使用済み        優先順位
/swapfile                               file            524284  0       -2
```
- 情報が表示されていればOK

### 失敗したコマンドを実行

- yumでもなんでも、実行してみる
- まだメモリ不足になるようであればスワップを増やしてみる

### スワップの無効化

```bash
$ sudo swapoff /swapfile
$ sudo swapon -s
```
- `swapon -s` で何も表示されていなければOK

### スワップ用ファイルの削除

```bash
$ sudo rm /swapfile
```
