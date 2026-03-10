import Foundation

/// A chunk of document content optimized for RAG retrieval
struct DocumentChunk: Identifiable, Codable, Sendable {
    let id: UUID
    let documentId: UUID
    var content: String
    var tokenCount: Int
    var metadata: ChunkMetadata
    var position: ChunkPosition

    init(
        id: UUID = UUID(),
        documentId: UUID,
        content: String,
        tokenCount: Int,
        metadata: ChunkMetadata,
        position: ChunkPosition
    ) {
        self.id = id
        self.documentId = documentId
        self.content = content
        self.tokenCount = tokenCount
        self.metadata = metadata
        self.position = position
    }
}

/// Metadata associated with a chunk
struct ChunkMetadata: Codable, Sendable {
    var sectionTitle: String?
    var headingHierarchy: [String]
    var containsCode: Bool
    var containsTable: Bool
    var pageNumber: Int?
    var documentTitle: String
    var product: VMwareProduct
    var version: String?
    var sourceURL: URL?

    init(
        sectionTitle: String? = nil,
        headingHierarchy: [String] = [],
        containsCode: Bool = false,
        containsTable: Bool = false,
        pageNumber: Int? = nil,
        documentTitle: String,
        product: VMwareProduct,
        version: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.headingHierarchy = headingHierarchy
        self.containsCode = containsCode
        self.containsTable = containsTable
        self.pageNumber = pageNumber
        self.documentTitle = documentTitle
        self.product = product
        self.version = version
        self.sourceURL = sourceURL
    }
}

/// Position information for a chunk within its source document
struct ChunkPosition: Codable, Sendable {
    var startOffset: Int
    var endOffset: Int
    var chunkIndex: Int
    var totalChunks: Int

    init(
        startOffset: Int,
        endOffset: Int,
        chunkIndex: Int,
        totalChunks: Int = 0
    ) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
    }
}

/// Result from a similarity search
struct SimilarityResult: Identifiable, Sendable {
    let id: UUID
    let chunkId: UUID
    let distance: Float
    let content: String
    let sectionTitle: String?
    let documentTitle: String
    let product: VMwareProduct
    let version: String?
    let sourceURL: URL?
    let score: Float  // Normalized similarity score (1.0 = identical)

    init(
        chunkId: UUID,
        distance: Float,
        content: String,
        sectionTitle: String?,
        documentTitle: String,
        product: VMwareProduct,
        version: String?,
        sourceURL: URL?
    ) {
        self.id = chunkId
        self.chunkId = chunkId
        self.distance = distance
        self.content = content
        self.sectionTitle = sectionTitle
        self.documentTitle = documentTitle
        self.product = product
        self.version = version
        self.sourceURL = sourceURL
        // Convert distance to similarity score (assuming L2 distance)
        self.score = 1.0 / (1.0 + distance)
    }
}

/// Result from BM25 keyword search
struct KeywordResult: Identifiable, Sendable {
    let id: UUID
    let chunkId: UUID
    let score: Float
    let content: String
    let snippet: String
    let sectionTitle: String?
    let documentTitle: String
    let product: VMwareProduct

    init(
        chunkId: UUID,
        score: Float,
        content: String,
        snippet: String,
        sectionTitle: String?,
        documentTitle: String,
        product: VMwareProduct
    ) {
        self.id = chunkId
        self.chunkId = chunkId
        self.score = score
        self.content = content
        self.snippet = snippet
        self.sectionTitle = sectionTitle
        self.documentTitle = documentTitle
        self.product = product
    }
}

/// Combined ranked result from hybrid search
struct RankedChunk: Identifiable, Sendable {
    let id: UUID
    let chunk: DocumentChunk
    let combinedScore: Float
    let vectorScore: Float
    let keywordScore: Float
    let documentTitle: String
    let sourceURL: URL?

    init(
        chunk: DocumentChunk,
        combinedScore: Float,
        vectorScore: Float,
        keywordScore: Float,
        documentTitle: String,
        sourceURL: URL?
    ) {
        self.id = chunk.id
        self.chunk = chunk
        self.combinedScore = combinedScore
        self.vectorScore = vectorScore
        self.keywordScore = keywordScore
        self.documentTitle = documentTitle
        self.sourceURL = sourceURL
    }
}
