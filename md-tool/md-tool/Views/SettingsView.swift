import SwiftUI

struct SettingsView: View {
    @State private var patterns: [String] = ExclusionSettings.patterns
    @State private var newPattern = ""

    var body: some View {
        Form {
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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
    }

    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !patterns.contains(trimmed) else { return }
        patterns.append(trimmed)
        ExclusionSettings.patterns = patterns
        newPattern = ""
    }
}
