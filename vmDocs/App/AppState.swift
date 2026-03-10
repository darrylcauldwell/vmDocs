import SwiftUI
import SwiftData

/// Global application state
@Observable
final class AppState {

    // MARK: - Navigation

    enum NavigationTab: String, CaseIterable {
        case chat = "Chat"
        case library = "Library"
        case search = "Search"
        case watchFolder = "Custom Documents"
        case help = "Help"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .library: return "books.vertical"
            case .search: return "magnifyingglass"
            case .watchFolder: return "folder.badge.plus"
            case .help: return "questionmark.circle"
            }
        }

        var description: String {
            switch self {
            case .chat: return "Ask questions about VMware documentation"
            case .library: return "Browse and manage indexed documentation"
            case .search: return "Search across all documentation"
            case .watchFolder: return "Add your own PDFs and documents"
            case .help: return "View documentation and tutorials"
            }
        }
    }

    var selectedTab: NavigationTab = .chat
    var showImportSheet = false
    var showScraperSheet = false
    var showSettingsSheet = false

    // MARK: - Chat State

    var currentConversationId: UUID?
    var isStreaming = false
    var streamingText = ""
    var tokensPerSecond: Double = 0

    // MARK: - Filter State

    var selectedProducts: Set<String> = []
    var selectedVersions: Set<String> = []

    // MARK: - Connection State

    var isOllamaConnected = false
    var ollamaError: String?
    var availableModels: [String] = []
    var selectedChatModel = "llama3.2"
    var selectedEmbeddingModel = "nomic-embed-text"

    // MARK: - Index State

    var totalDocuments = 0
    var totalChunks = 0
    var isIndexing = false
    var indexingProgress: Double = 0
    var indexingStatus = ""

    // MARK: - Scraper State

    var isScraperRunning = false
    var scraperProgress: Double = 0
    var scraperStatus = ""
    var pagesDiscovered = 0
    var pagesProcessed = 0

    // MARK: - Services

    private(set) var ollamaClient: OllamaAPIClient?

    // MARK: - Initialization

    init() {
        // Initialize Ollama client
        let config = OllamaAPIClient.Config()
        ollamaClient = OllamaAPIClient(config: config)

        // Check Ollama connection
        Task {
            await checkOllamaConnection()
        }
    }

    // MARK: - Chat Actions

    func startNewChat() {
        currentConversationId = nil
        streamingText = ""
        isStreaming = false
    }

    func clearChatHistory() {
        // Will be handled by view model
    }

    func exportConversation() {
        // Will be handled by view model
    }

    // MARK: - Ollama Actions

    func checkOllamaConnection() async {
        guard let client = ollamaClient else {
            isOllamaConnected = false
            ollamaError = "Ollama client not initialized"
            return
        }

        let healthy = await client.isHealthy()

        await MainActor.run {
            isOllamaConnected = healthy
            if healthy {
                ollamaError = nil
            } else {
                ollamaError = "Cannot connect to Ollama. Make sure it's running on localhost:11434"
            }
        }

        if healthy {
            await refreshModels()
        }
    }

    func refreshModels() async {
        guard let client = ollamaClient else { return }

        do {
            let models = try await client.listModels()
            await MainActor.run {
                availableModels = models.map(\.name)
            }
        } catch {
            await MainActor.run {
                ollamaError = "Failed to list models: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Index Actions

    func refreshIndex() async {
        // Refresh statistics from vector store
        isIndexing = true
        indexingStatus = "Refreshing index statistics..."

        // Simulate delay for demo
        try? await Task.sleep(nanoseconds: 500_000_000)

        isIndexing = false
        indexingStatus = ""
    }

    // MARK: - Filter Actions

    func toggleProduct(_ product: String) {
        if selectedProducts.contains(product) {
            selectedProducts.remove(product)
        } else {
            selectedProducts.insert(product)
        }
    }

    func clearFilters() {
        selectedProducts.removeAll()
        selectedVersions.removeAll()
    }
}
