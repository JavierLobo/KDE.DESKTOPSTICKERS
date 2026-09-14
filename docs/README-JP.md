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

KDE Plasma デスクトップ向けのフローティング付箋アプリです。Qt6/QML
で書かれたスタンドアロンアプリケーションで、プラズモイドではなく通常
のプログラムとしてインストールされ、自動起動に対応しています。各付箋
は装飾のない独立したウィンドウとして表示され、位置とサイズは永続的に
保存されます。また、付箋ごとに全ての仮想デスクトップへの表示(ピン留
め)をオプトインで選択できます。

<p align="center">
  <img src="../img/screenshot-desktop.png" alt="KDE Plasma デスクトップ上のフローティング付箋" width="720">
</p>

## 必要要件

- Plasma 6.x(6.7.4 で動作確認済み)および KWin、Wayland セッション
- Qt 6.4+(`Core`、`Gui`、`Qml`、`Quick`、`Widgets`、`DBus`)
- CMake、Bash

## インストール

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

バイナリをビルドし、`~/.local/bin/desktop-stickers` にインストールし
て、自動起動を登録します。初回起動、サンプルデータ、トラブルシューテ
ィングを含む完全なガイドは [QUICKSTART-JP.md](QUICKSTART-JP.md) を、
手動確認用のチェックリストは `QA_CHECKLIST.md` を参照してください。

## 機能

- トレイアイコン、または既存の付箋の「+」ボタンから新しい付箋を作成
  します(元の付箋から少しずらした位置にカスケード表示されます)。id
  は連番で採番されます
- デスクトップ上でのドラッグ(`Window.startSystemMove()` による実際
  のウィンドウ移動)に対応しています。実際の位置(Qt ではなく KWin が
  報告する値)はドラッグのたびに保存され、付箋ごとの KWin ウィンドウ
  ルール(`desktopstickers-sticker-<id>`)を通じて再起動後も復元され
  ます
- 右下端からのリサイズに対応し、サイズも位置と同じ仕組みで保存・復元
  されます
- 付箋ごとのピン留め(📍/📌 ボタン):同じ付箋の KWin ウィンドウルール
  を通じて、個別にオプトインすることでその付箋を全ての仮想デスクトッ
  プに同時表示できます。ピン留めしない場合、付箋は作成または移動した
  先のデスクトップにのみ存在します。既定値は設定(デスクトップ)から
  変更可能で、初期状態では新規付箋はピン留めなしで作成されます
- **フル Markdown** でのテキスト編集(見出し、表、コード、引用、リス
  ト、太字/斜体、リンク、チェックボックス)に対応し、クリックで編集
  モードに切り替わり、フォーカスを外すとレンダリング済みプレビューに
  自動的に戻ります
- 編集中に表示される**Markdown 書式設定ツールバー**:太字、斜体、取
  り消し線、見出し(H1〜H3)、箇条書きリスト、番号付きリスト、タスク
  リスト、リンク、画像、インラインコード、引用、コードブロック、水平
  線、表(行/列数を選択可能)。各ボタンは選択範囲に対してトグル動作
  し、それぞれ独自のキーボードショートカットを持ちます。付箋が縮小す
  ると、優先度の低いボタンから順に右から左へと「その他のオプション」
  ボタンの中に折りたたまれていきます。ツールバー全体は付箋のヘッダー
  から非表示にでき、設定で既定を非表示にすることもできます
- プレビューではリンクをクリックでき(システムの URL ハンドラーで開
  きます)、フェンス付きコードブロックは背景色を分けた枠内に表示され
  ます
- コンテンツはスクロール可能です:長い付箋でも内容が付箋からはみ出す
  ことはなく、編集領域は入力中もカーソルが見えるよう自動的にスクロー
  ルします
- 背景色:ランダム、システムアクセントカラー(Plasma のテーマにリア
  ルタイムで追従)、または自分で選んだ固定色から選択でき、設定(外
  観)で変更できます
- 設定からフォントファミリーとサイズを設定可能:優先順位付きのリスト
  (例:「Times New Roman」→「Liberation Serif」)の中から、実際にマ
  シンにインストールされている最初のフォントが使用されます。ポイント
  サイズも設定できます
