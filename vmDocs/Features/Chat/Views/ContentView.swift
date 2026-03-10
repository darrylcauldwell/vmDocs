import SwiftUI
import SwiftData

/// Main content view with sidebar navigation
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showSetupChecklist = false
    @State private var showKeyboardShortcuts = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showSetupChecklist) {
            SetupChecklistView()
        }
        .sheet(isPresented: Binding(
            get: { appState.showImportSheet },
            set: { appState.showImportSheet = $0 }
        )) {
            ImportDocumentsView()
        }
        .sheet(isPresented: Binding(
            get: { appState.showScraperSheet },
            set: { appState.showScraperSheet = $0 }
        )) {
            WebScraperView()
        }
        .sheet(isPresented: Binding(
            get: { appState.showSettingsSheet },
            set: { appState.showSettingsSheet = $0 }
        )) {
            SettingsView()
        }
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutsSheet()
        }
        .alert("Ollama Connection Error", isPresented: Binding(
            get: { appState.ollamaError != nil },
            set: { if !$0 { appState.ollamaError = nil } }
        )) {
            Button("Retry") {
                Task {
                    await appState.checkOllamaConnection()
                }
            }
            Button("Settings") {
                appState.showSettingsSheet = true
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(appState.ollamaError ?? "Unknown error")
        }
        // Keyboard shortcuts
        .keyboardShortcut("1", modifiers: .command) // Chat
        .keyboardShortcut("2", modifiers: .command) // Library
        .keyboardShortcut("3", modifiers: .command) // Search
        .keyboardShortcut(",", modifiers: .command) // Settings
        .keyboardShortcut("?", modifiers: .command) // Help
        .onAppear {
            // Check Ollama connection on launch
            Task {
                await appState.checkOllamaConnection()
                // Show setup checklist if Ollama not connected and onboarding complete
                if !appState.isOllamaConnected && !showOnboarding {
                    showSetupChecklist = true
                }
            }
        }
    }
}

/// Sidebar navigation
struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )) {
            Section("Main") {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    .tag(AppState.NavigationTab.chat)
                    .help("Ask questions about VMware documentation")

                Label("Document Library", systemImage: "books.vertical")
                    .tag(AppState.NavigationTab.library)
                    .help("Browse and manage indexed documentation")

                Label("Search", systemImage: "magnifyingglass")
                    .tag(AppState.NavigationTab.search)
                    .help("Search across all documentation")
            }

            Section("Add Content") {
                Label("Custom Documents", systemImage: "folder.badge.plus")
                    .tag(AppState.NavigationTab.watchFolder)
                    .help("Add your own PDFs and documents")

                Button {
                    appState.showScraperSheet = true
                } label: {
                    Label("Web Scraper", systemImage: "globe")
                }
                .help("Download documentation from Broadcom TechDocs")
            }

            Section("Status") {
                // Ollama status with tooltip
                HStack {
                    Circle()
                        .fill(appState.isOllamaConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text("Ollama")
                    Spacer()
                    Text(appState.isOllamaConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .help(appState.isOllamaConnected ? "Ollama is running and ready" : "Start Ollama to use AI features")

                // Index stats
                HStack {
                    Image(systemName: "doc.text")
                    Text("Documents")
                    Spacer()
                    Text("\(appState.totalDocuments)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .help("Total number of indexed documents")

                HStack {
                    Image(systemName: "square.stack.3d.up")
                    Text("Chunks")
                    Spacer()
                    Text("\(appState.totalChunks)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .help("Total searchable text chunks")
            }

            Section("Quick Filters") {
                ForEach(VMwareProduct.allCases.prefix(6), id: \.self) { product in
                    Toggle(isOn: Binding(
                        get: { appState.selectedProducts.contains(product.rawValue) },
                        set: { _ in appState.toggleProduct(product.rawValue) }
                    )) {
                        Label(product.displayName, systemImage: product.iconName)
                    }
                    .toggleStyle(.checkbox)
                    .help("Filter results to \(product.displayName) documentation")
                }

                if !appState.selectedProducts.isEmpty {
                    Button("Clear Filters") {
                        appState.clearFilters()
                    }
                    .font(.caption)
                }
            }

            Section {
                Label("Help", systemImage: "questionmark.circle")
                    .tag(AppState.NavigationTab.help)
                    .help("View documentation and tutorials")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("vmDocs")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.showSettingsSheet = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("Open Settings (⌘,)")

                Menu {
                    Button("Keyboard Shortcuts") {
                        // Show keyboard shortcuts
                    }
                    Button("View Help") {
                        appState.selectedTab = .help
                    }
                    Divider()
                    Link("Ollama Website", destination: URL(string: "https://ollama.com")!)
                    Link("VMware TechDocs", destination: URL(string: "https://techdocs.broadcom.com/us/en/vmware-cis.html")!)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Help & Resources")
            }
        }
    }
}

/// Detail view based on selected tab
struct DetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.selectedTab {
        case .chat:
            ChatView()
        case .library:
            DocumentLibraryView()
        case .search:
            SearchView()
        case .watchFolder:
            WatchFolderView()
        case .help:
            HelpView()
        }
    }
}

/// Keyboard shortcuts sheet
struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Shortcuts list
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ShortcutSection(title: "Navigation", shortcuts: [
                        ("⌘ 1", "Go to Chat"),
                        ("⌘ 2", "Go to Document Library"),
                        ("⌘ 3", "Go to Search"),
                        ("⌘ ,", "Open Settings"),
                        ("⌘ ?", "Open Help")
                    ])

                    ShortcutSection(title: "Chat", shortcuts: [
                        ("⌘ N", "New Chat"),
                        ("⌘ ↩", "Send Message"),
                        ("⌘ .", "Stop Generation"),
                        ("⌘ K", "Clear Chat")
                    ])

                    ShortcutSection(title: "General", shortcuts: [
                        ("⌘ F", "Focus Search"),
                        ("⌘ ⇧ S", "Toggle Sidebar"),
                        ("⌘ ⇧ E", "Export Chat"),
                        ("⌘ O", "Import Documents")
                    ])
                }
                .padding()
            }
        }
        .frame(width: 350, height: 450)
    }
}

struct ShortcutSection: View {
    let title: String
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(shortcuts, id: \.0) { shortcut in
                HStack {
                    Text(shortcut.0)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(width: 70, alignment: .leading)

                    Text(shortcut.1)
                        .font(.body)

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
