import SwiftUI

/// Comprehensive help and documentation view
struct HelpView: View {
    @State private var selectedSection: HelpSection = .gettingStarted
    @State private var searchText = ""

    enum HelpSection: String, CaseIterable, Identifiable {
        case gettingStarted = "Getting Started"
        case chat = "Chat & Questions"
        case documentLibrary = "Document Library"
        case watchFolder = "Custom Documents"
        case webScraper = "Web Scraper"
        case settings = "Settings"
        case troubleshooting = "Troubleshooting"
        case keyboardShortcuts = "Keyboard Shortcuts"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .gettingStarted: return "play.circle"
            case .chat: return "bubble.left.and.bubble.right"
            case .documentLibrary: return "books.vertical"
            case .watchFolder: return "folder.badge.plus"
            case .webScraper: return "globe"
            case .settings: return "gear"
            case .troubleshooting: return "wrench.and.screwdriver"
            case .keyboardShortcuts: return "keyboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(HelpSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Help")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    helpContent(for: selectedSection)
                }
                .padding(24)
                .frame(maxWidth: 700, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor))
        }
    }

    @ViewBuilder
    private func helpContent(for section: HelpSection) -> some View {
        switch section {
        case .gettingStarted:
            GettingStartedContent()
        case .chat:
            ChatHelpContent()
        case .documentLibrary:
            DocumentLibraryHelpContent()
        case .watchFolder:
            WatchFolderHelpContent()
        case .webScraper:
            WebScraperHelpContent()
        case .settings:
            SettingsHelpContent()
        case .troubleshooting:
            TroubleshootingHelpContent()
        case .keyboardShortcuts:
            KeyboardShortcutsContent()
        }
    }
}

// MARK: - Getting Started

struct GettingStartedContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Getting Started")
                .font(.largeTitle.bold())

            Text("Welcome to vmDocs - your AI-powered VMware documentation assistant. This app helps you quickly find answers to VMware-related questions using advanced RAG (Retrieval Augmented Generation) technology.")
                .font(.body)

            Divider()

            // Quick Start Steps
            HelpStepView(
                number: 1,
                title: "Install and Start Ollama",
                description: "vmDocs uses Ollama for local AI processing. Install from ollama.com and ensure it's running.",
                command: "ollama serve"
            )

            HelpStepView(
                number: 2,
                title: "Download Required Models",
                description: "Pull the chat and embedding models needed for vmDocs.",
                command: "ollama pull llama3.2 && ollama pull nomic-embed-text"
            )

            HelpStepView(
                number: 3,
                title: "Index Documentation",
                description: "Use the web scraper to download VMware documentation, or add your own PDFs via the Document Library.",
                tip: "Start with a single product to test, then expand."
            )

            HelpStepView(
                number: 4,
                title: "Ask Questions",
                description: "Once documents are indexed, go to Chat and ask questions in natural language. vmDocs will find relevant documentation and generate accurate answers with sources."
            )

            Divider()

            // Feature Overview
            Text("Feature Overview")
                .font(.title2.bold())

            FeatureCard(
                icon: "bubble.left.and.bubble.right",
                title: "AI Chat",
                description: "Ask questions in natural language about any VMware topic. Get accurate answers with source citations."
            )

            FeatureCard(
                icon: "books.vertical",
                title: "Document Library",
                description: "Browse all indexed documentation. Filter by product, search by keyword, and view document details."
            )

            FeatureCard(
                icon: "folder.badge.plus",
                title: "Custom Documents",
                description: "Add your own PDFs, design guides, and books. Drag and drop or use the watch folder."
            )

            FeatureCard(
                icon: "globe",
                title: "Web Scraper",
                description: "Download documentation from Broadcom TechDocs and other VMware sources automatically."
            )
        }
    }
}

// MARK: - Chat Help

