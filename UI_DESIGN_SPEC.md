# Finder直結型・階層プレビュー・マークダウン管理ツール UI/UX設計書

---

## 1. レイアウト設計

### 1.1 全体構成 - 3カラムレイアウト

```
+------------------------------------------------------------------+
|  [Traffic Lights]   md-tool - ~/Documents/Notes        [Toolbar] |
+------------------------------------------------------------------+
|          |                  |                                     |
| Sidebar  |   File List      |   Preview / Editor                 |
| (Folder  |                  |                                     |
|  Tree)   |  +------------+ |  # Document Title                   |
|          |  | search...  | |                                     |
| v Notes  |  +------------+ |  Lorem ipsum dolor sit amet,        |
|   v Blog |                  |  consectetur adipiscing elit.       |
|     file1|  file1.md   3/7 |                                     |
|     file2|  file2.md   3/5 |  ## Section 1                       |
|   > Draft|  file3.md   3/1 |                                     |
| > Archive|                  |  - bullet point 1                   |
|          |  Sort: Name  v  |  - bullet point 2                   |
|          |                  |                                     |
| [+ Add]  |                  |  ```swift                           |
|          |                  |  let x = 42                         |
|          |                  |  ```                                 |
+----------+------------------+-------------------------------------+
```

### 1.2 カラム幅仕様

| カラム | 初期幅 | 最小幅 | 最大幅 | 比率目安 |
|--------|--------|--------|--------|----------|
| Sidebar (フォルダツリー) | 200pt | 140pt | 320pt | ~16% |
| File List (ファイルリスト) | 240pt | 180pt | 400pt | ~20% |
| Preview / Editor | 残り全て | 400pt | 制限なし | ~64% |

### 1.3 カラムの折りたたみ・リサイズ

- **リサイズ**: `NSSplitView` のディバイダーをドラッグで自由にリサイズ
- **Sidebar折りたたみ**:
  - `Cmd + 0` または View > Hide Sidebar でトグル
  - 折りたたみ時はアニメーション付きで幅0へ（0.25秒、ease-in-out）
  - ディバイダーをダブルクリックでも折りたたみ/展開
- **File List折りたたみ**:
  - `Cmd + Shift + 0` でトグル
  - 折りたたみ時、Previewが全幅を使用（2カラム→1カラム）

### 1.4 ウィンドウサイズ変更時の挙動

| ウィンドウ幅 | レイアウト |
|-------------|-----------|
| 1200pt以上 | 3カラム通常表示 |
| 900〜1199pt | Sidebarを自動的に200ptに縮小、Previewが吸収 |
| 700〜899pt | Sidebarを自動折りたたみ、2カラム表示 |
| 700pt未満 | 最小幅として制約（これ以下にリサイズ不可） |

- **推奨ウィンドウ初期サイズ**: 1200 x 800pt
- **最小ウィンドウサイズ**: 700 x 500pt
- フルスクリーン対応（macOS標準）

---

## 2. ユーザーフロー

### 2.1 初回起動フロー

```
[アプリ起動]
    |
    v
[ウェルカム画面]
    "フォルダを追加してマークダウンを管理しましょう"
    [フォルダを選択...] ボタン (中央配置、目立つAccentColor)
    [最近のフォルダを開く] (小さめのセカンダリリンク)
    |
    v
[NSOpenPanel表示] ※フォルダ選択のみ許可
    |
    v
[サイドバーにフォルダツリー表示]
    |
    v
[ツリー自動展開 → 最初の.mdファイルを自動選択]
    |
    v
[プレビュー表示完了]
```

- ウェルカム画面はフォルダ未登録時のみ表示
- 次回起動以降は前回の状態（開いていたフォルダ・選択ファイル・カラム幅）を復元

### 2.2 フォルダの追加・削除フロー

**追加:**
1. サイドバー下部の `[+]` ボタン、または `File > Add Folder...` (`Cmd + Shift + O`)
2. `NSOpenPanel` でフォルダ選択
3. サイドバー末尾に追加、自動展開
4. セキュリティスコープブックマーク保存（サンドボックス対応）

**削除:**
1. サイドバーのルートフォルダを右クリック → "Remove from Sidebar"
2. 確認ダイアログ: "サイドバーから削除しますか？（ファイルは削除されません）"
3. OK → サイドバーから除去

**補足:**
- 複数のルートフォルダを登録可能（Finderのサイドバーと同様のメンタルモデル）
- Finderからフォルダをサイドバーにドラッグ&ドロップでも追加可能