- 付箋ごとの名前は Stickers Panel から編集できます。未設定の場合はテ
  キストの先頭にある空でない行から自動的に導出されます(先頭の `#`
  見出し記号は除去されます)。付箋のヘッダー(`#<id> | <名前または
  フォールバック>`)とトレイメニュー/パネルのどちらでも 30 文字に切り
  詰められます
- **Stickers Panel**:件数制限のない完全な一覧で、検索、並べ替え(最
  近の更新順/アルファベット順/色順)、クリックで開く、コンテキストメ
  ニュー(開く、名前変更、複製)、複数選択、そして確認(任意)と数秒
  間の取り消しを伴う削除に対応しています
- システムトレイアイコンには直近に更新された付箋が最大 10 件(ページ
  分割なし)表示され、各行をクリックするとその付箋を開く、または前面
  に表示します
- 付箋の「✕」ボタンはウィンドウを閉じるだけです — 付箋データ自体は残
  り、トレイメニューまたは Panel から再度開くことができます。付箋の
  削除は独立した操作であり、常に取り消しオプションを伴います
- **設定パネル**(トレイアイコンを右クリック →「オプション」→「設
  定」):外観(色/フォント)、動作(Markdown ツールバーの既定表示、
  削除確認、トレイ左クリック時の動作)、システム(自動起動、「フォル
  ダを開く」ボタン付きのデータパス、エクスポート/インポートによるバ
  ックアップ)、言語の各項目があります
- **多言語インターフェース**:設定内の言語セレクターでは、各言語名が
  その言語自身の表記(例:「Spanish」ではなく「Español」)で国旗の隣
  に表示されます。スペイン語、英語、フランス語、ロシア語を標準搭載し
  ており、各言語は `src/i18n/` 以下の独立した JSON ファイルとして管
  理され、ビルド時・実行時の両方で自動検出されます
- トレイメニューの**「オプション」サブメニュー**:ヘルプ(GitHub 上の
  ドキュメント)、寄付(開発者を支援)、ライセンスを表示、設定、この
  アプリについて、の各項目があります
- シングルインスタンス:アプリが既に実行中の場合、再度起動しても重複
  したコピーは開きません
- セッション途中で KWin が再起動した場合(クラッシュや
  `kwin_wayland --replace`)も自動的に復旧します:アプリを再起動しな
  くても、位置の永続化は自動的に再接続されます
- インストーラーは、過去のセッションで削除された付箋の孤立した KWin
  ルールを掃除します
- 標準的な freedesktop の `.desktop` エントリによる自動起動に対応
  (Plasma の「バックグラウンドサービス」は使用しません)。設定から
  切り替え可能です

<p align="center">
  <img src="../img/Desktop-stickers-markdown.png" alt="Markdown がレンダリングされた付箋の例:見出し、表、コードブロック" width="720">
</p>

## データ保存

Desktop Stickers は **XDG Base Directory** 標準に準拠しています —
ホームディレクトリ直下に専用の単独フォルダを置くことはありません。

付箋は `$XDG_DATA_HOME/desktop-stickers/stickers.json`(通常は
`~/.local/share/desktop-stickers/stickers.json`)に保存されます:

```json
{
  "stickers": [
    {
      "id": "001",
      "name": "",
      "text": "Markdown コンテンツ",
      "color": "#FFD700",
      "x": 100,
      "y": 200,
      "width": 300,
      "height": 250,
      "pinned": false,
      "fontFamily": "Liberation Serif",
      "fontSize": 10,
      "created": "2026-08-17T10:30:00Z",
      "modified": "2026-08-17T15:45:00Z"
    }
  ]
}
```

アプリの各種設定は別に `$XDG_CONFIG_HOME/desktop-stickers/settings.json`
(通常は `~/.config/desktop-stickers/settings.json`)に保存されます
— 外観、動作、自動起動、言語の設定が含まれます。

> v1.1.0 より前のバージョンからアップグレードする場合: 新しいバイナ
> リを初めて実行した際に、データは古い `~/.stickers/` パスから上記
> の 2 つの XDG パスへ自動的に、かつ意識せずに移行されます。手動で
> の作業は不要です。

## ダウンロード

公開されている全てのバージョンはリポジトリの
[Releases](https://github.com/JavierLobo/KDE.DESKTOPSTICKERS/releases)
ページにあり、それぞれソースコードとリリースノートが付属しています。

## ライセンス

GPL-3.0
