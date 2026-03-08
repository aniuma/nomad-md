import Foundation

enum PDFPageSize: String, CaseIterable {
    case a4 = "a4"
    case letter = "letter"
    case b5 = "b5"
    case legal = "legal"

    var displayName: String {
        switch self {
        case .a4: "A4"
        case .letter: "Letter"
        case .b5: "B5"
        case .legal: "Legal"
        }
    }

    var width: CGFloat {
        switch self {
        case .a4: 595.28
        case .letter: 612
        case .b5: 498.90
        case .legal: 612
        }
    }

    var height: CGFloat {
        switch self {
        case .a4: 841.89
        case .letter: 792
        case .b5: 708.66
        case .legal: 1008
        }
    }
}

enum PDFMarginPreset: String, CaseIterable {
    case narrow = "narrow"
    case normal = "normal"
    case wide = "wide"

    var displayName: String {
        switch self {
        case .narrow: "狭い"
        case .normal: "標準"
        case .wide: "広い"
        }
    }

    var points: CGFloat {
        switch self {
        case .narrow: 36
        case .normal: 54
        case .wide: 72
        }
    }
}

struct PDFExportSettings {
    var pageSize: PDFPageSize = .a4
    var marginPreset: PDFMarginPreset = .normal
    var showHeader: Bool = true
    var showFooter: Bool = true

    static func load() -> PDFExportSettings {
        let defaults = UserDefaults.standard
        var settings = PDFExportSettings()
        if let raw = defaults.string(forKey: "pdfPageSize"),
           let size = PDFPageSize(rawValue: raw) {
            settings.pageSize = size
        }
        if let raw = defaults.string(forKey: "pdfMarginPreset"),
           let preset = PDFMarginPreset(rawValue: raw) {
            settings.marginPreset = preset
        }
        if defaults.object(forKey: "pdfShowHeader") != nil {
            settings.showHeader = defaults.bool(forKey: "pdfShowHeader")
        }
        if defaults.object(forKey: "pdfShowFooter") != nil {
            settings.showFooter = defaults.bool(forKey: "pdfShowFooter")
        }
        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(pageSize.rawValue, forKey: "pdfPageSize")
        defaults.set(marginPreset.rawValue, forKey: "pdfMarginPreset")
        defaults.set(showHeader, forKey: "pdfShowHeader")
        defaults.set(showFooter, forKey: "pdfShowFooter")
    }
}
