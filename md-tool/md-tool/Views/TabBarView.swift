import SwiftUI

struct TabBarView: View {
    let tabs: [URL]
    let activeTab: URL?
    let onSelect: (URL) -> Void
    let onClose: (URL) -> Void
    let isDirty: (URL) -> Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { url in
                        TabItemView(
                            url: url,
                            isActive: url.path == activeTab?.path,
                            isDirty: isDirty(url),
                            onSelect: { onSelect(url) },
                            onClose: { onClose(url) }
                        )
                    }
                }
            }
        }
        .frame(height: 30)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabItemView: View {
    let url: URL
    let isActive: Bool
    let isDirty: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Circle()
                    .fill(NomadColors.sandGold)
                    .frame(width: 6, height: 6)
            }
            Text(url.lastPathComponent)
                .font(.system(size: 12))
                .lineLimit(1)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isActive ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(isHovered && !isActive ? Color(nsColor: .controlAccentColor).opacity(0.05) : Color.clear)
        .modifier(ActiveTabGlassModifier(isActive: isActive))
        .overlay(alignment: .trailing) {
            Divider()
                .frame(height: 16)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct ActiveTabGlassModifier: ViewModifier {
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
        }
    }
}
