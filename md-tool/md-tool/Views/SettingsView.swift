import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var patterns: [String] = ExclusionSettings.patterns
    @State private var newPattern = ""
    @State private var selectedTheme: String = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
    @State private var customCSSPath: String = UserDefaults.standard.string(forKey: "customCSSPath") ?? ""
    @State private var pdfSettings = PDFExportSettings.load()
    @State private var appearanceMode: String = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"

    var body: some View {
        Form {
            Section {
                Picker("外観", selection: $appearanceMode) {
                    Text("システム").tag("system")
                    Text("ライト").tag("light")
                    Text("ダーク").tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: appearanceMode) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "appearanceMode")
                    NotificationCenter.default.post(name: .appearanceChanged, object: nil)
                }
            } header: {
                Text("外観モード")
            }

            Section {
                Picker("テーマ", selection: $selectedTheme) {
                    Text("Default").tag("default")
                    Text("GitHub").tag("github")
                    Text("Notion").tag("notion")
                    Text("Minimal").tag("minimal")
                    Text("Technical").tag("technical")
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTheme) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "previewTheme")
                    NotificationCenter.default.post(name: .themeChanged, object: nil)
                }
            } header: {
                Text("プレビューテーマ")
            }

            Section {
                HStack {
                    TextField("CSSファイルパス", text: $customCSSPath)
                        .textFieldStyle(.roundedBorder)
                    Button("選択...") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.init(filenameExtension: "css")!]
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            customCSSPath = url.path
                        }
                    }
                }
                .onChange(of: customCSSPath) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "customCSSPath")
                    NotificationCenter.default.post(name: .themeChanged, object: nil)
                }

                if !customCSSPath.isEmpty {
                    Button("カスタムCSSをクリア") {
                        customCSSPath = ""
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("カスタムCSS")
            } footer: {
                Text("CSSファイルを指定すると、選択テーマの後に追加で適用されます。")
                    .foregroundStyle(.secondary)
            }

            Section {
                List {
                    ForEach(patterns, id: \.self) { pattern in
                        HStack {
                            Image(systemName: "folder.badge.minus")
                                .foregroundStyle(.secondary)
                            Text(pattern)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                patterns.removeAll { $0 == pattern }
                                ExclusionSettings.patterns = patterns
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minHeight: 120)

                HStack {
                    TextField("ディレクトリ名を追加...", text: $newPattern)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPattern() }
                    Button("追加") { addPattern() }
                        .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button("デフォルトに戻す") {
                    patterns = ExclusionSettings.defaultPatterns
                    ExclusionSettings.patterns = patterns
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("除外ディレクトリ")
            } footer: {
                Text("サイドバーに表示しないディレクトリ名を指定します。")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("用紙サイズ", selection: $pdfSettings.pageSize) {
                    ForEach(PDFPageSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .onChange(of: pdfSettings.pageSize) { _, _ in pdfSettings.save() }

                Picker("余白", selection: $pdfSettings.marginPreset) {
                    ForEach(PDFMarginPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: pdfSettings.marginPreset) { _, _ in pdfSettings.save() }

                Toggle("ヘッダーを表示（ファイル名）", isOn: $pdfSettings.showHeader)
                    .onChange(of: pdfSettings.showHeader) { _, _ in pdfSettings.save() }

                Toggle("フッターを表示（ページ番号）", isOn: $pdfSettings.showFooter)
                    .onChange(of: pdfSettings.showFooter) { _, _ in pdfSettings.save() }
            } header: {
                Text("PDFエクスポート")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 680)
    }

    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !patterns.contains(trimmed) else { return }
        patterns.append(trimmed)
        ExclusionSettings.patterns = patterns
        newPattern = ""
    }
}
