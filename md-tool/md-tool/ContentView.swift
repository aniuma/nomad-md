import SwiftUI
import UniformTypeIdentifiers

enum ViewMode {
    case preview
    case edit
    case split
}

struct ContentView: View {
    @State private var appState = AppState()
    @State private var sidebarVM: SidebarViewModel?
    @State private var previewVM = PreviewViewModel()
    @State private var editorVM = EditorViewModel()
    @State private var viewMode: ViewMode = .preview
    @State private var showQuickOpen = false
    @State private var showSearch = false
    @State private var showIndex = false
    @State private var showRecentFiles = false
    @State private var showTOC = UserDefaults.standard.object(forKey: "showTOC") as? Bool ?? true
    @State private var previewTheme = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
    @State private var appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationTitle(windowTitle)
        .navigationSplitViewColumnWidth(min: 140, ideal: 200, max: 320)
        .preferredColorScheme(preferredColorScheme)
        .overlay { quickOpenOverlay }
        .overlay { searchOverlay }
        .overlay { indexOverlay }
        .overlay { recentFilesOverlay }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .modifier(NotificationModifier(
            appState: appState,
            sidebarVM: $sidebarVM,
            previewVM: previewVM,
            editorVM: editorVM,
            viewMode: $viewMode,
            showQuickOpen: $showQuickOpen,
            showSearch: $showSearch,
            showIndex: $showIndex,
            showRecentFiles: $showRecentFiles,
            showTOC: $showTOC,
            previewTheme: $previewTheme,
            appearanceMode: $appearanceMode,
            selectFile: selectFile,
            closeTab: closeTab,
            initSidebarVM: initSidebarVM
        ))
        .alert("ファイルが外部で変更されました", isPresented: Binding(
            get: { editorVM.hasConflict },
            set: { if !$0 { editorVM.resolveConflict(.keepLocal) } }
        )) {
            Button("外部の変更を読み込む") {
                editorVM.resolveConflict(.reload)
                if viewMode == .split {
                    previewVM.loadFile(at: appState.selectedFileURL)
                }
            }
            Button("ローカルの編集を維持", role: .cancel) {
                editorVM.resolveConflict(.keepLocal)
            }
        } message: {
            Text("編集中のファイルが別のアプリで変更されました。どちらの内容を使いますか？")
        }
        .onAppear {
            if !appState.registeredFolderURLs.isEmpty {
                initSidebarVM()
                if let url = appState.selectedFileURL {
                    previewVM.loadFile(at: url)
                } else if let firstRoot = sidebarVM?.rootNodes.first,
                          let first = FileSystemService.findFirstMarkdownFile(in: firstRoot) {
                    selectFile(first)
                }
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        if let vm = sidebarVM {
            SidebarView(
                viewModel: vm,
                selectedFileURL: appState.selectedFileURL,
                onSelect: { url in selectFile(url) }
            )
        } else {
            WelcomeView {
                initSidebarVM()
                sidebarVM?.addFolder()
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let fileURL = appState.selectedFileURL, fileURL.hasDirectoryPath {
            directoryPlaceholder(fileURL)
        } else if appState.activeTabURL != nil {
            VStack(spacing: 0) {
                tabBar
                fileSizeWarningBanner
                fileContentView
            }
        } else if !appState.registeredFolderURLs.isEmpty {
            Text("Markdownファイルを選択してください")
                .foregroundStyle(.secondary)
        } else {
            WelcomeView {
                initSidebarVM()
                sidebarVM?.addFolder()
            }
        }
    }

    @ViewBuilder
    private func directoryPlaceholder(_ fileURL: URL) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "compass.drawing")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(NomadColors.sandGold.opacity(0.6))
            Text("「\(fileURL.lastPathComponent)」にMarkdownファイルがありません")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("サイドバーからMarkdownファイルを選択してください。")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabBar: some View {
        if !appState.openTabs.isEmpty {
            TabBarView(
                tabs: appState.openTabs,
                activeTab: appState.activeTabURL,
                onSelect: { url in activateTab(url) },
                onClose: { url in closeTab(url) },
                isDirty: { url in
                    (viewMode == .edit || viewMode == .split)
                        && editorVM.currentFileURL?.path == url.path
                        && editorVM.isDirty
                }
            )
        }
    }

    @ViewBuilder
    private var fileSizeWarningBanner: some View {
        if let warning = previewVM.fileSizeWarning, warning != .tooLarge {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(warning == .veryLarge ? "大きなファイルです（10MB超）。表示に時間がかかる場合があります。" : "大きなファイルです（1MB超）。")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var fileContentView: some View {
        if let fileURL = appState.activeTabURL {
            Group {
                switch viewMode {
                case .preview:
                    previewContent(fileURL: fileURL)
                case .edit:
                    editContent
                case .split:
                    splitContent(fileURL: fileURL)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func previewContent(fileURL: URL) -> some View {
        PreviewView(
            htmlContent: previewVM.htmlContent,
            baseURL: fileURL.deletingLastPathComponent(),
            showTOC: showTOC,
            theme: previewTheme,
            onInternalLink: { url in selectFile(url) },
            onToggleCheckbox: { line in previewVM.toggleCheckbox(at: line) }
        )
    }

    @ViewBuilder
    private var editContent: some View {
        if editorVM.fileTooLarge {
            Text("ファイルサイズが10MBを超えています。編集できません。")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EditorView(
                text: $editorVM.text,
                fileURL: appState.activeTabURL,
                onTextChange: { editorVM.textDidChange($0) }
            )
        }
    }

    @ViewBuilder
    private func splitContent(fileURL: URL) -> some View {
        HSplitView {
            EditorView(
                text: $editorVM.text,
                fileURL: fileURL,
                onTextChange: { newText in
                    editorVM.textDidChange(newText)
                    previewVM.renderFromText(newText, baseURL: fileURL.deletingLastPathComponent())
                }
            )
            .frame(minWidth: 300)
            PreviewView(
                htmlContent: previewVM.htmlContent,
                baseURL: fileURL.deletingLastPathComponent(),
                showTOC: showTOC,
                theme: previewTheme,
                onInternalLink: { url in selectFile(url) },
                onToggleCheckbox: { line in previewVM.toggleCheckbox(at: line) }
            )
            .frame(minWidth: 300)
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var quickOpenOverlay: some View {
        if showQuickOpen, let vm = sidebarVM {
            modalOverlay(onDismiss: { showQuickOpen = false }) {
                QuickOpenView(
                    files: vm.rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) },
                    onSelect: { url in selectFile(url) },
                    onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showQuickOpen = false } }
                )
            }
        }
    }

    @ViewBuilder
    private var searchOverlay: some View {
        if showSearch, let vm = sidebarVM {
            modalOverlay(onDismiss: { showSearch = false }) {
                SearchView(
                    files: vm.rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) },
                    onSelect: { url in selectFile(url) },
                    onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showSearch = false } }
                )
            }
        }
    }

    @ViewBuilder
    private var indexOverlay: some View {
        if showIndex, let vm = sidebarVM {
            modalOverlay(onDismiss: { showIndex = false }) {
                IndexView(
                    files: vm.rootNodes.flatMap { FileSystemService.collectAllMarkdownFiles(in: $0) },
                    rootFolders: appState.registeredFolderURLs,
                    onSelect: { url in selectFile(url) },
                    onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showIndex = false } }
                )
            }
        }
    }

