# Desktop Stickers - クイックスタート

<p align="center">
  <a href="QUICKSTART-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="QUICKSTART-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="QUICKSTART-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="QUICKSTART-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="QUICKSTART-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="QUICKSTART-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="QUICKSTART-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

## インストール

```bash
cd <リポジトリのパス>  # リポジトリをクローンしたディレクトリに移動します
chmod +x scripts/install.sh
./scripts/install.sh
```

Qt6 バイナリ(`build/desktop-stickers`)をビルドし、`~/.local/bin/desktop-stickers`
にインストールして、`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop` に
自動起動を登録します。

## 初回起動

次回の Plasma セッションでアプリは自動的に起動します。ログアウトせず
に今すぐ試すには:

```bash
~/.local/bin/desktop-stickers &
```

システムトレイにアイコン(「Desktop Stickers」)が表示されるはずです。
`~/.stickers/stickers.json` に既に付箋が保存されている場合、そのウィ
ンドウは最後の実際の位置(付箋ごとの KWin ルールにより永続化されたも
の — `QA_CHECKLIST.md` を参照)に表示されます。

## 最初の付箋を作成する

- トレイアイコンをクリック →「Nuevo sticker」、または
- 既存の付箋の "+" ボタンをクリック

## 編集

付箋の内部をクリックすると Markdown で編集できます。外側をクリックす
るとレンダリング済みプレビューに戻ります。

## ピン留め(全デスクトップ)とリサイズ

- ヘッダーの 📍/📌 ボタン:その付箋を全ての仮想デスクトップに表示する
  (📌)か、自分のデスクトップのみに表示する(📍)かを切り替えます。新
  規付箋は既定でピン留めなしの状態で作成されます。
- 右下端からドラッグしてサイズを変更します。

## サンプルデータ

⚠️ このスクリプトは `~/.stickers/stickers.json` を**上書き**します —
既に付箋を作成済みの場合、失われます。新規インストール時のみ、また
は現在のデータを失っても構わない場合のみ使用してください。

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

`~/.stickers/stickers.json` にサンプル付箋を 3 つ作成します。

## 完全な確認

全機能の手動チェックリストは `QA_CHECKLIST.md` を参照してください。

## トラブルシューティング

**バイナリがビルドできない:**
- Qt6(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)がインストール
  されているか確認してください
- 不足しているパッケージを確認するため `cmake -B build -S .` の出力を
  確認してください

**付箋が全デスクトップに表示されない:**
- 「全デスクトップ」はアプリ全体のルールではなく、ヘッダーのピン留め
  ボタン(📍/📌)による**付箋ごと**のオプトインです — まずその付箋のピ
  ン留めが有効(📌)になっているか確認してください。
- ピン留めが有効なのに付箋がデスクトップ間で追従しない場合、その付箋
  固有の KWin ルールを確認してください:
  `kreadconfig6 --file kwinrulesrc --group desktopstickers-sticker-<id> --key desktopsrule`
  は `2`(Force)を返すはずです。`1` や空を返す場合、ピン留めが書き込
  まれていません — 📌 を再度クリックしてください。
- グループが登録されているかも確認してください:
  `kreadconfig6 --file kwinrulesrc --group General --key rules` に
  `desktopstickers-sticker-<id>` が含まれているはずです。
- 値は正しいのにリアルタイムに反映されない場合は、強制的に再読み込み
  します: `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`
- この仕組み(付箋ごとに 1 つ、ピン留めと位置で共有される KWin ルー
  ル)の完全な詳細は
  `superpowers/specs/2026-08-18-sticker-pin-position-resize-design.md`
  の「Arquitectura: de regla global a reglas por-ventana」セクション
  を参照してください

**ログ:**
```bash
journalctl --user -f
```
(このアプリは plasmashell の一部ではなく独立したプロセスなので、その
メッセージはユーザーセッションのログに出力されます。リアルタイムのコ
ンソール出力を見るには、ターミナルから直接 `~/.local/bin/desktop-stickers`
を実行するのが最も確実な方法です)