struct ChatHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chat & Questions")
                .font(.largeTitle.bold())

            Text("The Chat view is your main interface for asking questions about VMware products. vmDocs uses RAG (Retrieval Augmented Generation) to find relevant documentation and generate accurate answers.")
                .font(.body)

            Divider()

            Text("How It Works")
                .font(.title2.bold())

            NumberedList(items: [
                "Type your question in natural language",
                "vmDocs searches the indexed documentation using hybrid search (semantic + keyword)",
                "Relevant chunks are retrieved and ranked",
                "The AI generates an answer based on the retrieved context",
                "Sources are displayed so you can verify the information"
            ])

            Divider()

            Text("Tips for Better Results")
                .font(.title2.bold())

            TipCard(
                tip: "Be Specific",
                description: "Instead of \"How does vSphere work?\", ask \"How do I configure vMotion in vSphere 8?\""
            )

            TipCard(
                tip: "Include Product Names",
                description: "Mention the specific VMware product (vSphere, NSX, vSAN) for more targeted results."
            )

            TipCard(
                tip: "Include Version Numbers",
                description: "If you need version-specific information, include it: \"vCenter 8.0 backup procedures\""
            )

            TipCard(
                tip: "Use Product Filters",
                description: "Enable product filters in the sidebar to restrict search to specific products."
            )

            Divider()

            Text("Example Questions")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                ExampleQuestion(text: "How do I install vCenter Server 8?")
                ExampleQuestion(text: "What are the system requirements for vSAN?")
                ExampleQuestion(text: "How do I configure NSX-T distributed firewall rules?")
                ExampleQuestion(text: "What's the best practice for vSphere HA configuration?")
                ExampleQuestion(text: "How do I troubleshoot vMotion failures?")
            }

            Divider()

            Text("Source Citations")
                .font(.title2.bold())

            Text("Every answer includes clickable source citations. Click on a source to:")
                .font(.body)

            BulletList(items: [
                "View the original documentation page",
                "See the full context of the information",
                "Verify the accuracy of the response"
            ])
        }
    }
}

// MARK: - Document Library Help

struct DocumentLibraryHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Document Library")
                .font(.largeTitle.bold())

            Text("The Document Library shows all indexed documentation. Browse, search, and manage your VMware knowledge base.")
                .font(.body)

            Divider()

            Text("Features")
                .font(.title2.bold())

            FeatureCard(
                icon: "line.3.horizontal.decrease.circle",
                title: "Filter by Product",
                description: "Use the sidebar toggles or the filter menu to show only specific VMware products."
            )

            FeatureCard(
                icon: "magnifyingglass",
                title: "Search",
                description: "Search document titles and content using the search bar."
            )

            FeatureCard(
                icon: "arrow.up.arrow.down",
                title: "Sort",
                description: "Sort by title, product, date added, or relevance."
            )

            FeatureCard(
                icon: "info.circle",
                title: "Document Details",
                description: "Click on any document to see its metadata, source URL, and indexed chunks."
            )

            Divider()

            Text("Document Status Icons")
                .font(.title2.bold())

            StatusLegend(icon: "checkmark.circle.fill", color: .green, label: "Indexed", description: "Document is fully indexed and searchable")
            StatusLegend(icon: "clock", color: .orange, label: "Pending", description: "Document is queued for indexing")
            StatusLegend(icon: "arrow.triangle.2.circlepath", color: .blue, label: "Indexing", description: "Document is currently being processed")
            StatusLegend(icon: "exclamationmark.circle.fill", color: .red, label: "Failed", description: "Indexing failed - click for details")
        }
    }
}

// MARK: - Watch Folder Help

struct WatchFolderHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Custom Documents")
                .font(.largeTitle.bold())

            Text("Add your own VMware-related documents to enhance your knowledge base. Upload design guides, books, KB articles, or any PDF/HTML content.")
                .font(.body)

            Divider()

            Text("Supported Formats")
                .font(.title2.bold())

            HStack(spacing: 20) {
                FormatBadge(format: "PDF", icon: "doc.text.fill")
                FormatBadge(format: "HTML", icon: "globe")
                FormatBadge(format: "Markdown", icon: "text.badge.checkmark")
                FormatBadge(format: "Plain Text", icon: "doc.plaintext")
            }

            Divider()

            Text("Adding Documents")
                .font(.title2.bold())

            FeatureCard(
                icon: "arrow.down.doc",
                title: "Drag and Drop",
                description: "Drag files directly into the drop zone in the Document Library."
            )

            FeatureCard(
                icon: "plus.circle",
                title: "Add Files Button",
                description: "Click \"Add Files\" to open the file picker and select documents."
            )

            FeatureCard(
                icon: "folder",
                title: "Watch Folder",
                description: "Place files in ~/Documents/vmDocs and they'll be automatically detected and indexed."
            )

            Divider()

            Text("Automatic Product Detection")
                .font(.title2.bold())

            Text("vmDocs automatically detects the VMware product based on the filename. For example:")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                DetectionExample(filename: "vSphere_Install_Guide.pdf", detected: "vSphere")
                DetectionExample(filename: "NSX-T_Admin_Guide.pdf", detected: "NSX")
                DetectionExample(filename: "vSAN_Best_Practices.pdf", detected: "vSAN")
            }

            Text("You can also manually select the product when adding files.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Suggested Documents")
                .font(.title2.bold())

            Text("Consider adding these types of documents for a comprehensive knowledge base:")
                .font(.body)

            BulletList(items: [
                "VMware Validated Designs (VVD) guides",
                "Architecture reference documents",
                "Product-specific best practices guides",
                "Certification study materials",
                "Internal runbooks and procedures"
            ])
        }
    }
}

