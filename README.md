# Nomad

静かな旅路で、知を照らす — Finder直結型 Markdown プレビューア（macOSネイティブ）

SwiftUI + WKWebView の2ペイン構成で、ローカルのMarkdownファイルを快適に閲覧・編集できるツール。独自データベースを持たず、Finderのフォルダ構造をそのまま活用する「No Database」設計。ロックインなし、どのツールとも自由に共存。

## 機能一覧

### フォルダ管理
- **複数ルートフォルダの同時管理** — サイドバーにSection分けで表示
- **フォルダ追加** — メニュー（Cmd+Shift+O）、D&D、またはウェルカム画面から
- **フォルダ削除** — 右クリックメニュー（確認ダイアログ付き）
- **FSEventsファイル変更自動検知** — ファイル追加/削除/リネームを自動反映（0.5秒デバウンス）
- **除外パターン設定** — `.git`, `node_modules`等をサイドバーから除外（Cmd+, で管理）
- **フォルダクリック時README自動表示** — フォルダ選択でREADME.mdを自動プレビュー
- **Front Matterタグ** — YAML Front Matterからタグ抽出、サイドバーでタグフィルタ

### プレビュー
- **Markdownプレビュー** — swift-markdownでAST→HTML変換、WKWebViewで表示
- **ファイル変更時の自動再レンダリング** — 外部エディタでの編集を即座に反映
- **日本語タイポグラフィ最適化** — Hiragino Kaku Gothic ProN、line-height 1.8、letter-spacing 0.03em
- **プレビューテーマ4種** — Default（和文最適化）/ GitHub / Minimal（セリフ体）/ Technical（モノスペース）
- **カスタムCSSテーマ** — 任意のCSSファイルを追加適用可能
- **TOC（目次サイドバー）** — 右サイドバーに階層ネスト目次を常時表示、スクロール追従ハイライト（Cmd+Shift+T）
- **内部リンク遷移** — `.md`への相対リンクをクリックでアプリ内ファイル遷移
- **YAML Front Matter** — メタデータを折りたたみ可能なテーブルで表示
- **Callout/Admonition** — `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!IMPORTANT]`, `[!CAUTION]`（GitHub風、折りたたみ対応）
- **Mermaidダイアグラム** — \`\`\`mermaid コードブロックを図として描画
- **KaTeX数式レンダリング** — `$...$`（インライン）と `$$...$$`（ブロック）
- **脚注** — `[^id]` 参照と `[^id]:` 定義、文末に脚注セクション自動生成
- **見出しレベル警告** — h1→h3等のスキップを検出し折りたたみ警告表示
- **セクション単位コピー** — 見出しホバーでコピーボタン表示
- **リンク切れ検出** — 存在しない相対リンクを赤+打ち消し線で表示
- **レンダリングキャッシュ** — SHA256ベース、最大50件
- **oEmbed** — YouTube/Twitter/Gist URL自動埋め込み

### 編集
- **プレビュー/編集/分割モード** — Cmd+Eで切替、Cmd+\で分割表示
- **Markdown構文ハイライト** — 見出し/太字/コード/リンク/引用/リスト
- **自動保存** — 2秒デバウンス、ファイル切替時即時保存
- **Undo/Redo** — NSTextViewネイティブ
- **未保存インジケーター** — ウィンドウタイトルに「● filename.md」
- **外部変更コンフリクト処理** — 編集中の外部変更をダイアログで通知（リロード/維持）
- **大ファイル段階処理** — 1MB超:警告、10MB超:エディタ拒否、50MB超:プレビュー拒否

### 検索・ナビゲーション
- **クイックオープン（Cmd+P）** — ファイル名部分一致検索、矢印キーナビゲーション
- **クイックスイッチャー見出し検索** — `#`プレフィックスで全ファイルの見出しを横断検索
- **全文検索（Cmd+Shift+F）** — 正規表現対応、大文字小文字区別、検索&置換
- **索引/インデックス（Cmd+Shift+I）** — 全ファイルの見出し一覧、検索フィルタ付き

### タブ・履歴
- **タブ機能** — 複数ファイルをタブで開いて切替（Cmd+Wで閉じる）
- **最近使った項目（Cmd+Shift+R）** — 最大20件の履歴、メニューからもアクセス可能

### エクスポート
- **HTMLエクスポート** — CSS/JSインラインのスタンドアローンHTML
- **PDFエクスポート** — WKWebView.createPDF()でPDF生成

### 連携
- **URLスキーム** — `nomad://open?path=/path/to/file.md` でファイル/フォルダを開く
- **Quick Look Extension** — FinderでスペースキーによるMarkdownプレビュー
- **Share Extension** — 右クリック共有からHTML/PDF変換

## キーボードショートカット

| ショートカット | 機能 |
|---|---|
| Cmd+Shift+O | フォルダを追加 |
| Cmd+P | クイックオープン |
| Cmd+Shift+F | 全文検索 |
| Cmd+Shift+I | 索引/インデックス |
| Cmd+Shift+R | 最近使った項目 |
| Cmd+Shift+T | 目次の表示/非表示 |
| Cmd+E | プレビュー/編集モード切替 |
| Cmd+\ | 分割表示切替 |
| Cmd+W | タブを閉じる |
| Cmd+Shift+E | HTMLとして保存 |
| Cmd+, | 設定 |

## 技術スタック

- **UI**: SwiftUI + WKWebView
- **Markdown**: [swift-markdown](https://github.com/swiftlang/swift-markdown)（MarkupWalkerでAST→HTML）
- **ファイル監視**: CoreServices FSEvents API
- **数式**: KaTeX（CDN）
- **ダイアグラム**: Mermaid.js（CDN）
- **対象OS**: macOS 26.2+
- **アーキテクチャ**: MVVM（@Observable）

## プロジェクト構成

```
md-tool/md-tool/
├── App/           AppState, NomadApp
├── Models/        FileNode, BookmarkManager, ExclusionSettings
├── Services/      FileSystemService, MarkdownRenderer, FileWatcher,
│                  TagService, ExportService, OEmbedService, HTMLTemplateProvider
├── ViewModels/    SidebarViewModel, PreviewViewModel, EditorViewModel
├── Views/         ContentView, SidebarView, PreviewView, EditorView,
│                  WelcomeView, QuickOpenView, SearchView, SettingsView,
│                  IndexView, TabBarView, RecentFilesView
└── Resources/
```

## ビルド

```bash
cd md-tool/md-tool
xcodebuild -scheme md-tool -destination 'platform=macOS' build
xcodebuild -scheme md-tool -destination 'platform=macOS' test -only-testing:md-toolTests
```

## ライセンス

MIT
