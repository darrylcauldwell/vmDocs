import Foundation

// MARK: - Multi-Level Cache Manager

/// High-performance caching system for RAG operations
public actor CacheManager {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let queryCache: CacheConfig
        public let embeddingCache: CacheConfig
        public let resultCache: CacheConfig
        public let persistToDisk: Bool

        public init(
            queryCache: CacheConfig = CacheConfig(maxItems: 1000, ttlSeconds: 3600),
            embeddingCache: CacheConfig = CacheConfig(maxItems: 10000, ttlSeconds: 86400),
            resultCache: CacheConfig = CacheConfig(maxItems: 500, ttlSeconds: 1800),
            persistToDisk: Bool = true
        ) {
            self.queryCache = queryCache
            self.embeddingCache = embeddingCache
            self.resultCache = resultCache
            self.persistToDisk = persistToDisk
        }
    }

    public struct CacheConfig: Sendable {
        public let maxItems: Int
        public let ttlSeconds: Int

        public init(maxItems: Int, ttlSeconds: Int) {
            self.maxItems = maxItems
            self.ttlSeconds = ttlSeconds
        }
    }

    // MARK: - Cache Entry

    private struct CacheEntry<T: Sendable>: Sendable {
        let value: T
        let createdAt: Date
        let ttlSeconds: Int
        var accessCount: Int

        var isExpired: Bool {
            Date().timeIntervalSince(createdAt) > Double(ttlSeconds)
        }
    }

    // MARK: - Properties

    private let config: Config
    private var queryCache: [String: CacheEntry<[String]>] = [:]  // query -> expanded queries
    private var embeddingCache: [String: CacheEntry<[Float]>] = [:]  // text hash -> embedding
    private var resultCache: [String: CacheEntry<Data>] = [:]  // query hash -> serialized results

    private var cacheStats = CacheStats()

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config

        // Load persisted cache if enabled
        if config.persistToDisk {
            Task {
                await loadPersistedCache()
            }
        }
    }

    // MARK: - Query Cache

    /// Get cached query expansions
    public func getCachedQueryExpansions(_ query: String) -> [String]? {
        let key = query.lowercased()

        guard let entry = queryCache[key], !entry.isExpired else {
            cacheStats.queryMisses += 1
            return nil
        }

        queryCache[key]?.accessCount += 1
        cacheStats.queryHits += 1
        return entry.value
    }

    /// Cache query expansions
    public func cacheQueryExpansions(_ query: String, expansions: [String]) {
        let key = query.lowercased()
        queryCache[key] = CacheEntry(
            value: expansions,
            createdAt: Date(),
            ttlSeconds: config.queryCache.ttlSeconds,
            accessCount: 1
        )
        evictIfNeeded(cache: &queryCache, maxItems: config.queryCache.maxItems)
    }

    // MARK: - Embedding Cache

    /// Get cached embedding for text
    public func getCachedEmbedding(_ text: String) -> [Float]? {
        let key = hashText(text)

        guard let entry = embeddingCache[key], !entry.isExpired else {
            cacheStats.embeddingMisses += 1
            return nil
        }

        embeddingCache[key]?.accessCount += 1
        cacheStats.embeddingHits += 1
        return entry.value
    }

    /// Cache embedding for text
    public func cacheEmbedding(_ text: String, embedding: [Float]) {
        let key = hashText(text)
        embeddingCache[key] = CacheEntry(
            value: embedding,
            createdAt: Date(),
            ttlSeconds: config.embeddingCache.ttlSeconds,
            accessCount: 1
        )
        evictIfNeeded(cache: &embeddingCache, maxItems: config.embeddingCache.maxItems)
    }

    /// Batch cache embeddings
    public func cacheEmbeddingsBatch(_ textEmbeddingPairs: [(String, [Float])]) {
        for (text, embedding) in textEmbeddingPairs {
            cacheEmbedding(text, embedding: embedding)
        }
    }

    // MARK: - Result Cache

    /// Get cached search results
    public func getCachedResults(_ query: String, filters: [String: String]) -> Data? {
        let key = hashQuery(query, filters: filters)

        guard let entry = resultCache[key], !entry.isExpired else {
            cacheStats.resultMisses += 1
            return nil
        }

        resultCache[key]?.accessCount += 1
        cacheStats.resultHits += 1
        return entry.value
    }

    /// Cache search results
    public func cacheResults(_ query: String, filters: [String: String], results: Data) {
        let key = hashQuery(query, filters: filters)
        resultCache[key] = CacheEntry(
            value: results,
            createdAt: Date(),
            ttlSeconds: config.resultCache.ttlSeconds,
            accessCount: 1
        )
        evictIfNeeded(cache: &resultCache, maxItems: config.resultCache.maxItems)
    }

    // MARK: - Cache Statistics

    public struct CacheStats: Sendable {
        public var queryHits: Int = 0
        public var queryMisses: Int = 0
        public var embeddingHits: Int = 0
        public var embeddingMisses: Int = 0
        public var resultHits: Int = 0
        public var resultMisses: Int = 0

        public var queryHitRate: Double {
            let total = queryHits + queryMisses
            return total > 0 ? Double(queryHits) / Double(total) : 0
        }

        public var embeddingHitRate: Double {
            let total = embeddingHits + embeddingMisses
            return total > 0 ? Double(embeddingHits) / Double(total) : 0
        }

        public var resultHitRate: Double {
            let total = resultHits + resultMisses
            return total > 0 ? Double(resultHits) / Double(total) : 0
        }
    }

    public func getStats() -> CacheStats {
        cacheStats
    }

    /// Clear all caches
    public func clearAll() {
        queryCache.removeAll()
        embeddingCache.removeAll()
        resultCache.removeAll()
        cacheStats = CacheStats()
    }

    /// Clear expired entries
    public func evictExpired() {
        queryCache = queryCache.filter { !$0.value.isExpired }
        embeddingCache = embeddingCache.filter { !$0.value.isExpired }
        resultCache = resultCache.filter { !$0.value.isExpired }
    }

    // MARK: - Private Helpers

    private func hashText(_ text: String) -> String {
        // Simple hash for cache key
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 5381
        for char in normalized.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(hash, radix: 16)
    }

    private func hashQuery(_ query: String, filters: [String: String]) -> String {
        let filterString = filters.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        return hashText("\(query)|\(filterString)")
    }

    private func evictIfNeeded<T>(cache: inout [String: CacheEntry<T>], maxItems: Int) {
        guard cache.count > maxItems else { return }

        // LRU eviction - remove least accessed items
        let sortedKeys = cache.sorted { $0.value.accessCount < $1.value.accessCount }
            .prefix(cache.count - maxItems)
            .map { $0.key }

        for key in sortedKeys {
            cache.removeValue(forKey: key)
        }
    }

    // MARK: - Persistence

    private func loadPersistedCache() async {
        // Load from disk if available
        let cacheDir = getCacheDirectory()

        // Load embedding cache (most valuable to persist)
        let embeddingPath = cacheDir.appendingPathComponent("embeddings.cache")
        if let data = try? Data(contentsOf: embeddingPath),
           let loaded = try? JSONDecoder().decode([String: [Float]].self, from: data) {
            for (key, value) in loaded {
                embeddingCache[key] = CacheEntry(
                    value: value,
                    createdAt: Date(),
                    ttlSeconds: config.embeddingCache.ttlSeconds,
                    accessCount: 0
                )
            }
        }
    }

    public func persistCache() async {
        guard config.persistToDisk else { return }

        let cacheDir = getCacheDirectory()
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // Persist embedding cache
        let embeddingPath = cacheDir.appendingPathComponent("embeddings.cache")
        let embeddingData = embeddingCache.mapValues { $0.value }
        if let data = try? JSONEncoder().encode(embeddingData) {
            try? data.write(to: embeddingPath)
        }
    }

    private func getCacheDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("vmDocs")
    }
}