// MARK: - Web Scraper Help

struct WebScraperHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Web Scraper")
                .font(.largeTitle.bold())

            Text("Download official VMware documentation from Broadcom TechDocs and other sources. The scraper handles pagination, retries, and content extraction automatically.")
                .font(.body)

            Divider()

            Text("Documentation Sources")
                .font(.title2.bold())

            SourceCard(
                name: "Broadcom TechDocs",
                url: "techdocs.broadcom.com",
                description: "Official product documentation including installation guides, admin guides, and API references.",
                pages: "~50,000 pages"
            )

            SourceCard(
                name: "Knowledge Base",
                url: "knowledge.broadcom.com",
                description: "Technical KB articles, troubleshooting guides, and known issues.",
                pages: "~50,000 articles"
            )

            SourceCard(
                name: "VMware Blogs",
                url: "blogs.vmware.com",
                description: "Technical blog posts from VMware engineers and experts.",
                pages: "~5,000 posts"
            )

            Divider()

            Text("How to Use")
                .font(.title2.bold())

            NumberedList(items: [
                "Open Settings → Scraper to configure options",
                "Select which documentation sources to scrape",
                "Choose specific products or scrape all",
                "Click \"Start Scraping\" and monitor progress",
                "Documents are automatically indexed as they're downloaded"
            ])

            Divider()

            Text("Scraper Settings")
                .font(.title2.bold())

            SettingExplanation(
                name: "Concurrent Requests",
                description: "Number of simultaneous downloads. Higher = faster, but be respectful to servers."
            )

            SettingExplanation(
                name: "Request Delay",
                description: "Pause between requests. Helps avoid rate limiting."
            )

            SettingExplanation(
                name: "Max Depth",
                description: "How many levels of links to follow. Higher values find more content but take longer."
            )

            Divider()

            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text("Note: Initial scraping of all documentation can take several hours. You can use the app while scraping runs in the background.")
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Settings Help

struct SettingsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle.bold())

            Text("Configure vmDocs to match your needs and hardware capabilities.")
                .font(.body)

            Divider()

            Text("Ollama Settings")
                .font(.title2.bold())

            SettingExplanation(
                name: "Ollama URL",
                description: "The address where Ollama is running. Default is http://localhost:11434"
            )

            SettingExplanation(
                name: "Connection Status",
                description: "Shows whether vmDocs can communicate with Ollama."
            )

            Divider()

            Text("Model Settings")
                .font(.title2.bold())

            SettingExplanation(
                name: "Chat Model",
                description: "The AI model used to generate responses. llama3.2 is recommended for speed; mistral for technical accuracy."
            )

            SettingExplanation(
                name: "Embedding Model",
                description: "Model used to create document embeddings for search. nomic-embed-text provides the best balance."
            )

            Divider()

            Text("RAG Settings")
                .font(.title2.bold())

            SettingExplanation(
                name: "Chunk Size",
                description: "Size of text segments for indexing. Larger = more context per chunk, smaller = more precise retrieval."
            )

            SettingExplanation(
                name: "Top K Results",
                description: "Number of relevant chunks retrieved for each query. More results = more context but slower."
            )

            SettingExplanation(
                name: "Vector Weight",
                description: "Balance between semantic search (understanding meaning) and keyword search (exact matches)."
            )

            SettingExplanation(
                name: "Temperature",
                description: "Controls response creativity. Lower = more focused/deterministic, higher = more varied."
            )
        }
    }
}

// MARK: - Troubleshooting Help