### 2.3 ファイル閲覧・編集・保存フロー

```
[サイドバーでフォルダ選択]
    |
    v
[ファイルリストに.mdファイル一覧表示]
    |
    v
[ファイルをクリック]
    |
    v
[プレビューモードで表示] ← デフォルト
    |
    +-- ダブルクリック or Cmd+E or 鉛筆アイコン
    |
    v
[編集モードに切替]
    |  テキスト編集（シンタックスハイライト付き）
    |  自動保存 (1秒デバウンス) + Cmd+S で即時保存
    |
    +-- Esc or Cmd+E or 目アイコン
    |
    v
[プレビューモードに戻る]
```

### 2.4 プレビュー / 編集モードの切り替え

| 操作 | 動作 |
|------|------|
| ファイルシングルクリック | プレビュー表示 |
| ファイルダブルクリック | 編集モードで開く |
| `Cmd + E` | プレビュー ↔ 編集 トグル |
| Previewエリア右上のトグルボタン | プレビュー ↔ 編集 トグル |
| `Esc` (編集中) | プレビューに戻る |

**トグルボタンUI:**
```
+-------------------+
| [目] [鉛筆] [分割] |  ← セグメンテッドコントロール
+-------------------+
  Preview  Edit  Split
```

- 「分割」モード: 左に編集、右にリアルタイムプレビュー（Previewカラム内を縦分割）

---

## 3. コンポーネント詳細

### 3.1 サイドバー（フォルダツリー）

**実装コンポーネント:** `NSOutlineView` (Source List style)

```
+-- Sidebar ---------+
| [search folders...] |  ← フォルダ検索（任意）
|---------------------|
| v  Notes            |  ← ルートフォルダ（太字、フォルダアイコン）
|    v  Blog          |  ← サブフォルダ（通常、フォルダアイコン）
|       article1.md   |  ← .mdファイル（ドキュメントアイコン）
|       article2.md   |
|    >  Drafts        |  ← 折りたたみ状態
| v  Projects         |  ← 別ルートフォルダ
|    README.md        |
|---------------------|
| [+ Add Folder]      |  ← 追加ボタン
+---------------------+
```

**仕様詳細:**

| 項目 | 仕様 |
|------|------|
| フォント | SF Pro Text, 13pt（ルートは14pt semibold） |
| 行高 | 24pt |
| インデント | 16pt/階層 |
| アイコンサイズ | 16x16pt |
| フォルダアイコン | `NSImage.Name.folder`（SF Symbols: `folder.fill`） |
| ファイルアイコン | `doc.text`（SF Symbols） |
| 選択行 | macOS標準のアクセントカラーハイライト |
| 展開/折りたたみ | 三角形ディスクロージャー（macOS標準） |
| ツリー監視 | `FSEvents` でファイルシステム変更をリアルタイム反映 |

**コンテキストメニュー（右クリック）:**

| 対象 | メニュー項目 |
|------|-------------|
| ルートフォルダ | Finderで表示 / ターミナルで開く / サイドバーから削除 |
| サブフォルダ | Finderで表示 / 新規マークダウン / 新規フォルダ / 名前を変更 / ゴミ箱に入れる |
| ファイル | Finderで表示 / 編集モードで開く / 名前を変更 / 複製 / ゴミ箱に入れる |

### 3.2 ファイルリスト（中央カラム）

**実装コンポーネント:** `NSTableView`（単一カラム、カスタムセル）

```
+-- File List --------+
| [  Search files...  ]|  ← 検索フィルター
|----------------------|
| Sort: Name  v        |  ← ソートドロップダウン
|----------------------|
| doc.text  article1   |
| Mar 7, 2026  1.2KB   |  ← ファイルセル（2行構成）
|----------------------|
| doc.text  article2   |
| Mar 5, 2026  800B    |
|----------------------|
| doc.text  draft-new  |
| Mar 1, 2026  2.4KB   |  ← 選択状態はハイライト
|----------------------|
|                      |
| 3 files              |  ← フッターにファイル数表示
+----------------------+
```

**ファイルセルの構成:**
```
+------------------------------------------+
| [icon] filename.md                [star] |  ← 1行目: アイコン + ファイル名 + お気に入り
| Updated: Mar 7, 2026       1.2KB        |  ← 2行目: 更新日 + サイズ
+------------------------------------------+
```

**ソート機能:**

