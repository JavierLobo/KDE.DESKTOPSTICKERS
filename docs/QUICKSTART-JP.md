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

これにより Qt6 バイナリ(`build/desktop-stickers`)がビルドされ、
`~/.local/bin/desktop-stickers` にインストールされて、
`~/.config/autostart/io.github.javierlobo.desktopstickers.desktop` に
自動起動が登録されます。

## 初回起動

次回の Plasma セッションでアプリは自動的に起動します。ログアウトせず
に今すぐ試すには:

```bash
~/.local/bin/desktop-stickers &
```

システムトレイにアイコン(「Desktop Stickers」)が表示されるはずで
す。既に付箋を保存済みの場合、そのウィンドウは最後の実際の位置(付箋
ごとの KWin ルールにより永続化されたもの — `QA_CHECKLIST.md` を参
照)に表示されます。データは
`$XDG_DATA_HOME/desktop-stickers/stickers.json`(通常は
`~/.local/share/desktop-stickers/`)以下に保存され、ホームディレクト
リ直下の単独フォルダには置かれません。

UI の言語は設定に保存されている値に従います(既定はスペイン語)。変
更するには: トレイアイコンを右クリック →**「オプション」→「設
定」→「言語」**。

## 最初の付箋を作成する

- トレイアイコンをクリック →「Nuevo sticker」、または
- 既存の付箋の「+」ボタンをクリック

## 編集

付箋の内部をクリックすると Markdown で編集できます — テキストエリア
の上部に書式設定ツールバー(太字、見出し、リスト、表、リンクなど)が
表示されます。外側をクリックするとレンダリング済みプレビューに戻りま
す。

## ピン留め(全デスクトップ)とリサイズ

- ヘッダーの 📍/📌 ボタン:その付箋を全ての仮想デスクトップに表示する
  (📌)か、自分のデスクトップのみに表示する(📍)かを切り替えます。新
  規付箋は既定でピン留めなしの状態で作成されます(設定で変更可能)。
- 右下端からドラッグしてサイズを変更します。

## 設定パネル

トレイアイコンを右クリック →**「オプション」→「設定」**でパネルが開
き、次の 4 つのセクションがあります:

- **外観**:新規付箋の既定色(ランダム、システムアクセントカラー、ま
  たは固定色)、フォントの優先順位リスト、フォントサイズ
- **動作**:Markdown ツールバーの既定表示、削除確認、トレイ左クリッ
  ク時の動作
- **システム**:自動起動の有効/無効、データパス(「フォルダを開く」
  ボタン付き)、エクスポート/インポートによるバックアップ
- **言語**:UI 言語セレクター

**オプション**サブメニューの残りの項目には、ヘルプ(GitHub 上のドキ
ュメント)、寄付(開発者を支援)、ライセンスを表示、このアプリについ
て、があります。

## Stickers Panel

トレイアイコンを左クリック(またはメニューの「Panel de Stickers」)
すると、完全な一覧が開きます:テキストによる検索、並べ替え(最近の更
新順/アルファベット順/色順)、クリックで付箋を開く、コンテキストメニ
ュー(開く、名前変更、複製)、複数選択による一括削除に対応していま
す。

## サンプルデータ

⚠️ このスクリプトは `stickers.json` を**上書き**します — 既に付箋を
作成済みの場合、失われます。新規インストール時のみ、または現在のデー
タを失っても構わない場合のみ使用してください。

```bash
chmod +x scripts/test-sticker.sh
./scripts/test-sticker.sh
```

サンプル付箋を 3 つ作成します。

## 完全な確認

全機能を網羅する手動チェックリストは `QA_CHECKLIST.md` を参照してく
ださい。

## トラブルシューティング

**バイナリがビルドできない:**
- Qt6(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)がインストー
  ルされているか確認してください
- 不足しているパッケージを確認するため `cmake -B build -S .` の出力
  を確認してください

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

**`src/i18n/` に追加した新しい言語が表示されない:**
- `src/i18n/es.json` と全く同じキー(`Language.name` と
  `Language.flag` を含む)が必要です。
- 再ビルド(`cmake --build build`)が必要です — 辞書の一覧は
  configure/build 時にのみ再検出され、既にインストール済みのアプリを
  起動しただけでは反映されません。

**ログ:**
```bash
journalctl --user -f
```
(このアプリは plasmashell の一部ではなく独立したプロセスなので、その
メッセージはユーザーセッションのログに出力されます。リアルタイムのコ
ンソール出力を見るには、ターミナルから直接 `~/.local/bin/desktop-stickers`
を実行するのが最も確実な方法です)
