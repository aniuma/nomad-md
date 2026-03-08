import SwiftUI

struct RecentFilesView: View {
    let recentFiles: [URL]
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void
    let onClear: () -> Void

    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .foregroundStyle(.secondary)
                Text("最近使った項目")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if !recentFiles.isEmpty {
                    Button("クリア") {
                        onClear()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            if recentFiles.isEmpty {
                Text("最近使った項目はありません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    List(Array(recentFiles.enumerated()), id: \.element) { index, url in
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .id(index)
                        .contentShape(Rectangle())
                        .listRowBackground(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                        .onTapGesture {
                            onSelect(url)
                            onDismiss()
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < recentFiles.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            guard !recentFiles.isEmpty, selectedIndex < recentFiles.count else { return .ignored }
            onSelect(recentFiles[selectedIndex])
            onDismiss()
            return .handled
        }
    }
}
