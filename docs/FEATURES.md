# Nomad 全機能一覧

## プレビュー

- swift-markdown による AST→HTML 変換、WKWebView でレンダリング
- **テーマ 5 種**: Default（和文最適化）/ GitHub / Minimal（セリフ体）/ Technical（モノスペース）/ Notion
- カスタム CSS の追加適用
- 日本語タイポグラフィ最適化（Hiragino Kaku Gothic ProN、line-height 1.8、letter-spacing 0.03em）
- ファイル変更時の自動再レンダリング
- レンダリングキャッシュ（SHA256 ベース、最大 50 件）
- 見出しレベル警告 — h1→h3 等のスキップを検出し折りたたみ警告表示
- セクション単位コピー — 見出しホバーでコピーボタン表示
- セクション折りたたみ — 見出し単位で折りたたみ / 展開
- 読了時間表示 — 日本語 550 文字/分、英語 220 語/分

## リッチコンテンツ

| 記法 | 対応 |
|---|---|
| KaTeX 数式 | `$...$` インライン / `$$...$$` ブロック |
| Mermaid ダイアグラム | ` ```mermaid ` コードブロック |
| Callout / Admonition | `[!NOTE]` `[!TIP]` `[!WARNING]` `[!IMPORTANT]` `[!CAUTION]`（折りたたみ対応） |
| タスクリスト | `- [x]` / `- [ ]` チェックボックス |
| 脚注 | `[^id]` 参照と `[^id]:` 定義、文末に脚注セクション自動生成 |
| YAML Front Matter | メタデータを折りたたみ可能なテーブルで表示（タグ抽出対応） |
| oEmbed | YouTube / Twitter / Gist の URL 自動埋め込み |

## ナビゲーション・検索

- **TOC（目次）** — 右サイドバーに階層表示、スクロール追従ハイライト（Cmd+Shift+T）
- **クイックオープン（Cmd+P）** — ファイル名部分一致、`#` プレフィックスで見出し横断検索
- **全文検索（Cmd+Shift+F）** — 正規表現対応、大文字小文字区別、検索 & 置換
- **索引（Cmd+Shift+I）** — 全ファイルの見出し一覧、トピック分類、検索フィルタ付き
- **内部リンク遷移** — `.md` 相対リンクをクリックでアプリ内タブとして開く
- **リンク切れ検出** — 存在しない相対リンクを赤 + 打ち消し線で警告

## タブ・ウィンドウ

- **プレビュータブ** — クリックで開き、次のファイルで上書き。ダブルクリックでピン留め
- 複数ファイルをタブで管理（重複防止・コンテキストメニュー対応）
- Finder から `.md` ファイルをダブルクリックで直接オープン
- 単一ウィンドウ設計
- 最近使った項目（Cmd+Shift+R）、最大 20 件の履歴

## 編集

- プレビュー / 編集 / 分割モード（Cmd+E / Cmd+\）
- Markdown 構文ハイライト（見出し・太字・コード・リンク・引用・リスト）
- 自動保存（2 秒デバウンス）、ファイル切替時即時保存
- Undo/Redo（NSTextView ネイティブ）
- 未保存インジケーター — ウィンドウタイトルに「● filename.md」
- 外部変更コンフリクト処理 — 編集中の外部変更をダイアログで通知（リロード / 維持）
- 大ファイル段階処理 — 1MB 超: 警告、10MB 超: エディタ拒否、50MB 超: プレビュー拒否
- 新規ファイル作成、画像 D&D 挿入、リスト自動継続

## フォルダ管理

- 複数ルートフォルダの同時管理（折りたたみ可能）
- フォルダ追加 — メニュー（Cmd+Shift+O）、D&D、ウェルカム画面
- フォルダ削除 — 右クリックメニュー（確認ダイアログ付き）
- FSEvents によるファイル変更自動検知（0.5 秒デバウンス）
- 除外パターン設定（`.git`, `node_modules` 等）
- フォルダクリック時 README 自動表示
- Front Matter タグフィルタ

## エクスポート

- **HTML** — CSS/JS インラインのスタンドアローン HTML（Cmd+Shift+E）
- **PDF** — WKWebView ベース、ページ分割対応（YouTube は QR コード + サムネイル化）

## 連携

- **URL スキーム** — `nomad://open?path=/path/to/file.md`
- **Quick Look Extension** — Finder でスペースキープレビュー
- **Share Extension** — 右クリック共有から HTML/PDF 変換
- **外観モード** — システム / ライト / ダーク切替

## キーボードショートカット

| キー | 機能 |
|---|---|
| Cmd+P | クイックオープン |
| Cmd+E | ビューア / 編集切替 |
| Cmd+\ | 分割表示 |
| Cmd+W | タブを閉じる |
| Cmd+Shift+O | フォルダを追加 |
| Cmd+Shift+F | 全文検索 |
| Cmd+Shift+I | 索引 |
| Cmd+Shift+R | 最近使った項目 |
| Cmd+Shift+T | 目次の表示 / 非表示 |
| Cmd+Shift+E | HTML エクスポート |
| Cmd+, | 設定 |

## 技術スタック

| | |
|---|---|
| UI | SwiftUI + WKWebView |
| Markdown | [swift-markdown](https://github.com/swiftlang/swift-markdown)（AST→HTML） |
| ファイル監視 | CoreServices FSEvents API |
| 数式 | KaTeX（CDN） |
| ダイアグラム | Mermaid.js（CDN） |
| 対象 OS | macOS 26.2+（Liquid Glass 対応） |
| アーキテクチャ | MVVM（@Observable） |
| 設計思想 | No Database — 独自管理ファイルなし |
