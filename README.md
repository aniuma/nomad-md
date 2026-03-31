# Nomad — Markdown Viewer（ノマド マークダウンビューア）

AI エージェントが生成した Markdown を、まとめて・すばやく・きれいに閲覧する macOS アプリ

[Download](../../releases) ・ [全機能一覧](docs/FEATURES.md)

---

<!-- <p align="center"><img src="docs/screenshots/main.png" width="800"></p> -->

Claude, ChatGPT, Cursor ── AI エージェントを使っていると、PRD・設計書・議事録・ナレッジベースなど大量の Markdown ファイルがプロジェクトごとに生まれます。Nomad は、それぞれ別のディレクトリに散らばるこれらのファイルを **横断的に閲覧・検索** するためのビューアです。

- **複数フォルダをサイドバーに登録** するだけ。`.md` ファイルを自動で拾い出します
- 登録フォルダ全体を対象にした **全文検索・索引** で、目的のドキュメントにすぐたどり着けます
- Finder のフォルダ構造をそのまま使う **No Database** 設計。独自ファイルを一切作りません
- ビューア特化ですが、`Cmd+E` で編集モードにも切り替えられます

## 主な機能

### 表示・コンテンツ

5 種類のテーマ（Default / GitHub / Minimal / Technical / Notion）に加え、カスタム CSS も適用可能。日本語に最適化されたタイポグラフィで、ドキュメントを読みやすく表示します。

- **YouTube / Twitter / Gist** — URL を貼るだけでそのままインライン表示
- **セクション折りたたみ** / **読了時間** — 長いドキュメントでも必要な箇所にフォーカス
- **YAML Front Matter** — ファイル冒頭のメタデータ（タイトル、タグ、日付など）をテーブル表示。タグでのフィルタにも対応
- **Callout（注意書き）** — `[!NOTE]` `[!WARNING]` 等、GitHub スタイルの強調ブロック
- **タスクリスト・脚注** — チェックボックスや参照注をそのまま表示
- **KaTeX 数式 / Mermaid ダイアグラム** — 数式やフローチャートをコードブロックから描画

### ナビゲーション・検索

- **目次（TOC）** — ドキュメント内の見出しを右サイドバーに常時表示。スクロールに追従してハイライト
- **クイックオープン** `Cmd+P` — ファイル名で即ジャンプ。`#` を付ければ全ファイルの見出しを横断検索
- **全文検索** `Cmd+Shift+F` — 登録フォルダ内の全 .md を対象にテキスト検索（正規表現対応）
- **索引** `Cmd+Shift+I` — 登録フォルダ全体の見出しをトピック別に一覧表示
- **内部リンク** — .md 内の相対リンクをクリックでアプリ内遷移。リンク切れは自動検出・警告

### タブ・ファイル管理

ファイルをクリックすると**プレビュータブ**で表示されます（次のファイルをクリックすると入れ替わる）。タブをダブルクリックして**ピン留め**すると、複数ファイルを同時に開いたまま切り替えられます。

- Finder から `.md` をダブルクリックで Nomad に直接オープン
- 複数フォルダをサイドバーに登録。ファイルの追加・変更を自動検知して反映
- 最近使った項目 `Cmd+Shift+R`

### 編集

`Cmd+E` でビューア ↔ エディタを切り替え。`Cmd+\` で左右に並べて分割表示。

- Markdown 構文ハイライト、自動保存
- 新規ファイル作成、画像の D&D 挿入

### エクスポート

- **HTML / PDF** にエクスポート。HTML は CSS/JS インラインで単体で開けるファイルを生成
- **Quick Look** — Finder 上でスペースキーを押すだけで Markdown をプレビュー
- **共有メニュー** — 右クリック → 共有から HTML/PDF に変換
- 外観モード — システム / ライト / ダーク 切替

## インストール

[Releases](../../releases) から `.dmg` をダウンロード → `Nomad.app` を Applications にドラッグ。

<details>
<summary>ソースからビルド</summary>

```bash
cd md-tool/md-tool
xcodebuild -scheme md-tool -destination 'platform=macOS' build
```

</details>

## キーボードショートカット

| キー | 機能 |
|---|---|
| `Cmd+P` | クイックオープン |
| `Cmd+E` | ビューア / 編集切替 |
| `Cmd+\` | 分割表示 |
| `Cmd+W` | タブを閉じる |
| `Cmd+Shift+F` | 全文検索 |
| `Cmd+Shift+I` | 索引 |
| `Cmd+Shift+T` | 目次の表示 / 非表示 |
| `Cmd+Shift+R` | 最近使った項目 |
| `Cmd+,` | 設定 |

## ドキュメント

- [全機能一覧](docs/FEATURES.md) — 全機能の詳細リファレンス
- [機能要件](docs/functional-requirements.md) — 設計・仕様の詳細
- [デザインログ](docs/design-log.md) — UI/UX の設計経緯

## 技術情報

macOS 26.2+（Liquid Glass 対応）/ SwiftUI + WKWebView / [swift-markdown](https://github.com/swiftlang/swift-markdown) / MVVM（@Observable）/ No Database

## ライセンス

MIT
