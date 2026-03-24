import SwiftUI

enum NomadColors {
    // MARK: - Brand Colors

    /// Deep Night Blue — 主要背景、ヘッダー (#1E3A5F)
    static let deepNightBlue = Color(red: 0.118, green: 0.227, blue: 0.373)
    /// Sand Gold — アクセント、インタラクティブ要素 (#D4A574)
    static let sandGold = Color(red: 0.831, green: 0.647, blue: 0.455)
    /// Parchment — 明るい背景、カード (#F0E6D3)
    static let parchment = Color(red: 0.941, green: 0.902, blue: 0.827)
    /// Midnight — 最も深い背景、テキスト (#0F1B2D)
    static let midnight = Color(red: 0.059, green: 0.106, blue: 0.176)

    // MARK: - Semantic Colors

    /// 成功状態の表示に使用
    static let success = Color(red: 0.2, green: 0.7, blue: 0.35)
    /// 警告状態の表示に使用
    static let warning = Color(red: 0.95, green: 0.7, blue: 0.1)
    /// エラー状態の表示に使用
    static let error = Color(red: 0.9, green: 0.25, blue: 0.2)
}
