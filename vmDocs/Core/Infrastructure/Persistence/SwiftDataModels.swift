import Foundation
import SwiftData

// MARK: - Document Storage

@Model
final class StoredDocument {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceURLString: String?
    var localPathString: String?
    var product: String  // VMwareProduct.rawValue
    var version: String?
    var documentType: String  // DocumentType.rawValue
    var contentHash: String
    var chunkCount: Int
    var ingestedAt: Date
    var lastAccessedAt: Date?
    var breadcrumbsJSON: String  // JSON encoded [String]

    @Relationship(deleteRule: .cascade, inverse: \StoredChunk.document)
    var chunks: [StoredChunk] = []

    init(
        id: UUID = UUID(),
        title: String,
        sourceURL: URL? = nil,
        localPath: URL? = nil,
        product: String,
        version: String? = nil,
        documentType: String = "conceptual",
        contentHash: String,
        breadcrumbs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.sourceURLString = sourceURL?.absoluteString
        self.localPathString = localPath?.path
        self.product = product
        self.version = version
        self.documentType = documentType
        self.contentHash = contentHash
        self.chunkCount = 0
        self.ingestedAt = Date()
        self.lastAccessedAt = nil
        self.breadcrumbsJSON = (try? JSONEncoder().encode(breadcrumbs))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    // MARK: - Computed Properties

    var sourceURL: URL? {
        sourceURLString.flatMap { URL(string: $0) }
    }

    var localPath: URL? {
        localPathString.flatMap { URL(fileURLWithPath: $0) }
    }

    var breadcrumbs: [String] {
        guard let data = breadcrumbsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Chunk Storage

@Model
final class StoredChunk {
    @Attribute(.unique) var id: UUID
    var content: String
    var tokenCount: Int
    var sectionTitle: String?
    var headingHierarchyJSON: String  // JSON encoded [String]
    var containsCode: Bool
    var containsTable: Bool
    var positionStart: Int
    var positionEnd: Int
    var chunkIndex: Int
    var totalChunks: Int

    var document: StoredDocument?

    init(
        id: UUID = UUID(),
        content: String,
        tokenCount: Int,
        sectionTitle: String? = nil,
        headingHierarchy: [String] = [],
        containsCode: Bool = false,
        containsTable: Bool = false,
        positionStart: Int = 0,
        positionEnd: Int = 0,
        chunkIndex: Int = 0,
        totalChunks: Int = 0
    ) {
        self.id = id
        self.content = content
        self.tokenCount = tokenCount
        self.sectionTitle = sectionTitle
        self.headingHierarchyJSON = (try? JSONEncoder().encode(headingHierarchy))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.containsCode = containsCode
        self.containsTable = containsTable
        self.positionStart = positionStart
        self.positionEnd = positionEnd
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
    }

    var headingHierarchy: [String] {
        guard let data = headingHierarchyJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Chat Conversation Storage

@Model
final class StoredConversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    var productFiltersJSON: String  // JSON encoded [String]

    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.conversation)
    var messages: [StoredMessage] = []

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        productFilters: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.productFiltersJSON = (try? JSONEncoder().encode(productFilters))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    var productFilters: [String] {
        guard let data = productFiltersJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Chat Message Storage

@Model
final class StoredMessage {
    @Attribute(.unique) var id: UUID
    var role: String  // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var sourcesJSON: String  // JSON encoded [Source]
    var isStreaming: Bool

    var conversation: StoredConversation?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        sources: [StoredSource] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sourcesJSON = (try? JSONEncoder().encode(sources))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.isStreaming = isStreaming
    }

    var sources: [StoredSource] {
        guard let data = sourcesJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StoredSource].self, from: data)) ?? []
    }
}

// MARK: - Source (Codable, not @Model)

struct StoredSource: Codable, Identifiable {
    let id: UUID
    var referenceNumber: Int
    var title: String
    var product: String
    var version: String?
    var urlString: String?
    var sectionTitle: String?
    var relevanceScore: Float

    var url: URL? {
        urlString.flatMap { URL(string: $0) }
    }

    init(
        id: UUID = UUID(),
        referenceNumber: Int,
        title: String,
        product: String,
        version: String? = nil,
        url: URL? = nil,
        sectionTitle: String? = nil,
        relevanceScore: Float = 0
    ) {
        self.id = id
        self.referenceNumber = referenceNumber
        self.title = title
        self.product = product
        self.version = version
        self.urlString = url?.absoluteString
        self.sectionTitle = sectionTitle
        self.relevanceScore = relevanceScore
    }
}

// MARK: - Search Bookmark

@Model
final class StoredBookmark {
    @Attribute(.unique) var id: UUID
    var query: String
    var productFiltersJSON: String
    var createdAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        query: String,
        productFilters: [String] = [],
        note: String? = nil
    ) {
        self.id = id
        self.query = query
        self.productFiltersJSON = (try? JSONEncoder().encode(productFilters))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = Date()
        self.note = note
    }

    var productFilters: [String] {
        guard let data = productFiltersJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Scraper Progress (for resumability)

@Model
final class ScraperProgress {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var lastUpdatedAt: Date
    var state: String  // "running", "paused", "completed", "failed"
    var visitedURLsJSON: String
    var pendingURLsJSON: String
    var pagesProcessed: Int
    var totalDiscovered: Int
    var errorMessage: String?

    init(id: UUID = UUID()) {
        self.id = id
        self.startedAt = Date()
        self.lastUpdatedAt = Date()
        self.state = "running"
        self.visitedURLsJSON = "[]"
        self.pendingURLsJSON = "[]"
        self.pagesProcessed = 0
        self.totalDiscovered = 0
    }

    var visitedURLs: [String] {
        guard let data = visitedURLsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var pendingURLs: [String] {
        guard let data = pendingURLsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func updateVisitedURLs(_ urls: [String]) {
        visitedURLsJSON = (try? JSONEncoder().encode(urls))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        lastUpdatedAt = Date()
    }

    func updatePendingURLs(_ urls: [String]) {
        pendingURLsJSON = (try? JSONEncoder().encode(urls))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        lastUpdatedAt = Date()
    }
}

// MARK: - Settings Storage

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID

    // Ollama settings
    var ollamaURL: String
    var selectedChatModel: String
    var selectedEmbeddingModel: String
    var temperature: Float
    var contextWindow: Int

    // RAG settings
    var chunkSize: Int
    var chunkOverlap: Int
    var topK: Int
    var vectorWeight: Float
    var keywordWeight: Float

    // Scraper settings
    var maxConcurrentRequests: Int
    var requestDelay: Double
    var maxDepth: Int

    init() {
        self.id = UUID()
        self.ollamaURL = "http://localhost:11434"
        self.selectedChatModel = "llama3.2"
        self.selectedEmbeddingModel = "nomic-embed-text"
        self.temperature = 0.7
        self.contextWindow = 4096
        self.chunkSize = 512
        self.chunkOverlap = 50
        self.topK = 10
        self.vectorWeight = 0.7
        self.keywordWeight = 0.3
        self.maxConcurrentRequests = 5
        self.requestDelay = 0.5
        self.maxDepth = 10
    }
}