| ソートキー | 説明 | ショートカット |
|-----------|------|---------------|
| 名前 (A→Z) | アルファベット昇順 | - |
| 名前 (Z→A) | アルファベット降順 | - |
| 更新日 (新しい順) | 最終更新日降順（デフォルト） | - |
| 作成日 (新しい順) | 作成日降順 | - |
| サイズ | ファイルサイズ降順 | - |

**検索フィルター:**
- インクリメンタルサーチ（入力と同時にフィルタ）
- ファイル名マッチ（デフォルト）
- `Cmd + F` でフォーカス
- `Esc` でクリア & フォーカス解除
- 対象フォルダ内の全階層を再帰検索（オプション切替可能）

### 3.3 メインプレビュー / エディタ（右カラム）

**プレビューモード:**

- **実装:** `WKWebView` によるMarkdownレンダリング
- **デフォルトスタイル:** GitHub Flavored Markdown (GFM) 準拠
- **選択可能テーマ:**

| テーマ名 | 説明 |
|---------|------|
| GitHub | GFM準拠。コードブロック背景グレー、テーブル罫線付き |
| Minimal | 余白広め、serif系フォント、読書向き |
| Technical | monospace寄り、コード重視、行間狭め |

- **対応Markdown要素:** 見出し、リスト、テーブル、コードブロック（シンタックスハイライト）、画像、リンク、チェックリスト、数式（KaTeX）、Mermaid図

**プレビュー内ツールバー:**
```
+----------------------------------------------------------+
| [Preview | Edit | Split]    [Theme v]  [TOC]  [Export v] |
+----------------------------------------------------------+
```

| ボタン | 機能 |
|--------|------|
| Preview / Edit / Split | 表示モード切替（セグメンテッドコントロール） |
| Theme | レンダリングテーマ選択 |
| TOC | 目次サイドパネル表示/非表示 |
| Export | PDF / HTML / .md(コピー) エクスポート |

**編集モード:**

- **実装:** `NSTextView`（カスタム、シンタックスハイライト付き）
- **フォント:** SF Mono, 14pt（設定で変更可能）
- **行番号:** 左ガター表示（トグル可能）
- **シンタックスハイライト:** 見出し=太字青、リンク=アクセントカラー、コード=グレー背景、太字/斜体=対応スタイル
- **自動保存:** 編集停止後1秒で自動保存、タイトルバーに保存状態表示（"Edited" → "Saved"）

**分割モード:**
```
+-------------------------------+
| [Preview | Edit | Split]      |
+---------------+---------------+
|               |               |
|   Editor      |   Preview     |
|   (左)        |   (右)        |
|               |               |
| # Title       | Title         |
| - item        | * item        |
|               |               |
+---------------+---------------+
```
- スクロール同期（編集側のカーソル位置にプレビューを追従）

---

## 4. インタラクション設計

### 4.1 キーボードショートカット一覧

**ファイル操作:**

| ショートカット | 動作 |
|---------------|------|
| `Cmd + N` | 新規マークダウンファイル作成 |
| `Cmd + O` | ファイルを開く |
| `Cmd + Shift + O` | フォルダを追加 |
| `Cmd + S` | 保存（編集モード時） |
| `Cmd + W` | 現在のタブを閉じる |
| `Cmd + Shift + N` | 新規ウィンドウ |

**表示:**

| ショートカット | 動作 |
|---------------|------|
| `Cmd + 0` | サイドバーの表示/非表示 |
| `Cmd + Shift + 0` | ファイルリストの表示/非表示 |
| `Cmd + E` | プレビュー ↔ 編集 トグル |
| `Cmd + Shift + E` | 分割ビュー切替 |
| `Cmd + +` / `Cmd + -` | プレビューの拡大/縮小 |
| `Cmd + 0`（プレビュー） | 拡大率リセット（コンフリクト回避: Cmd+Shift+0にバインド検討） |

**ナビゲーション:**

| ショートカット | 動作 |
|---------------|------|
| `Up / Down` | ファイルリスト内の移動 |
| `Cmd + F` | ファイルリスト内検索 |
| `Cmd + Shift + F` | 全文検索（全フォルダ横断） |
| `Cmd + P` | クイックオープン（ファジーファイル名検索） |
| `Tab` | フォーカス移動（Sidebar → FileList → Preview） |
| `Cmd + [` / `Cmd + ]` | 閲覧履歴の戻る/進む |

