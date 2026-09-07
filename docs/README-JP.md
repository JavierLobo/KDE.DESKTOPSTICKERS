<p align="center">
  <img src="../img/logo-sticker.png" alt="Desktop Stickers ロゴ" width="120">
</p>

<h1 align="center">Desktop Stickers</h1>

<p align="center">
  <a href="../LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue.svg"></a>
  <a href="README-SP.md"><img alt="ES" src="https://img.shields.io/badge/lang-ES-red.svg"></a>
  <a href="README-IT.md"><img alt="IT" src="https://img.shields.io/badge/lang-IT-green.svg"></a>
  <a href="README-EN.md"><img alt="EN" src="https://img.shields.io/badge/lang-EN-blue.svg"></a>
  <a href="README-DE.md"><img alt="DE" src="https://img.shields.io/badge/lang-DE-orange.svg"></a>
  <a href="README-RU.md"><img alt="RU" src="https://img.shields.io/badge/lang-RU-blueviolet.svg"></a>
  <a href="README-CN.md"><img alt="CN" src="https://img.shields.io/badge/lang-CN-yellow.svg"></a>
  <a href="README-JP.md"><img alt="JP" src="https://img.shields.io/badge/lang-JP-lightgrey.svg"></a>
</p>

KDE Plasma デスクトップ向けのフローティング付箋アプリです。プラズモイ
ドではなく、通常のプログラムとしてインストールされスタンドアロンで動
作する Qt6/QML アプリケーションで、自動起動に対応しています。各付箋は
装飾のない独立したウィンドウとして表示され、位置とサイズは永続的に保
存され、付箋ごとに全ての仮想デスクトップへの表示(ピン留め)をオプト
インで選択できます。

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="KDE Plasma デスクトップ上のフローティング付箋" width="720">
</p>

## 必要要件

- Plasma 6.x(6.7.4 で動作確認済み)および KWin、Wayland セッション
- Qt 6.5+(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- CMake、Bash

## インストール

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

バイナリをビルドし、`~/.local/bin/desktop-stickers` にインストールし、自動
起動を登録します。詳しいガイド(初回起動、サンプルデータ、トラブルシ
ューティング)は [QUICKSTART-JP.md](QUICKSTART-JP.md) を、手動確認用
チェックリストは `QA_CHECKLIST.md` を参照してください。

## 機能

- トレイアイコン、または既存の付箋の "+" ボタンから新しい付箋を作成
  (元の付箋から少しずらした位置にカスケード表示され)、id は連番にな
  ります
- デスクトップ上でのドラッグ(`Window.startSystemMove()` による実際の
  移動)。実際の位置(Qt ではなく KWin から報告される値)はドラッグの
  たびに保存され、付箋ごとの KWin ウィンドウルール
  (`desktopstickers-sticker-<id>`)により再起動後も復元されます
- 右下端からのリサイズに対応し、サイズも位置と同様に保存・復元されます
- 付箋ごとのピン留め(📍/📌 ボタン):個別にオプトインすることで、その
  付箋を同じ KWin ウィンドウルールを通じて全ての仮想デスクトップに同時
  表示できます。ピン留めしない場合、付箋は作成または移動した先のデス
  クトップにのみ存在します。新規付箋は既定でピン留めなしの状態で作成
  されます
- **フル Markdown** でのテキスト編集(見出し、表、コード、引用、リス
  ト、太字/斜体、リンク、チェックボックス)に対応し、クリックで編集
  モードに、フォーカスを外すとレンダリング済みプレビューに自動的に切
  り替わります
- プレビューではリンクをクリックでき(システムの URL ハンドラーで開き
  ます)、コードブロックは背景色を分けた枠内に表示されます
- コンテンツはスクロール可能:長い付箋でも内容が付箋からはみ出すこと
  はなく、編集領域は入力中もカーソルが見えるよう自動的にスクロールし
  ます
- 背景色:6 色のパステルカラーからなる固定パレット(新規付箋ごとにラ
  ンダムに割り当て)、または自由な色選択
- 付箋ごとの名前を Stickers Panel から編集可能。未設定の場合はテキス
  トの先頭にある空でない行から自動的に導出されます(先頭の `#` 見出し
  記号は除去されます)。付箋のヘッダー(`#<id> | <名前またはフォール
  バック>`)とトレイメニュー/パネルの両方で 30 文字に切り詰められます
- システムトレイアイコンには、直近に更新された付箋が最大 10 件(ページ
  分割なし)表示され、各行をクリックするとその付箋を開く、または前面
  に表示します。同じメニュー内の「Stickers Panel」を開くと、件数制限
  のない完全なリストのウィンドウが表示され、各付箋の「開く」「名前変
  更」「削除(確認あり)」が行えます
- 付箋の "✕" ボタンはウィンドウを閉じるだけです — 付箋データ自体は残
  り、トレイメニューから再度開くことができます。付箋の削除は独立した
  操作であり、Stickers Panel からのみ実行でき、常に確認を求められま
  す。削除すると、対応する KWin ウィンドウルールも合わせて削除されます
- `~/.stickers/stickers.json` へのデータ永続化
- シングルインスタンス:アプリが既に実行中の場合、再度起動しても重複
  したコピーは開きません
- セッション途中で KWin が再起動した場合(クラッシュや
  `kwin_wayland --replace`)も自動的に復旧します:アプリを再起動しな
  くても、位置の永続化は自動的に再接続されます
- インストーラーは、過去のセッションで削除された付箋の孤立した KWin
  ルールを掃除します
- 標準的な freedesktop の `.desktop` エントリによる自動起動(Plasma の
  「バックグラウンドサービス」は使用しません)

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Markdown がレンダリングされた付箋の例:見出し、表、コードブロック" width="720">
</p>

## データ保存

付箋は `~/.stickers/stickers.json` に保存されます:

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Contenido en Markdown",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

## ダウンロード

公開されている全てのバージョンはリポジトリの
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
ページにあります。各バージョンにはソースコードとリリースノートが
付属しています。

## ライセンス

GPL-3.0