    @ViewBuilder
    private var recentFilesOverlay: some View {
        if showRecentFiles {
            modalOverlay(onDismiss: { showRecentFiles = false }) {
                RecentFilesView(
                    recentFiles: appState.recentFiles,
                    onSelect: { url in selectFile(url) },
                    onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showRecentFiles = false } },
                    onClear: {
                        appState.recentFiles = []
                        BookmarkManager.clearRecentFiles()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func modalOverlay<Content: View>(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { onDismiss() } }
            VStack {
                content()
                    .padding(.top, 80)
                Spacer()
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private var windowTitle: String {
        guard let url = appState.activeTabURL ?? appState.selectedFileURL else { return "Nomad" }
        let name = url.lastPathComponent
        let dirty = (viewMode == .edit || viewMode == .split) && editorVM.isDirty
        return dirty ? "● \(name)" : name
    }

    private func selectFile(_ url: URL) {
        if viewMode == .edit || viewMode == .split {
            editorVM.saveImmediately()
        }
        appState.selectFile(url)
        previewVM.loadFile(at: url)
        if viewMode == .edit || viewMode == .split {
            editorVM.loadFile(at: url)
        }
    }

    private func activateTab(_ url: URL) {
        if viewMode == .edit || viewMode == .split {
            editorVM.saveImmediately()
        }
        appState.activateTab(url)
        previewVM.loadFile(at: url)
        if viewMode == .edit || viewMode == .split {
            editorVM.loadFile(at: url)
        }
    }

    private func closeTab(_ url: URL) {
        if viewMode == .edit || viewMode == .split {
            if editorVM.currentFileURL?.path == url.path {
                editorVM.saveImmediately()
            }
        }
        appState.closeTab(url)
        if let newActive = appState.activeTabURL {
            previewVM.loadFile(at: newActive)
            if viewMode == .edit || viewMode == .split {
                editorVM.loadFile(at: newActive)
            }
        } else {
            previewVM.loadFile(at: nil)
            editorVM.loadFile(at: nil)
            if viewMode != .preview {
                viewMode = .preview
            }
        }
    }

    private func initSidebarVM() {
        if sidebarVM == nil {
            sidebarVM = SidebarViewModel(appState: appState)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let urlString = String(data: data, encoding: .utf8),
                      let url = URL(string: urlString) else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
                DispatchQueue.main.async {
                    if isDir.boolValue {
                        initSidebarVM()
                        sidebarVM?.addFolderByURL(url)
                    } else {
                        let ext = url.pathExtension.lowercased()
                        if ext == "md" || ext == "markdown" {
                            selectFile(url)
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Notification Modifier

private struct NotificationModifier: ViewModifier {
    let appState: AppState
    @Binding var sidebarVM: SidebarViewModel?
    let previewVM: PreviewViewModel
    let editorVM: EditorViewModel
    @Binding var viewMode: ViewMode
    @Binding var showQuickOpen: Bool
    @Binding var showSearch: Bool
    @Binding var showIndex: Bool
    @Binding var showRecentFiles: Bool
    @Binding var showTOC: Bool
    @Binding var previewTheme: String
    @Binding var appearanceMode: String
    let selectFile: (URL) -> Void
    let closeTab: (URL) -> Void
    let initSidebarVM: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .quickOpen)) { _ in
                if sidebarVM != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showSearch = false; showIndex = false; showRecentFiles = false
                        showQuickOpen.toggle()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fullTextSearch)) { _ in
                if sidebarVM != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showQuickOpen = false; showIndex = false; showRecentFiles = false
                        showSearch.toggle()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showIndex)) { _ in
                if sidebarVM != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showQuickOpen = false; showSearch = false; showRecentFiles = false
                        showIndex.toggle()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showRecentFiles)) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    showQuickOpen = false; showSearch = false; showIndex = false
                    showRecentFiles.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
                if let activeURL = appState.activeTabURL {
                    closeTab(activeURL)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
                previewTheme = UserDefaults.standard.string(forKey: "previewTheme") ?? "default"
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleTOC)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { showTOC.toggle() }
                UserDefaults.standard.set(showTOC, forKey: "showTOC")
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
                if viewMode == .edit || viewMode == .split {
                    editorVM.saveImmediately()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleEditMode)) { _ in
                guard appState.selectedFileURL != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch viewMode {
                    case .preview:
                        editorVM.loadFile(at: appState.selectedFileURL)
                        viewMode = .edit
                    case .edit, .split:
                        editorVM.saveImmediately()
                        previewVM.loadFile(at: appState.selectedFileURL)
                        viewMode = .preview
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSplitMode)) { _ in
                guard appState.selectedFileURL != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewMode == .split {
                        editorVM.saveImmediately()
                        previewVM.loadFile(at: appState.selectedFileURL)
                        viewMode = .preview
                    } else {
                        if viewMode == .edit { editorVM.saveImmediately() }
                        editorVM.loadFile(at: appState.selectedFileURL)
                        previewVM.loadFile(at: appState.selectedFileURL)
                        viewMode = .split
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportHTML)) { _ in
                guard let fileURL = appState.activeTabURL ?? appState.selectedFileURL,
                      !previewVM.htmlContent.isEmpty else { return }
                ExportService.exportHTML(
                    htmlBody: previewVM.htmlContent,
                    theme: previewTheme,
                    showTOC: showTOC,
                    sourceFileName: fileURL.lastPathComponent
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in
                guard let fileURL = appState.activeTabURL ?? appState.selectedFileURL,
                      !previewVM.htmlContent.isEmpty else { return }
                ExportService.exportPDF(
                    htmlBody: previewVM.htmlContent,
                    sourceFileName: fileURL.lastPathComponent,
                    settings: PDFExportSettings.load()
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFileByURL)) { notification in
                guard let fileURL = notification.object as? URL else { return }
                initSidebarVM()
                let parentFolder = fileURL.deletingLastPathComponent()
                if !appState.registeredFolderURLs.contains(where: { parentFolder.path.hasPrefix($0.path) }) {
                    sidebarVM?.addFolderByURL(parentFolder)
                }
                selectFile(fileURL)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appearanceChanged)) { _ in
                appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNewFile)) { _ in
                guard let vm = sidebarVM else { return }
                let dir = appState.selectedFileURL?.hasDirectoryPath == true
                    ? appState.selectedFileURL
                    : appState.selectedFileURL?.deletingLastPathComponent()
                if let url = vm.createNewFile(in: dir) {
                    selectFile(url)
                    if viewMode == .preview {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            editorVM.loadFile(at: url)
                            viewMode = .edit
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFolderByURL)) { notification in
                guard let folderURL = notification.object as? URL else { return }
                initSidebarVM()
                sidebarVM?.addFolderByURL(folderURL)
            }
    }
}
