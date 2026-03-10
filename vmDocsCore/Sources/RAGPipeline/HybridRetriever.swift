import Foundation

/// Hybrid retriever combining vector similarity and BM25 keyword search
/// Uses Reciprocal Rank Fusion (RRF) for result merging
public actor HybridRetriever {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let vectorWeight: Float
        public let keywordWeight: Float
        public let topK: Int
        public let rrfConstant: Float
        public let minScore: Float

        public init(
            vectorWeight: Float = 0.7,
            keywordWeight: Float = 0.3,
            topK: Int = 10,
            rrfConstant: Float = 60,
            minScore: Float = 0.01
        ) {
            self.vectorWeight = vectorWeight
            self.keywordWeight = keywordWeight
            self.topK = topK
            self.rrfConstant = rrfConstant
            self.minScore = minScore
        }
    }

    // MARK: - Result Types

    public struct RetrievalResult: Sendable {
        public let rankedChunks: [RankedResult]
        public let vectorMatchCount: Int
        public let keywordMatchCount: Int
        public let retrievalTimeMs: Int

        public init(
            rankedChunks: [RankedResult],
            vectorMatchCount: Int,
            keywordMatchCount: Int,
            retrievalTimeMs: Int
        ) {
            self.rankedChunks = rankedChunks
            self.vectorMatchCount = vectorMatchCount
            self.keywordMatchCount = keywordMatchCount
            self.retrievalTimeMs = retrievalTimeMs
        }
    }

    public struct RankedResult: Sendable, Identifiable {
        public let id: String
        public let chunkId: String
        public let content: String
        public let combinedScore: Float
        public let vectorScore: Float
        public let keywordScore: Float
        public let documentTitle: String
        public let sectionTitle: String?
        public let product: String
        public let version: String?
        public let sourceURL: URL?
        public let headingHierarchy: [String]
        public let containsCode: Bool

        public init(
            chunkId: String,
            content: String,
            combinedScore: Float,
            vectorScore: Float,
            keywordScore: Float,
            documentTitle: String,
            sectionTitle: String?,
            product: String,
            version: String?,
            sourceURL: URL?,
            headingHierarchy: [String],
            containsCode: Bool
        ) {
            self.id = chunkId
            self.chunkId = chunkId
            self.content = content
            self.combinedScore = combinedScore
            self.vectorScore = vectorScore
            self.keywordScore = keywordScore
            self.documentTitle = documentTitle
            self.sectionTitle = sectionTitle
            self.product = product
            self.version = version
            self.sourceURL = sourceURL
            self.headingHierarchy = headingHierarchy
            self.containsCode = containsCode
        }
    }

    public struct ProcessedQuery: Sendable {
        public let originalQuery: String
        public let keywords: [String]
        public let filters: QueryFilters

        public init(
            originalQuery: String,
            keywords: [String] = [],
            filters: QueryFilters = QueryFilters()
        ) {
            self.originalQuery = originalQuery
            self.keywords = keywords
            self.filters = filters
        }
    }

    public struct QueryFilters: Sendable {
        public var products: [String]
        public var versions: [String]

        public init(products: [String] = [], versions: [String] = []) {
            self.products = products
            self.versions = versions
        }
    }

    // MARK: - Properties

    private let config: Config

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Query Processing

    /// Process a natural language query to extract keywords and filters
    public func processQuery(_ query: String) -> ProcessedQuery {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract product mentions
        var products: [String] = []
        let productPatterns: [(pattern: String, product: String)] = [
            ("vsphere", "vSphere"),
            ("vcenter", "vCenter"),
            ("esxi", "ESXi"),
            ("vsan", "vSAN"),
            ("nsx", "NSX"),
            ("tanzu", "Tanzu"),
            ("aria", "Aria"),
            ("horizon", "Horizon"),
            ("workstation", "Workstation"),
            ("fusion", "Fusion"),
            ("hcx", "HCX"),
            ("cloud foundation", "VCF"),
            ("vcf", "VCF"),
            ("cloud director", "CloudDirector"),
            ("vcd", "CloudDirector")
        ]

        for (pattern, product) in productPatterns {
            if normalizedQuery.contains(pattern) {
                products.append(product)
            }
        }

        // Extract version mentions
        var versions: [String] = []
        let versionPattern = #"\b(\d+\.\d+(?:\.\d+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: versionPattern) {
            let range = NSRange(normalizedQuery.startIndex..., in: normalizedQuery)
            let matches = regex.matches(in: normalizedQuery, range: range)
            for match in matches {
                if let versionRange = Range(match.range(at: 1), in: normalizedQuery) {
                    versions.append(String(normalizedQuery[versionRange]))
                }
            }
        }

        // Extract keywords (remove stop words)
        let stopWords: Set<String> = [
            "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "shall", "can", "need", "dare",
            "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
            "from", "as", "into", "through", "during", "before", "after",
            "above", "below", "between", "under", "again", "further", "then",
            "once", "here", "there", "when", "where", "why", "how", "all",
            "each", "few", "more", "most", "other", "some", "such", "no",
            "nor", "not", "only", "own", "same", "so", "than", "too", "very",
            "just", "and", "but", "if", "or", "because", "until", "while",
            "what", "which", "who", "whom", "this", "that", "these", "those",
            "i", "me", "my", "myself", "we", "our", "ours", "ourselves", "you",
            "your", "yours", "yourself", "yourselves", "he", "him", "his",
            "himself", "she", "her", "hers", "herself", "it", "its", "itself",
            "they", "them", "their", "theirs", "themselves"
        ]

        let words = normalizedQuery.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }

        return ProcessedQuery(
            originalQuery: query,
            keywords: words,
            filters: QueryFilters(products: products, versions: versions)
        )
    }

    // MARK: - Retrieval

    /// Perform hybrid retrieval combining vector and keyword search
    public func retrieve(
        query: ProcessedQuery,
        queryEmbedding: [Float],
        vectorSearch: ([Float], Int, String?, String?) async throws -> [VectorSearchResult],
        keywordSearch: (String, Int, String?) async throws -> [KeywordSearchResult]
    ) async throws -> RetrievalResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Determine filters
        let productFilter = query.filters.products.first
        let versionFilter = query.filters.versions.first

        // Parallel retrieval
        async let vectorResults = vectorSearch(
            queryEmbedding,
            config.topK * 2,
            productFilter,
            versionFilter
        )

        let keywordQuery = query.keywords.isEmpty
            ? query.originalQuery
            : query.keywords.joined(separator: " OR ")

        async let keywordResults = keywordSearch(
            keywordQuery,
            config.topK * 2,
            productFilter
        )

        let (vectors, keywords) = try await (vectorResults, keywordResults)

        // Apply Reciprocal Rank Fusion
        let fused = reciprocalRankFusion(
            vectorResults: vectors,
            keywordResults: keywords
        )

        let endTime = CFAbsoluteTimeGetCurrent()

        return RetrievalResult(
            rankedChunks: Array(fused.prefix(config.topK)),
            vectorMatchCount: vectors.count,
            keywordMatchCount: keywords.count,
            retrievalTimeMs: Int((endTime - startTime) * 1000)
        )
    }

    // MARK: - Reciprocal Rank Fusion

    private func reciprocalRankFusion(
        vectorResults: [VectorSearchResult],
        keywordResults: [KeywordSearchResult]
    ) -> [RankedResult] {
        // Build score map
        var scoreMap: [String: (
            vectorRank: Int?,
            keywordRank: Int?,
            vectorResult: VectorSearchResult?,
            keywordResult: KeywordSearchResult?
        )] = [:]

        // Process vector results
        for (rank, result) in vectorResults.enumerated() {
            scoreMap[result.chunkId] = (rank + 1, nil, result, nil)
        }

        // Process keyword results
        for (rank, result) in keywordResults.enumerated() {
            if var existing = scoreMap[result.chunkId] {
                existing.keywordRank = rank + 1
                existing.keywordResult = result
                scoreMap[result.chunkId] = existing
            } else {
                scoreMap[result.chunkId] = (nil, rank + 1, nil, result)
            }
        }

        // Calculate RRF scores
        var results: [RankedResult] = []

        for (chunkId, data) in scoreMap {
            let vectorRRF: Float = data.vectorRank.map { 1.0 / (config.rrfConstant + Float($0)) } ?? 0
            let keywordRRF: Float = data.keywordRank.map { 1.0 / (config.rrfConstant + Float($0)) } ?? 0

            let combinedScore = config.vectorWeight * vectorRRF + config.keywordWeight * keywordRRF

            guard combinedScore >= config.minScore else { continue }

            // Get content from whichever result we have
            let content = data.vectorResult?.content ?? data.keywordResult?.content ?? ""
            let documentTitle = data.vectorResult?.documentTitle ?? data.keywordResult?.documentTitle ?? ""
            let sectionTitle = data.vectorResult?.sectionTitle ?? data.keywordResult?.sectionTitle
            let product = data.vectorResult?.product ?? data.keywordResult?.product ?? "Unknown"
            let version = data.vectorResult?.version ?? data.keywordResult?.version
            let sourceURL = data.vectorResult?.sourceURL ?? data.keywordResult?.sourceURL
            let headingHierarchy = data.vectorResult?.headingHierarchy ?? []
            let containsCode = data.vectorResult?.containsCode ?? false

            results.append(RankedResult(
                chunkId: chunkId,
                content: content,
                combinedScore: combinedScore,
                vectorScore: vectorRRF,
                keywordScore: keywordRRF,
                documentTitle: documentTitle,
                sectionTitle: sectionTitle,
                product: product,
                version: version,
                sourceURL: sourceURL,
                headingHierarchy: headingHierarchy,
                containsCode: containsCode
            ))
        }

        // Sort by combined score descending
        return results.sorted { $0.combinedScore > $1.combinedScore }
    }
}

// VectorSearchResult and KeywordSearchResult are defined in VectorStoreManager.swift
