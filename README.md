# Nomad — AI Markdown Viewer

> 静かな旅路で、知を照らす

AI時代の Markdown プレビューア。生成されたドキュメントを **確認し、承認する** ワークフローに特化した macOS ネイティブアプリ。

独自データベースを持たず、Finder のフォルダ構造をそのまま活用する「**No Database**」設計。ロックインなし、どのエディタ・ツールとも自由に共存。

<!-- スクリーンショットをここに追加 -->
<!-- ![Nomad Screenshot](docs/screenshot.png) -->

## インストール

### GitHub Releases（推奨）

[Releases](../../releases) から最新の `.dmg` をダウンロードし、`Nomad.app` を Applications フォルダにドラッグ。

### ソースからビルド

```bash
cd md-tool/md-tool
xcodebuild -scheme md-tool -destination 'platform=macOS' build
```

## 主な特徴

### Markdown プレビュー

- swift-markdown による AST→HTML 変換、WKWebView でレンダリング
- **テーマ 5 種**: Default（和文最適化）/ GitHub / Minimal / Technical / Notion
- カスタム CSS の追加適用にも対応
- 日本語タイポグラフィ最適化（Hiragino Kaku Gothic ProN、line-height 1.8）
- ファイル保存時に自動再レンダリング

### リッチコンテンツ

| 記法 | 対応 |
|---|---|
| KaTeX 数式 | `$...$` インライン / `$$...$$` ブロック |
| Mermaid ダイアグラム | ` ```mermaid ` コードブロック |
| Callout / Admonition | `[!NOTE]` `[!TIP]` `[!WARNING]` `[!IMPORTANT]` `[!CAUTION]` |
| タスクリスト | `- [x]` / `- [ ]` チェックボックス |
| 脚注 | `[^id]` 参照と定義 |
| YAML Front Matter | メタデータをテーブルで表示（タグ抽出対応） |
| oEmbed | YouTube / Twitter / Gist の URL 自動埋め込み |

### セクション折りたたみ・読了時間

- 見出し単位でセクションを折りたたみ / 展開
- 日本語 550 文字/分、英語 220 語/分ベースの読了時間を自動表示

### ナビゲーション

- **TOC（目次）** — 右サイドバーに階層表示、スクロール追従ハイライト
- **クイックオープン（Cmd+P）** — ファイル名部分一致、`#` プレフィックスで見出し横断検索
- **全文検索（Cmd+Shift+F）** — 正規表現対応、検索 & 置換
- **索引（Cmd+Shift+I）** — 全ファイルの見出し一覧、トピック分類
- **内部リンク遷移** — `.md` 相対リンクをクリックでアプリ内タブとして開く
- **リンク切れ検出** — 存在しない相対リンクを赤 + 打ち消し線で警告

### タブ & ウィンドウ

- 複数ファイルをタブで管理（重複防止・コンテキストメニュー対応）
- Finder から `.md` ファイルをダブルクリックで直接オープン
- 単一ウィンドウ設計 — 常にひとつのウィンドウで集約
- 最近使った項目（Cmd+Shift+R）、最大 20 件の履歴

### 編集

- プレビュー / 編集 / 分割モード（Cmd+E / Cmd+\\）
- Markdown 構文ハイライト（見出し・太字・コード・リンク・引用・リスト）
- 自動保存（2 秒デバウンス）、外部変更コンフリクト処理
- 新規ファイル作成、画像 D&D 挿入、リスト自動継続

### フォルダ管理

- 複数ルートフォルダの同時管理（折りたたみ可能）
- D&D / メニュー / ウェルカム画面からフォルダ追加
- FSEvents によるファイル変更自動検知
- 除外パターン設定（`.git`, `node_modules` 等）
- Front Matter タグフィルタ

### エクスポート

- **HTML** — CSS/JS インラインのスタンドアローン HTML
- **PDF** — WKWebView ベース、ページ分割対応（YouTube は QR コード + サムネイル化）

### 連携

- **URLスキーム** — `nomad://open?path=/path/to/file.md`
- **Quick Look Extension** — Finder でスペースキープレビュー
- **Share Extension** — 右クリック共有から HTML/PDF 変換
- **外観モード** — システム / ライト / ダーク 切替

## キーボードショートカット

| キー | 機能 |
|---|---|
| **Cmd+P** | クイックオープン |
| **Cmd+E** | プレビュー / 編集切替 |
| **Cmd+\\** | 分割表示 |
| **Cmd+W** | タブを閉じる |
| **Cmd+Shift+O** | フォルダを追加 |
| **Cmd+Shift+F** | 全文検索 |
| **Cmd+Shift+I** | 索引 |
| **Cmd+Shift+R** | 最近使った項目 |
| **Cmd+Shift+T** | 目次の表示 / 非表示 |
| **Cmd+Shift+E** | HTML エクスポート |
| **Cmd+,** | 設定 |

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

## ライセンス

MIT
