# Nomad — ブランディングガイド

## アプリ名

**Nomad**（先頭大文字）

### 由来
- 遊牧民 = ロックインなし、どのツールとも自由に共存
- 哲学的な深み（ドゥルーズの「ノマド」概念 = 知的放浪）
- "No-m-a-d" に md が自然に内包
- ローカルファーストでツール横断（Claude Code, OpenClaw, Drive等）というコンセプトを体現

## コンセプト

**「静かな旅路で、知を照らす」**

### デザイン原則
1. **自由** — ツールは邪魔しない。ファイルが主役。余白を大切に
2. **温かい知性** — 旅先の書斎のような安心感
3. **静謐な動き** — 派手なアニメーションより静かな遷移

## カラーパレット

| 名前 | Hex | 用途 |
|---|---|---|
| Deep Night Blue | `#1E3A5F` | Primary。砂漠の夜空 |
| Clear Blue | `#2B6CB0` | Secondary。澄んだ空 |
| Sand Gold | `#D4A574` | Accent。砂漠の砂、温かみ |
| Parchment | `#F0E6D3` | Light。羊皮紙、柔らかい白 |
| Midnight | `#0F1B2D` | Dark。深夜の闇 |
| Off-black | `#1A1A2E` | Text。読みやすい黒 |

## アイコン

- **モチーフ: 砂丘の曲線** — Typora的ミニマルさ
- macOS Tahoe スーパーエリプスの中に砂丘の稜線2本
- 背景: Deep Night Blue → Midnight グラデーション
- 曲線: Sand Gold → 白へフェード
- 星のドット（夜空の静けさを表現）
- ソース: `md-tool/md-tool/Assets.xcassets/AppIcon.appiconset/icon.svg`

## タイポグラフィ

- サンセリフ系（Inter, SF Pro）
- 文字間やや広め
- ウェイト: Regular〜Medium

## 識別子

| 項目 | 値 |
|---|---|
| 表示名 | Nomad |
| バンドルID | `com.susumu.nomad` |
| URLスキーム | `nomad://open?path=...` |
| Quick Look Extension | `com.susumu.nomad.quicklook` |
| Share Extension | `com.susumu.nomad.share` |
| App Group | `group.com.susumu.nomad` |
| モジュール名 | `Nomad` |
| App構造体 | `NomadApp` |

## リネーム履歴（2026-03-08）

### 変更したもの
- バンドルID: `com.susumu.md-tool` → `com.susumu.nomad`（全ターゲット）
- URLスキーム: `mdtool://` → `nomad://`
- App構造体: `md_toolApp` → `NomadApp`
- PRODUCT_NAME: `$(TARGET_NAME)` → `Nomad`（.app名・Dock表示に反映）
- テストimport: `@testable import md_tool` → `@testable import Nomad`
- TEST_HOST: `md-tool.app/.../md-tool` → `Nomad.app/.../Nomad`
- Extension entitlements: `group.com.susumu.md-tool` → `group.com.susumu.nomad`
- Share Extension表示: `md-tool: Markdownを変換` → `Nomad: Markdownを変換`
- AppIcon: 砂丘曲線アイコン新規作成（SVG + 全サイズPNG）
- README.md: タイトル・説明をNomadに更新

### 変更しなかったもの（意図的）
- **Xcodeプロジェクト名** (`md-tool.xcodeproj`) — Gitリポジトリ構造との兼ね合いでXcode GUIリネームが失敗するため。開発者しか見ない内部名
- **ディレクトリ名** (`md-tool/`) — pbxprojのパス参照が多く、手動変更はリスクが高い
- **スキーム名** (`md-tool`) — ビルドコマンドとCI互換性のため
- **ターゲット名** (`md-tool`, `md-toolTests` 等) — 同上

> これらは開発者向けの内部名であり、ユーザーに見える部分は全てNomadに統一済み。