// MARK: - Batch Processor

/// Processes embeddings and indexing in optimized batches
public actor BatchProcessor {

    public struct BatchConfig: Sendable {
        public let batchSize: Int
        public let maxConcurrent: Int
        public let delayBetweenBatches: TimeInterval

        public init(
            batchSize: Int = 32,
            maxConcurrent: Int = 4,
            delayBetweenBatches: TimeInterval = 0.1
        ) {
            self.batchSize = batchSize
            self.maxConcurrent = maxConcurrent
            self.delayBetweenBatches = delayBetweenBatches
        }
    }

    public struct BatchProgress: Sendable {
        public let processed: Int
        public let total: Int
        public let currentBatch: Int
        public let totalBatches: Int
        public let estimatedRemainingSeconds: Int

        public var progress: Double {
            total > 0 ? Double(processed) / Double(total) : 0
        }
    }

    private let config: BatchConfig
    private var isCancelled = false

    public init(config: BatchConfig = BatchConfig()) {
        self.config = config
    }

    /// Process items in optimized batches
    public func processBatches<T: Sendable, R: Sendable>(
        items: [T],
        processor: @escaping @Sendable (T) async throws -> R,
        progressHandler: @Sendable (BatchProgress) -> Void
    ) async throws -> [R] {
        isCancelled = false
        var results: [R] = []
        results.reserveCapacity(items.count)

        let batches = items.chunked(into: config.batchSize)
        let totalBatches = batches.count
        var processed = 0
        let startTime = Date()

        for (batchIndex, batch) in batches.enumerated() {
            guard !isCancelled else { break }

            // Process batch concurrently
            let batchResults = try await withThrowingTaskGroup(of: R.self) { group in
                for item in batch {
                    group.addTask {
                        try await processor(item)
                    }
                }

                var batchResults: [R] = []
                for try await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }

            results.append(contentsOf: batchResults)
            processed += batch.count

            // Calculate ETA
            let elapsed = Date().timeIntervalSince(startTime)
            let rate = Double(processed) / elapsed
            let remaining = Double(items.count - processed) / rate

            progressHandler(BatchProgress(
                processed: processed,
                total: items.count,
                currentBatch: batchIndex + 1,
                totalBatches: totalBatches,
                estimatedRemainingSeconds: Int(remaining)
            ))

            // Delay between batches to prevent overload
            if batchIndex < batches.count - 1 {
                try await Task.sleep(nanoseconds: UInt64(config.delayBetweenBatches * 1_000_000_000))
            }
        }

        return results
    }

    /// Cancel ongoing batch processing
    public func cancel() {
        isCancelled = true
    }
}

