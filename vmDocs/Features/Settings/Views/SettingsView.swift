import SwiftUI
import SwiftData
import vmDocsCore

/// Settings view for configuring the application
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            OllamaSettingsTab()
                .tabItem {
                    Label("Ollama", systemImage: "cpu")
                }

            ModelsSettingsTab()
                .tabItem {
                    Label("Models", systemImage: "brain")
                }

            RAGSettingsTab()
                .tabItem {
                    Label("RAG", systemImage: "magnifyingglass")
                }

            ScraperSettingsTab()
                .tabItem {
                    Label("Scraper", systemImage: "globe")
                }

            StorageSettingsTab()
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
        }
        .frame(width: 600, height: 450)
    }
}

/// Ollama connection settings
struct OllamaSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var ollamaURL = "http://localhost:11434"
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Ollama URL", text: $ollamaURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Circle()
                        .fill(appState.isOllamaConnected ? .green : .red)
                        .frame(width: 10, height: 10)

                    Text(appState.isOllamaConnected ? "Connected" : "Not Connected")
                        .foregroundStyle(appState.isOllamaConnected ? .green : .red)

                    Spacer()

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Button("Test Connection") {
                        Task {
                            isTesting = true
                            await appState.checkOllamaConnection()
                            testResult = appState.isOllamaConnected ? "Connection successful!" : "Connection failed"
                            isTesting = false
                        }
                    }
                }

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(appState.isOllamaConnected ? .green : .red)
                }
            }

            Section("Available Models") {
                if appState.availableModels.isEmpty {
                    Text("No models found. Pull models using Ollama CLI.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.availableModels, id: \.self) { model in
                        HStack {
                            Image(systemName: "cube.box")
                            Text(model)
                            Spacer()
                        }
                    }
                }

                Button("Refresh Models") {
                    Task {
                        await appState.refreshModels()
                    }
                }
            }

            Section("Installation Help") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To install Ollama:")
                        .font(.headline)

                    Text("1. Visit https://ollama.com and download for macOS")
                    Text("2. Install and run Ollama")
                    Text("3. Pull recommended models:")

                    HStack {
                        Text("ollama pull llama3.2")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(4)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("ollama pull llama3.2", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }

                    HStack {
                        Text("ollama pull nomic-embed-text")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(4)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("ollama pull nomic-embed-text", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// Model selection settings
struct ModelsSettingsTab: View {
    @Environment(AppState.self) private var appState

    struct RecommendedModel: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let size: String
        let recommended: Bool
    }

    let chatModels = [
        RecommendedModel(name: "llama3.2", description: "Fast, good quality responses", size: "2GB", recommended: true),
        RecommendedModel(name: "llama3.1:8b", description: "Better quality, more resources", size: "4.7GB", recommended: false),
        RecommendedModel(name: "mistral", description: "Excellent for technical content", size: "4.1GB", recommended: true),
        RecommendedModel(name: "qwen2.5:7b", description: "Strong reasoning capabilities", size: "4.4GB", recommended: true)
    ]

    let embeddingModels = [
        RecommendedModel(name: "nomic-embed-text", description: "Best balance of quality and speed", size: "274MB", recommended: true),
        RecommendedModel(name: "mxbai-embed-large", description: "Higher quality embeddings", size: "670MB", recommended: false),
        RecommendedModel(name: "all-minilm", description: "Fastest, lightweight", size: "45MB", recommended: false)
    ]

    var body: some View {
        Form {
            Section("Chat Model") {
                Picker("Selected Model", selection: Binding(
                    get: { appState.selectedChatModel },
                    set: { appState.selectedChatModel = $0 }
                )) {
                    ForEach(appState.availableModels.isEmpty ? chatModels.map(\.name) : appState.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                Text("Used for generating responses to your questions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Recommended Chat Models")
                    .font(.headline)

                ForEach(chatModels) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(model.name)
                                    .font(.headline)
                                if model.recommended {
                                    Text("Recommended")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(model.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(model.size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Embedding Model") {
                Picker("Selected Model", selection: Binding(
                    get: { appState.selectedEmbeddingModel },
                    set: { appState.selectedEmbeddingModel = $0 }
                )) {
                    ForEach(embeddingModels.map(\.name), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                Text("Used for semantic search and document indexing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// RAG pipeline settings
struct RAGSettingsTab: View {
    @State private var chunkSize = 512
    @State private var chunkOverlap = 50
    @State private var topK = 10
    @State private var vectorWeight: Float = 0.7
    @State private var temperature: Float = 0.7
    @State private var contextWindow = 4096

    var body: some View {
        Form {
            Section("Chunking") {
                VStack(alignment: .leading) {
                    Text("Chunk Size: \(chunkSize) tokens")
                    Slider(value: Binding(
                        get: { Double(chunkSize) },
                        set: { chunkSize = Int($0) }
                    ), in: 256...1024, step: 64)
                    Text("Size of text chunks for indexing. Larger chunks provide more context but less precision.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Chunk Overlap: \(chunkOverlap) tokens")
                    Slider(value: Binding(
                        get: { Double(chunkOverlap) },
                        set: { chunkOverlap = Int($0) }
                    ), in: 0...200, step: 10)
                    Text("Overlap between consecutive chunks to preserve context at boundaries.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Retrieval") {
                VStack(alignment: .leading) {
                    Text("Top K Results: \(topK)")
                    Slider(value: Binding(
                        get: { Double(topK) },
                        set: { topK = Int($0) }
                    ), in: 3...20, step: 1)
                    Text("Number of relevant chunks to retrieve for each query.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Vector Weight: \(vectorWeight, specifier: "%.1f")")
                    Slider(value: $vectorWeight, in: 0...1, step: 0.1)
                    Text("Balance between semantic (vector) and keyword (BM25) search. Higher = more semantic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Generation") {
                VStack(alignment: .leading) {
                    Text("Temperature: \(temperature, specifier: "%.1f")")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                    Text("Controls randomness. Lower = more focused, higher = more creative.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Context Window: \(contextWindow)")
                    Slider(value: Binding(
                        get: { Double(contextWindow) },
                        set: { contextWindow = Int($0) }
                    ), in: 2048...32768, step: 1024)
                    Text("Maximum context length for the model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

/// Scraper settings
struct ScraperSettingsTab: View {
    @State private var maxConcurrentRequests = 5
    @State private var requestDelay: Double = 0.5
    @State private var maxDepth = 10

    var body: some View {
        Form {
            Section("Performance") {
                VStack(alignment: .leading) {
                    Text("Concurrent Requests: \(maxConcurrentRequests)")
                    Slider(value: Binding(
                        get: { Double(maxConcurrentRequests) },
                        set: { maxConcurrentRequests = Int($0) }
                    ), in: 1...10, step: 1)
                    Text("Number of simultaneous requests. Higher = faster but more load on servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Request Delay: \(requestDelay, specifier: "%.1f")s")
                    Slider(value: $requestDelay, in: 0.1...2.0, step: 0.1)
                    Text("Delay between requests to be respectful to servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Crawling") {
                VStack(alignment: .leading) {
                    Text("Max Depth: \(maxDepth)")
                    Slider(value: Binding(
                        get: { Double(maxDepth) },
                        set: { maxDepth = Int($0) }
                    ), in: 1...20, step: 1)
                    Text("Maximum link depth to follow from entry points.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sources") {
                Text("Documentation sources are configured in the scraper view.")
                    .foregroundStyle(.secondary)

                ForEach(DocumentationSources.allSources, id: \.id) { source in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(source.name)
                                .font(.headline)
                            Text(source.baseURL.host ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("~\(source.estimatedPages) pages")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
    }
}

/// Storage settings
struct StorageSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var vectorDBSize = "0 MB"
    @State private var documentsSize = "0 MB"

    var body: some View {
        Form {
            Section("Statistics") {
                HStack {
                    Text("Total Documents")
                    Spacer()
                    Text("\(appState.totalDocuments)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Total Chunks")
                    Spacer()
                    Text("\(appState.totalChunks)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Vector Database Size")
                    Spacer()
                    Text(vectorDBSize)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Document Cache Size")
                    Spacer()
                    Text(documentsSize)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Locations") {
                VStack(alignment: .leading) {
                    Text("Data Directory")
                        .font(.headline)
                    Text("~/Library/Application Support/vmDocs/")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Button("Open in Finder") {
                        if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                            NSWorkspace.shared.open(url.appendingPathComponent("vmDocs"))
                        }
                    }
                }

                VStack(alignment: .leading) {
                    Text("Vector Database")
                        .font(.headline)
                    Text("~/Library/Application Support/vmDocs/vectors.db")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Maintenance") {
                Button("Rebuild Index") {
                    // Trigger index rebuild
                }
                .help("Re-index all documents. This may take a while.")

                Button("Clear Cache") {
                    // Clear document cache
                }
                .help("Clear downloaded document cache.")

                Button("Reset All Data", role: .destructive) {
                    // Show confirmation and clear all data
                }
                .help("Delete all indexed documents and reset the database.")
            }
        }
        .padding()
        .onAppear {
            calculateStorageSize()
        }
    }

    private func calculateStorageSize() {
        // Calculate actual storage sizes
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let vmDocsDir = appSupport.appendingPathComponent("vmDocs")

            // Vector DB
            let vectorDBPath = vmDocsDir.appendingPathComponent("vectors.db")
            if let attrs = try? fileManager.attributesOfItem(atPath: vectorDBPath.path) {
                let size = attrs[.size] as? Int64 ?? 0
                vectorDBSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }

            // Documents directory
            let docsDir = vmDocsDir.appendingPathComponent("documents")
            if let size = directorySize(at: docsDir) {
                documentsSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        }
    }

    private func directorySize(at url: URL) -> Int64? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                totalSize += attrs[.size] as? Int64 ?? 0
            }
        }
        return totalSize
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
