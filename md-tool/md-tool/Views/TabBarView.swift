import SwiftUI

struct TabBarView: View {
    let tabs: [TabItem]
    let activeTab: UUID?
    let onSelect: (TabItem) -> Void
    let onClose: (TabItem) -> Void
    let isDirty: (TabItem) -> Bool
    var isPreviewTab: (TabItem) -> Bool = { _ in false }
    var onPin: (TabItem) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == activeTab,
                            isDirty: isDirty(tab),
                            isPreview: isPreviewTab(tab),
                            onSelect: { onSelect(tab) },
                            onClose: { onClose(tab) },
                            onPin: { onPin(tab) }
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
    let tab: TabItem
    let isActive: Bool
    let isDirty: Bool
    let isPreview: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onPin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Circle()
                    .fill(NomadColors.sandGold)
                    .frame(width: 6, height: 6)
            }
            Text(tab.url.lastPathComponent)
                .font(.system(size: 12))
                .italic(isPreview)
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
        .background(isHovered && !isActive ? Color.accentColor.opacity(0.05) : Color.clear)
        .modifier(ActiveTabGlassModifier(isActive: isActive))
        .overlay(alignment: .trailing) {
            Divider()
                .frame(height: 16)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPin()
        }
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
