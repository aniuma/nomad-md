# md-tool

Finder直結型 Markdown プレビューア（macOSネイティブ）

SwiftUI + WKWebView の2ペイン構成（サイドバー + プレビュー）で、ローカルのMarkdownファイルを快適に閲覧できるツール。

## 実装済み機能

### フォルダ管理
- **複数ルートフォルダの同時管理** — サイドバーにSection分けで表示
- **フォルダ追加** — メニュー（Cmd+Shift+O）またはD&D
- **フォルダ削除** — 右クリックメニューから（確認ダイアログ付き）
- **FSEventsファイル変更自動検知** — ファイル追加/削除/リネームを自動反映
- **除外パターン設定** — `.git`, `node_modules`等をサイドバーから除外（Cmd+, で設定画面）

### プレビュー
- **Markdownプレビュー** — swift-markdownでAST→HTML変換、WKWebViewで表示
- **ファイル変更時の自動再レンダリング** — 外部エディタでの編集を即座に反映
- **日本語タイポグラフィ最適化** — Hiragino Kaku Gothic ProN、line-height 1.8、letter-spacing 0.03em
- **TOC（目次自動生成）** — 見出しから折りたたみ可能な目次を自動生成、アンカーリンクでスムーズスクロール
- **内部リンク遷移** — `.md`への相対リンクをクリックでアプリ内ファイル遷移

### 検索
- **クイックオープン（Cmd+P）** — ファイル名部分一致検索、矢印キーナビゲーション
- **全文検索（Cmd+Shift+F）** — 全ファイル横断テキスト検索、検索ハイライト、最大100件

### データ管理
- **ブックマーク永続化** — UserDefaultsでフォルダ/選択ファイルを保存・復元
- **前回の状態復元** — アプリ再起動時に登録フォルダと選択ファイルを復元

## キーボードショートカット

| ショートカット | 機能 |
|---|---|
| Cmd+Shift+O | フォルダを追加 |
| Cmd+P | クイックオープン |
| Cmd+Shift+F | 全文検索 |
| Cmd+, | 設定 |

## 技術スタック

- **UI**: SwiftUI + WKWebView
- **Markdown**: [swift-markdown](https://github.com/swiftlang/swift-markdown)（MarkupWalkerでAST→HTML）
- **ファイル監視**: CoreServices FSEvents API
- **対象OS**: macOS 26.2+
- **アーキテクチャ**: MVVM（@Observable）

## プロジェクト構成

```
md-tool/md-tool/
├── App/           AppState, md_toolApp
├── Models/        FileNode, BookmarkManager, ExclusionSettings
├── Services/      FileSystemService, MarkdownRenderer, FileWatcher
├── ViewModels/    SidebarViewModel, PreviewViewModel
├── Views/         SidebarView, PreviewView, WelcomeView,
│                  QuickOpenView, SearchView, SettingsView
└── ContentView.swift
```

## ビルド

```bash
cd md-tool/md-tool
xcodebuild -scheme md-tool -destination 'platform=macOS' build
xcodebuild -scheme md-tool -destination 'platform=macOS' test -only-testing:md-toolTests
```