struct TroubleshootingHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Troubleshooting")
                .font(.largeTitle.bold())

            Text("Common issues and how to resolve them.")
                .font(.body)

            Divider()

            TroubleshootingItem(
                problem: "Ollama connection failed",
                solutions: [
                    "Ensure Ollama is installed: visit ollama.com",
                    "Start Ollama: run 'ollama serve' in Terminal",
                    "Check if another app is using port 11434",
                    "Verify URL in Settings → Ollama"
                ]
            )

            TroubleshootingItem(
                problem: "No models available",
                solutions: [
                    "Pull required models: 'ollama pull llama3.2'",
                    "Pull embedding model: 'ollama pull nomic-embed-text'",
                    "Click 'Refresh Models' in Settings"
                ]
            )

            TroubleshootingItem(
                problem: "Responses are slow",
                solutions: [
                    "Use a smaller model (llama3.2 instead of llama3.1:8b)",
                    "Reduce 'Top K Results' in RAG settings",
                    "Ensure no other resource-heavy apps are running",
                    "Check available RAM - AI models need significant memory"
                ]
            )

            TroubleshootingItem(
                problem: "Poor quality responses",
                solutions: [
                    "Index more documentation using the web scraper",
                    "Add relevant PDFs to the Document Library",
                    "Use more specific questions with product names",
                    "Increase 'Top K Results' for more context",
                    "Try a larger chat model (mistral, qwen2.5:7b)"
                ]
            )

            TroubleshootingItem(
                problem: "Scraping is stuck or failing",
                solutions: [
                    "Check your internet connection",
                    "Reduce concurrent requests in Settings",
                    "Increase request delay to avoid rate limiting",
                    "Some pages may be behind authentication"
                ]
            )

            TroubleshootingItem(
                problem: "App is using too much disk space",
                solutions: [
                    "Go to Settings → Storage to see usage breakdown",
                    "Clear cache to free up space",
                    "Remove unused documents from the library"
                ]
            )

            Divider()

            Text("Getting More Help")
                .font(.title2.bold())

            Text("If you're still having issues:")
                .font(.body)

            BulletList(items: [
                "Check the app logs in ~/Library/Logs/vmDocs/",
                "Visit github.com/anthropics/claude-code/issues for support",
                "Ensure you have the latest version of vmDocs and Ollama"
            ])
        }
    }
}

// MARK: - Keyboard Shortcuts

struct KeyboardShortcutsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle.bold())

            Text("Navigate vmDocs quickly with these keyboard shortcuts.")
                .font(.body)

            Divider()

            Text("Navigation")
                .font(.title2.bold())

            ShortcutRow(keys: "⌘ 1", action: "Go to Chat")
            ShortcutRow(keys: "⌘ 2", action: "Go to Document Library")
            ShortcutRow(keys: "⌘ 3", action: "Go to Search")
            ShortcutRow(keys: "⌘ ,", action: "Open Settings")
            ShortcutRow(keys: "⌘ ?", action: "Open Help")

            Divider()

            Text("Chat")
                .font(.title2.bold())

            ShortcutRow(keys: "⌘ N", action: "New Chat")
            ShortcutRow(keys: "⌘ ↩", action: "Send Message")
            ShortcutRow(keys: "⌘ .", action: "Stop Generation")
            ShortcutRow(keys: "⌘ K", action: "Clear Chat")
            ShortcutRow(keys: "⌘ ↑", action: "Previous Message")
            ShortcutRow(keys: "⌘ ↓", action: "Next Message")

            Divider()

            Text("General")
                .font(.title2.bold())

            ShortcutRow(keys: "⌘ F", action: "Focus Search")
            ShortcutRow(keys: "⌘ ⇧ S", action: "Toggle Sidebar")
            ShortcutRow(keys: "⌘ ⇧ E", action: "Export Chat")
            ShortcutRow(keys: "⌘ O", action: "Import Documents")
        }
    }
}

// MARK: - Helper Views

struct HelpStepView: View {
    let number: Int
    let title: String
    let description: String
    var command: String? = nil
    var tip: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let command = command {
                    HStack {
                        Text(command)
                            .font(.system(.callout, design: .monospaced))
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let tip = tip {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TipCard: View {
    let tip: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(tip)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ExampleQuestion: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "bubble.left")
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.body)
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct NumberedList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    Text(item)
                }
            }
        }
    }
}

struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(item)
                }
            }
        }
    }
}

struct StatusLegend: View {
    let icon: String
    let color: Color
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.headline)
                .frame(width: 80, alignment: .leading)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

struct FormatBadge: View {
    let format: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
            Text(format)
                .font(.caption)
        }
        .frame(width: 60, height: 60)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DetectionExample: View {
    let filename: String
    let detected: String

    var body: some View {
        HStack {
            Text(filename)
                .font(.system(.body, design: .monospaced))
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(detected)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
        }
    }
}

struct SourceCard: View {
    let name: String
    let url: String
    let description: String
    let pages: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(pages)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(url)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingExplanation: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TroubleshootingItem: View {
    let problem: String
    let solutions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(problem)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(solutions, id: \.self) { solution in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(solution)
                            .font(.body)
                    }
                }
            }
            .padding(.leading, 24)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80)

            Text(action)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HelpView()
        .frame(width: 900, height: 700)
}