**編集（編集モード時）:**

| ショートカット | 動作 |
|---------------|------|
| `Cmd + B` | 太字トグル |
| `Cmd + I` | 斜体トグル |
| `Cmd + K` | リンク挿入 |
| `Cmd + Shift + K` | 画像挿入 |
| `Cmd + Shift + C` | コードブロック挿入 |

### 4.2 ドラッグ&ドロップ

| 操作 | 動作 |
|------|------|
| Finderからフォルダをサイドバーへ | ルートフォルダとして追加 |
| Finderからファイルをファイルリストへ | 選択中フォルダにコピー/移動 |
| Finderから画像をエディタへ | 画像をフォルダにコピーし `![](path)` 挿入 |
| ファイルリスト内のファイルをサイドバーのフォルダへ | ファイル移動 |
| サイドバー内のフォルダ並び替え | ルートフォルダの表示順変更 |

### 4.3 タブ・スプリットビュー

**タブ対応:**
- macOS標準のタブ機能を活用（`NSWindow.allowsAutomaticWindowTabbing`）
- `Cmd + T` で新規タブ（異なるフォルダ/ファイルを並行閲覧）
- タブ間でのファイルのドラッグ&ドロップ移動

**スプリットビュー:**
- macOS標準のSplit View対応（フルスクリーン時に他アプリと並列表示）
- アプリ内の分割はPreviewカラム内のSplitモードで対応

### 4.4 ダークモード

- `NSAppearance` に追従し自動切替
- プレビューのCSSもダークモード対応（`prefers-color-scheme: dark`）
- 各テーマにライト/ダーク両バリアントを用意

**カラーパレット:**

| 要素 | ライト | ダーク |
|------|--------|--------|
| 背景（Sidebar） | `#F5F5F5` | `#1E1E1E` |
| 背景（FileList） | `#FFFFFF` | `#252525` |
| 背景（Preview） | `#FFFFFF` | `#2D2D2D` |
| テキスト | `#1D1D1F` | `#E5E5E5` |
| セカンダリテキスト | `#8E8E93` | `#98989F` |
| アクセント | システム設定に追従 | システム設定に追従 |
| ディバイダー | `#D1D1D6` | `#3A3A3C` |

※ 基本的に `NSColor` のセマンティックカラー（`.textColor`, `.separatorColor`, `.controlBackgroundColor` 等）を使用し、システム設定への追従を自動化する。

---

## 5. Macネイティブ感の実現

### 5.1 Apple Human Interface Guidelines 準拠ポイント

| ガイドライン項目 | 対応方針 |
|-----------------|---------|
| Sidebar | Source List スタイル (`NSOutlineView` + `.sourceList`) |
| 3カラムレイアウト | `NSSplitViewController` で管理 |
| ツールバー | `NSToolbar` 統合型（タイトルバーと一体化） |
| コンテキストメニュー | `NSMenu` による標準右クリックメニュー |
| ダークモード | セマンティックカラー + CSS `prefers-color-scheme` |
| フルスクリーン | 標準対応 |
| タブ | `NSWindow` タブ機能活用 |
| ドキュメントアイコン | タイトルバーにプロキシアイコン表示 |
| Handoff | 将来対応可能な設計 |
| Quick Look | `.md` ファイルの Quick Look プラグイン提供（将来） |

### 5.2 主要macOSコンポーネントマッピング

```
+------------------------------------------------------------------+
|  NSToolbar (unified title/toolbar style)                         |
|  [Traffic Lights]  proxy icon + title    [Toolbar Items]         |
+------------------------------------------------------------------+
|                    NSSplitViewController                         |
|                                                                  |
|  NSSplitViewItem  | NSSplitViewItem  | NSSplitViewItem           |
|  (.sidebar)       | (.contentList)   | (.none / detail)          |
|                   |                  |                            |
|  NSOutlineView    | NSTableView      | WKWebView (preview)       |
|  (Source List)    | (custom cells)   | NSTextView (editor)       |
|                   |                  |                            |
+------------------------------------------------------------------+
|  NSStatusBar (optional: word count, encoding)                    |
+------------------------------------------------------------------+
```