// MARK: - Incremental Indexer

/// Handles incremental updates to the document index
public actor IncrementalIndexer {

    public struct IndexDelta: Sendable {
        public let newDocuments: [URL]
        public let modifiedDocuments: [URL]
        public let deletedDocumentIds: [String]
        public let unchangedCount: Int

        public var hasChanges: Bool {
            !newDocuments.isEmpty || !modifiedDocuments.isEmpty || !deletedDocumentIds.isEmpty
        }
    }

    public struct DocumentFingerprint: Codable, Sendable {
        public let id: String
        public let url: String
        public let contentHash: String
        public let lastModified: Date
        public let size: Int
    }

    private var fingerprints: [String: DocumentFingerprint] = [:]
    private let persistPath: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        persistPath = appSupport.appendingPathComponent("vmDocs/fingerprints.json")
        Task {
            await loadFingerprints()
        }
    }

    /// Calculate what has changed since last index
    public func calculateDelta(scannedDocuments: [(url: URL, contentHash: String, lastModified: Date, size: Int)]) -> IndexDelta {
        var newDocs: [URL] = []
        var modifiedDocs: [URL] = []
        var seenIds: Set<String> = []

        for doc in scannedDocuments {
            let id = doc.url.absoluteString

            seenIds.insert(id)

            if let existing = fingerprints[id] {
                // Check if modified
                if existing.contentHash != doc.contentHash ||
                   existing.lastModified != doc.lastModified ||
                   existing.size != doc.size {
                    modifiedDocs.append(doc.url)
                }
            } else {
                // New document
                newDocs.append(doc.url)
            }
        }

        // Find deleted documents
        let deletedIds = fingerprints.keys.filter { !seenIds.contains($0) }

        return IndexDelta(
            newDocuments: newDocs,
            modifiedDocuments: modifiedDocs,
            deletedDocumentIds: Array(deletedIds),
            unchangedCount: scannedDocuments.count - newDocs.count - modifiedDocs.count
        )
    }

    /// Update fingerprints after indexing
    public func updateFingerprint(for url: URL, contentHash: String, lastModified: Date, size: Int) {
        let id = url.absoluteString
        fingerprints[id] = DocumentFingerprint(
            id: id,
            url: url.absoluteString,
            contentHash: contentHash,
            lastModified: lastModified,
            size: size
        )
    }

    /// Remove fingerprint for deleted document
    public func removeFingerprint(id: String) {
        fingerprints.removeValue(forKey: id)
    }

    /// Persist fingerprints to disk
    public func saveFingerprints() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(Array(fingerprints.values)) {
            try? FileManager.default.createDirectory(
                at: persistPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: persistPath)
        }
    }

    private func loadFingerprints() {
        guard let data = try? Data(contentsOf: persistPath) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let loaded = try? decoder.decode([DocumentFingerprint].self, from: data) {
            fingerprints = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
