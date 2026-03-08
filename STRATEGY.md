# Nomad 戦略メモ

> 2026-03-09 調査結果に基づく

---

## 市場ポジション

### プレビューア市場は空いている
- Markdownエディタは飽和（Obsidian, Typora, iA Writer, VS Code等）
- **プレビューア/ビューア**に特化したツールは極めて少ない
- Marked 2（最も近い競合）は開発停滞中 → **後継ポジションが空いている**
- 「プレビュー重視 + Finder直結 + No Database」の組み合わせは他にない

### AI時代のプレビューア需要
- AI（Claude Code, ChatGPT, Copilot等）がMarkdownを大量生成する時代
- **エディタよりもプレビューア**が重要になる
  - 「生成→確認→承認」ワークフローの「確認」フェーズに特化
  - AI生成物を人間が検証するツールとしてのポジション
- エディタはオプション機能、プレビューがメイン — この設計思想が時代に合致

### Nomadの差別化要素
- macOSネイティブ（SwiftUI）= 軽量・高速
- No Database = ロックインなし、Finder直結
- AI生成Markdown確認に必要な機能が既に揃っている:
  - FileWatcher（リアルタイム更新）
  - 見出しレベル警告（AI構造ミス検知）
  - セクションコピー（部分採用）
  - リンク切れ検出
  - チェックボックス双方向トグル
  - URLスキーム（`nomad://open?path=...`）

---

## アプリ名の方向性

- 現在: Nomad
- 検討中: 「for AI」「AI Markdown Previewer」等のサブタイトル追加
  - 例: "Nomad — Markdown Previewer for AI Agents"
  - 例: "Nomad — AI Markdown Previewer"
- HashiCorp Nomad / NoMAD（AD管理）との被りはカテゴリ違いで実害小
- サブタイトルでMarkdownプレビューアであることを明示すれば混同回避可能

---

## AI連携で既に動くもの（追加実装不要）

| ユースケース | 方法 |
|---|---|
| Claude Codeの出力をリアルタイムプレビュー | フォルダ開いておくだけ（FileWatcher自動検知） |
| Google Drive/Dropbox同期ファイル | 同期フォルダを開くだけ（FSEvents対応済み） |
| Alfred/Raycastから即オープン | `open "nomad://open?path=..."` |
| チェックボックスでタスク管理 | プレビュー上でクリック→ファイル自動書き戻し済み |

---

## 拡張の可能性

### 短期（v2.0内）
- セクション折りたたみ（長文AI出力の把握）
- 読了時間表示（AI生成文書のボリューム把握）
- 索引トピック分類（大量ファイルのナビゲーション）
- URLスキーム拡張（`&line=42`, `&mode=edit`）

### 中期（v2.x〜v3.0）
- ローカルLLM統合（要約、翻訳、セマンティック検索）
- AI生成ステータスタグ（Front Matter活用）
- セクション単位の承認/却下UI

---

## 公開戦略

### ライセンス
- 推奨: MIT（GitHub公開） + App Store有料（$9.99〜14.99買切り）

### 配布順序
1. GitHub v1.0リリース + README英語版
2. Homebrew Cask登録
3. TestFlight beta
4. Mac App Store公開
5. Product Hunt（安定後1回限り）

### 価格帯
- 買切り: $9.99〜14.99（Typora $14.99、Marked 2 $14.99と同水準）
- または月額 $2.99

### 準備事項
- 英語ローカライズ
- App Storeスクリーンショット・説明文
- CHANGELOG作成

### 成功パターン（個人開発macOSアプリ）
- 定期更新（開発が継続していることを示す）
- ユーザーフィードバックへの迅速な対応
- ネイティブ開発の価値を可視化
- MacStories等メディアへの露出