| UIパーツ | macOSコンポーネント |
|---------|-------------------|
| ウィンドウ | `NSWindow` (titled, closable, resizable, miniaturizable) |
| 3カラム分割 | `NSSplitViewController` + `NSSplitViewItem` |
| フォルダツリー | `NSOutlineView` (.sourceList style) |
| ファイルリスト | `NSTableView` (view-based, single column) |
| プレビュー | `WKWebView` |
| エディタ | `NSTextView` (カスタムシンタックスハイライト) |
| ツールバー | `NSToolbar` |
| 検索バー | `NSSearchField` |
| モード切替 | `NSSegmentedControl` |
| ソート選択 | `NSPopUpButton` |
| ファイル選択ダイアログ | `NSOpenPanel` |
| コンテキストメニュー | `NSMenu` |
| ステータスバー | カスタム `NSView`（下端固定） |

### 5.3 メニューバー構成

```
[md-tool] [File] [Edit] [View] [Navigate] [Format] [Window] [Help]
```

**md-tool メニュー:**
- About md-tool
- Preferences... (`Cmd + ,`)
- ---
- Hide md-tool / Hide Others / Show All
- ---
- Quit md-tool (`Cmd + Q`)

**File メニュー:**
- New Markdown File (`Cmd + N`)
- Open... (`Cmd + O`)
- Add Folder to Sidebar... (`Cmd + Shift + O`)
- ---
- Save (`Cmd + S`)
- ---
- Export as PDF (`Cmd + Shift + P`)
- Export as HTML
- ---
- Close Tab (`Cmd + W`)
- Close Window (`Cmd + Shift + W`)

**Edit メニュー:**
- Undo / Redo
- ---
- Cut / Copy / Paste / Select All
- ---
- Find (`Cmd + F`)
- Find in All Files (`Cmd + Shift + F`)
- ---
- Spelling and Grammar (標準サブメニュー)

**View メニュー:**
- Show/Hide Sidebar (`Cmd + 0`)
- Show/Hide File List (`Cmd + Shift + 0`)
- ---
- Preview Mode (`Cmd + E` toggle)
- Split Mode (`Cmd + Shift + E`)
- ---
- Show/Hide Table of Contents
- Show/Hide Line Numbers
- ---
- Zoom In / Zoom Out / Actual Size
- ---
- Enter Full Screen

**Navigate メニュー:**
- Quick Open (`Cmd + P`)
- Back (`Cmd + [`)
- Forward (`Cmd + ]`)

**Format メニュー:**
- Bold (`Cmd + B`)
- Italic (`Cmd + I`)
- ---
- Heading 1〜6
- ---
- Insert Link (`Cmd + K`)
- Insert Image (`Cmd + Shift + K`)
- Insert Code Block (`Cmd + Shift + C`)
- Insert Table

**Window メニュー:**
- Minimize / Zoom
- ---
- New Tab (`Cmd + T`)
- Show All Tabs
- ---
- Bring All to Front

**Help メニュー:**
- md-tool Help
- Markdown Syntax Reference

---

## 6. 設定画面 (Preferences)

`Cmd + ,` で開く設定ウィンドウ（macOS標準の `NSTabView` / SwiftUI `TabView` スタイル）。

### タブ構成

| タブ | 設定項目 |
|------|---------|
| General | デフォルト表示モード（Preview/Edit/Split）、起動時の動作（前回状態復元 or ウェルカム） |
| Editor | フォント・サイズ、タブ幅（2/4スペース）、行番号表示、自動保存間隔 |
| Preview | テーマ選択、CSSカスタム、数式レンダリングON/OFF |
| Shortcuts | キーボードショートカットのカスタマイズ |

---

## 7. ステータスバー（下端）

```
+------------------------------------------------------------------+
| UTF-8  |  Markdown  |  245 words  |  Ln 42, Col 15  |  Saved    |
+------------------------------------------------------------------+
```

- エンコーディング、ファイルタイプ、ワード数、カーソル位置（編集時）、保存状態を表示
- クリックで各種切替（エンコーディング変更など）

---

## 8. 技術スタック推奨

| レイヤー | 技術 |
|---------|------|
| UI Framework | AppKit（3カラム制御の柔軟性優先）+ 部分的にSwiftUI |
| 言語 | Swift |
| Markdownパース | swift-markdown (Apple公式) または cmark-gfm |
| プレビューレンダリング | WKWebView + カスタムCSS/JS |
| シンタックスハイライト | tree-sitter または NSTextStorageベースのカスタム |
| ファイル監視 | FSEvents (DispatchSource.makeFileSystemObjectSource) |
| データ永続化 | UserDefaults + セキュリティスコープブックマーク |
| 配布 | Mac App Store (サンドボックス対応) |
