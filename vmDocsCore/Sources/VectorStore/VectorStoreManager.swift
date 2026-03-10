import Foundation
import SQLiteVec

/// Manager for SQLiteVec vector database operations
/// Handles embeddings storage and similarity search
public actor VectorStoreManager {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let databasePath: URL
        public let embeddingDimension: Int

        public init(
            databasePath: URL,
            embeddingDimension: Int = 768  // nomic-embed-text default
        ) {
            self.databasePath = databasePath
            self.embeddingDimension = embeddingDimension
        }
    }

    // MARK: - Properties

    private let config: Config
    private var db: Database?
    private var isInitialized = false

    // MARK: - Initialization

    public init(config: Config) {
        self.config = config
    }

    /// Initialize the database and create tables
    public func initialize() async throws {
        guard !isInitialized else { return }

        // Initialize SQLiteVec
        try SQLiteVec.initialize()

        // Ensure directory exists
        let directory = config.databasePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // Open database
        db = try Database(.uri(config.databasePath.path))

        // Create tables
        try await createTables()

        isInitialized = true
    }

    private func createTables() async throws {
        guard let db = db else { throw VectorStoreError.notInitialized }

        // Vector embeddings table using vec0
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS chunk_embeddings
            USING vec0(
                chunk_id TEXT PRIMARY KEY,
                embedding float[\(config.embeddingDimension)]
            )
        """)

        // Chunk metadata table
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS chunk_metadata (
                chunk_id TEXT PRIMARY KEY,
                document_id TEXT NOT NULL,
                content TEXT NOT NULL,
                token_count INTEGER,
                section_title TEXT,
                heading_hierarchy TEXT,
                contains_code INTEGER DEFAULT 0,
                contains_table INTEGER DEFAULT 0,
                position_start INTEGER,
                position_end INTEGER,
                chunk_index INTEGER,
                total_chunks INTEGER,
                document_title TEXT,
                product TEXT,
                version TEXT,
                source_url TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Create index on document_id for faster lookups
        try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_chunk_document
            ON chunk_metadata(document_id)
        """)

        // Create index on product for filtering
        try await db.execute("""
            CREATE INDEX IF NOT EXISTS idx_chunk_product
            ON chunk_metadata(product)
        """)

        // Full-text search table for BM25
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts
            USING fts5(
                chunk_id,
                content,
                section_title,
                document_title,
                tokenize='porter unicode61'
            )
        """)

        // Documents table for tracking
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS documents (
                document_id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                source_url TEXT,
                product TEXT NOT NULL,
                version TEXT,
                content_hash TEXT,
                chunk_count INTEGER DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
    }

    // MARK: - Document Operations

    /// Check if a document already exists by content hash
    public func documentExists(contentHash: String) async throws -> Bool {
        guard let db = db else { throw VectorStoreError.notInitialized }

        let results = try await db.query(
            "SELECT 1 FROM documents WHERE content_hash = ? LIMIT 1",
            params: [contentHash]
        )
        return !results.isEmpty
    }

    /// Insert or update a document record
    public func upsertDocument(
        id: String,
        title: String,
        sourceURL: URL?,
        product: String,
        version: String?,
        contentHash: String,
        chunkCount: Int
    ) async throws {
        guard let db = db else { throw VectorStoreError.notInitialized }

        try await db.execute("""
            INSERT OR REPLACE INTO documents
            (document_id, title, source_url, product, version, content_hash, chunk_count, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
        """, params: [
            id,
            title,
            sourceURL?.absoluteString as Any,
            product,
            version as Any,
            contentHash,
            chunkCount
        ])
    }

    /// Delete a document and all its chunks
    public func deleteDocument(id: String) async throws {
        guard let db = db else { throw VectorStoreError.notInitialized }

        // Get all chunk IDs for this document
        let chunks = try await db.query(
            "SELECT chunk_id FROM chunk_metadata WHERE document_id = ?",
            params: [id]
        )

        // Delete from all tables
        for chunk in chunks {
            if let chunkId = chunk["chunk_id"] as? String {
                try await db.execute(
                    "DELETE FROM chunk_embeddings WHERE chunk_id = ?",
                    params: [chunkId]
                )
                try await db.execute(
                    "DELETE FROM chunk_fts WHERE chunk_id = ?",
                    params: [chunkId]
                )
            }
        }

        try await db.execute(
            "DELETE FROM chunk_metadata WHERE document_id = ?",
            params: [id]
        )

        try await db.execute(
            "DELETE FROM documents WHERE document_id = ?",
            params: [id]
        )
    }

    // MARK: - Chunk Operations

    /// Insert a chunk with its embedding
    public func insertChunk(
        id: String,
        documentId: String,
        content: String,
        tokenCount: Int,
        sectionTitle: String?,
        headingHierarchy: [String],
        containsCode: Bool,
        containsTable: Bool,
        positionStart: Int,
        positionEnd: Int,
        chunkIndex: Int,
        totalChunks: Int,
        documentTitle: String,
        product: String,
        version: String?,
        sourceURL: URL?,
        embedding: [Float]
    ) async throws {
        guard let db = db else { throw VectorStoreError.notInitialized }

        // Insert embedding
        try await db.execute(
            "INSERT INTO chunk_embeddings (chunk_id, embedding) VALUES (?, ?)",
            params: [id, embedding]
        )

        // Insert metadata
        try await db.execute("""
            INSERT INTO chunk_metadata
            (chunk_id, document_id, content, token_count, section_title, heading_hierarchy,
             contains_code, contains_table, position_start, position_end, chunk_index,
             total_chunks, document_title, product, version, source_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            id,
            documentId,
            content,
            tokenCount,
            sectionTitle as Any,
            headingHierarchy.joined(separator: " > "),
            containsCode ? 1 : 0,
            containsTable ? 1 : 0,
            positionStart,
            positionEnd,
            chunkIndex,
            totalChunks,
            documentTitle,
            product,
            version as Any,
            sourceURL?.absoluteString as Any
        ])

        // Insert into FTS
        try await db.execute(
            "INSERT INTO chunk_fts (chunk_id, content, section_title, document_title) VALUES (?, ?, ?, ?)",
            params: [id, content, sectionTitle ?? "", documentTitle]
        )
    }

    // MARK: - Search Operations

    /// Perform vector similarity search
    public func searchSimilar(
        embedding: [Float],
        limit: Int = 10,
        productFilter: String? = nil,
        versionFilter: String? = nil
    ) async throws -> [VectorSearchResult] {
        guard let db = db else { throw VectorStoreError.notInitialized }

        var query = """
            SELECT
                ce.chunk_id,
                ce.distance,
                cm.content,
                cm.section_title,
                cm.document_title,
                cm.product,
                cm.version,
                cm.source_url,
                cm.heading_hierarchy,
                cm.contains_code
            FROM chunk_embeddings ce
            JOIN chunk_metadata cm ON cm.chunk_id = ce.chunk_id
            WHERE ce.embedding MATCH ?
        """

        var params: [Any] = [embedding]

        if let product = productFilter {
            query += " AND cm.product = ?"
            params.append(product)
        }

        if let version = versionFilter {
            query += " AND cm.version = ?"
            params.append(version)
        }

        query += " ORDER BY ce.distance LIMIT ?"
        params.append(limit)

        let results = try await db.query(query, params: params)

        return results.compactMap { row -> VectorSearchResult? in
            guard let chunkId = row["chunk_id"] as? String,
                  let distance = row["distance"] as? Double,
                  let content = row["content"] as? String,
                  let documentTitle = row["document_title"] as? String,
                  let product = row["product"] as? String else {
                return nil
            }

            return VectorSearchResult(
                chunkId: chunkId,
                distance: Float(distance),
                content: content,
                sectionTitle: row["section_title"] as? String,
                documentTitle: documentTitle,
                product: product,
                version: row["version"] as? String,
                sourceURL: (row["source_url"] as? String).flatMap { URL(string: $0) },
                headingHierarchy: (row["heading_hierarchy"] as? String)?.components(separatedBy: " > ") ?? [],
                containsCode: (row["contains_code"] as? Int) == 1
            )
        }
    }

    /// Perform BM25 keyword search
    public func searchKeywords(
        query: String,
        limit: Int = 10,
        productFilter: String? = nil
    ) async throws -> [KeywordSearchResult] {
        guard let db = db else { throw VectorStoreError.notInitialized }

        var sql = """
            SELECT
                cf.chunk_id,
                bm25(chunk_fts) as score,
                snippet(chunk_fts, 1, '<mark>', '</mark>', '...', 32) as snippet,
                cm.content,
                cm.section_title,
                cm.document_title,
                cm.product,
                cm.version,
                cm.source_url
            FROM chunk_fts cf
            JOIN chunk_metadata cm ON cm.chunk_id = cf.chunk_id
            WHERE chunk_fts MATCH ?
        """

        var params: [Any] = [query]

        if let product = productFilter {
            sql += " AND cm.product = ?"
            params.append(product)
        }

        sql += " ORDER BY score LIMIT ?"
        params.append(limit)

        let results = try await db.query(sql, params: params)

        return results.compactMap { row -> KeywordSearchResult? in
            guard let chunkId = row["chunk_id"] as? String,
                  let score = row["score"] as? Double,
                  let content = row["content"] as? String,
                  let documentTitle = row["document_title"] as? String,
                  let product = row["product"] as? String else {
                return nil
            }

            return KeywordSearchResult(
                chunkId: chunkId,
                score: Float(-score),  // BM25 returns negative scores, lower is better
                content: content,
                snippet: row["snippet"] as? String ?? "",
                sectionTitle: row["section_title"] as? String,
                documentTitle: documentTitle,
                product: product,
                version: row["version"] as? String,
                sourceURL: (row["source_url"] as? String).flatMap { URL(string: $0) }
            )
        }
    }

    // MARK: - Statistics

    /// Get database statistics
    public func getStatistics() async throws -> VectorStoreStatistics {
        guard let db = db else { throw VectorStoreError.notInitialized }

        let docCount = try await db.query("SELECT COUNT(*) as count FROM documents")
        let chunkCount = try await db.query("SELECT COUNT(*) as count FROM chunk_metadata")
        let productStats = try await db.query("""
            SELECT product, COUNT(*) as count
            FROM chunk_metadata
            GROUP BY product
            ORDER BY count DESC
        """)

        var byProduct: [String: Int] = [:]
        for row in productStats {
            if let product = row["product"] as? String,
               let count = row["count"] as? Int {
                byProduct[product] = count
            }
        }

        return VectorStoreStatistics(
            totalDocuments: (docCount.first?["count"] as? Int) ?? 0,
            totalChunks: (chunkCount.first?["count"] as? Int) ?? 0,
            chunksByProduct: byProduct
        )
    }

    /// Clear all data
    public func clearAll() async throws {
        guard let db = db else { throw VectorStoreError.notInitialized }

        try await db.execute("DELETE FROM chunk_embeddings")
        try await db.execute("DELETE FROM chunk_fts")
        try await db.execute("DELETE FROM chunk_metadata")
        try await db.execute("DELETE FROM documents")
    }
}

// MARK: - Result Types

public struct VectorSearchResult: Sendable {
    public let chunkId: String
    public let distance: Float
    public let content: String
    public let sectionTitle: String?
    public let documentTitle: String
    public let product: String
    public let version: String?
    public let sourceURL: URL?
    public let headingHierarchy: [String]
    public let containsCode: Bool

    /// Similarity score (0-1, higher is more similar)
    public var similarityScore: Float {
        1.0 / (1.0 + distance)
    }
}

public struct KeywordSearchResult: Sendable {
    public let chunkId: String
    public let score: Float
    public let content: String
    public let snippet: String
    public let sectionTitle: String?
    public let documentTitle: String
    public let product: String
    public let version: String?
    public let sourceURL: URL?
}

public struct VectorStoreStatistics: Sendable {
    public let totalDocuments: Int
    public let totalChunks: Int
    public let chunksByProduct: [String: Int]
}

// MARK: - Errors

public enum VectorStoreError: Error, LocalizedError {
    case notInitialized
    case insertFailed(String)
    case searchFailed(String)
    case documentNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Vector store has not been initialized"
        case .insertFailed(let reason):
            return "Failed to insert into vector store: \(reason)"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        }
    }
}
