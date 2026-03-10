import Foundation

// MARK: - Query Expansion & Rewriting

/// Expands user queries to improve retrieval coverage
public actor QueryExpander {

    private let ollamaClient: Any  // OllamaAPIClient
    private let model: String

    public init(ollamaClient: Any, model: String = "llama3.2") {
        self.ollamaClient = ollamaClient
        self.model = model
    }

    /// Generate multiple query variations for better retrieval
    public func expandQuery(_ query: String) async throws -> [String] {
        var variations = [query]  // Always include original

        // 1. Generate synonyms and related terms
        let synonymPrompt = """
        Given this VMware documentation search query: "\(query)"

        Generate 3 alternative search queries that might find relevant documentation.
        Focus on:
        - VMware product synonyms (e.g., vSphere = ESXi + vCenter)
        - Technical term variations
        - Related concepts

        Return ONLY the queries, one per line, no numbering or explanation.
        """

        // In production, call LLM here
        // For now, use rule-based expansion
        variations.append(contentsOf: ruleBasedExpansion(query))

        return Array(Set(variations))  // Deduplicate
    }

    /// Rule-based query expansion for common VMware terms
    private func ruleBasedExpansion(_ query: String) -> [String] {
        var expansions: [String] = []
        let lower = query.lowercased()

        // Product expansions
        let productExpansions: [String: [String]] = [
            "vsphere": ["esxi", "vcenter", "vmotion", "ha", "drs"],
            "vcenter": ["vcsa", "vcenter server", "vcenter appliance"],
            "nsx": ["nsx-t", "nsx-v", "nsx data center", "network virtualization"],
            "vsan": ["vsan", "virtual san", "software-defined storage"],
            "tanzu": ["kubernetes", "tkg", "tkgs", "tanzu kubernetes"],
            "aria": ["vrops", "vrealize", "aria operations", "aria automation"],
            "vcf": ["cloud foundation", "vmware cloud foundation", "sddc"],
        ]

        for (term, related) in productExpansions {
            if lower.contains(term) {
                for relatedTerm in related {
                    let expanded = query.replacingOccurrences(
                        of: term,
                        with: relatedTerm,
                        options: .caseInsensitive
                    )
                    expansions.append(expanded)
                }
            }
        }

        // Action expansions
        let actionExpansions: [String: [String]] = [
            "install": ["deploy", "set up", "configure"],
            "configure": ["set up", "enable", "modify settings"],
            "troubleshoot": ["debug", "fix", "resolve", "error"],
            "upgrade": ["update", "migrate", "patch"],
            "backup": ["protect", "replicate", "disaster recovery"],
        ]

        for (action, alternatives) in actionExpansions {
            if lower.contains(action) {
                for alt in alternatives.prefix(2) {
                    let expanded = query.replacingOccurrences(
                        of: action,
                        with: alt,
                        options: .caseInsensitive
                    )
                    expansions.append(expanded)
                }
            }
        }

        return Array(expansions.prefix(5))  // Limit expansions
    }
}

// MARK: - Hypothetical Document Embeddings (HyDE)

/// Generates hypothetical answers to improve retrieval
public actor HyDEGenerator {

    private let ollamaClient: Any
    private let model: String

    public init(ollamaClient: Any, model: String = "llama3.2") {
        self.ollamaClient = ollamaClient
        self.model = model
    }

    /// Generate a hypothetical document that would answer the query
    public func generateHypotheticalDocument(_ query: String) async throws -> String {
        let prompt = """
        You are a VMware documentation writer. Write a brief, factual documentation excerpt
        that would perfectly answer this question:

        Question: \(query)

        Write 2-3 paragraphs of technical documentation that directly addresses this question.
        Use proper VMware terminology and be specific about procedures, settings, or concepts.
        Do not include phrases like "This documentation explains" - just write the content.
        """

        // In production, call LLM to generate hypothetical document
        // The embedding of this hypothetical doc often retrieves better than the query itself

        // Placeholder return - would be LLM generated
        return """
        VMware \(query) involves specific configuration steps and requirements.
        Refer to the official documentation for detailed procedures and best practices.
        """
    }
}

// MARK: - Cross-Encoder Reranker

/// Reranks retrieved chunks using cross-encoder scoring
public actor CrossEncoderReranker {

    public struct RerankedResult: Sendable {
        public let chunkId: String
        public let content: String
        public let originalScore: Float
        public let rerankedScore: Float
        public let documentTitle: String
        public let sourceURL: URL?
        public let product: String
    }

    private let ollamaClient: Any
    private let model: String

    public init(ollamaClient: Any, model: String = "llama3.2") {
        self.ollamaClient = ollamaClient
        self.model = model
    }

    /// Rerank results using LLM-based relevance scoring
    public func rerank(
        query: String,
        results: [HybridRetriever.RankedResult],
        topK: Int = 5
    ) async throws -> [RerankedResult] {
        // For each result, score relevance with LLM
        var rerankedResults: [RerankedResult] = []

        for result in results.prefix(topK * 2) {  // Score more than we need
            let relevanceScore = await scoreRelevance(query: query, content: result.content)

            rerankedResults.append(RerankedResult(
                chunkId: result.chunkId,
                content: result.content,
                originalScore: result.combinedScore,
                rerankedScore: relevanceScore,
                documentTitle: result.documentTitle,
                sourceURL: result.sourceURL,
                product: result.product
            ))
        }

        // Sort by reranked score
        return rerankedResults
            .sorted { $0.rerankedScore > $1.rerankedScore }
            .prefix(topK)
            .map { $0 }
    }

    /// Score relevance of content to query (0-1)
    private func scoreRelevance(query: String, content: String) async -> Float {
        // In production, use LLM to score relevance
        // For now, use simple heuristic
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let contentWords = Set(content.lowercased().split(separator: " ").map(String.init))

        let overlap = queryWords.intersection(contentWords).count
        let score = Float(overlap) / Float(max(queryWords.count, 1))

        return min(1.0, score * 2)  // Scale up
    }
}

// MARK: - Semantic Chunker

/// Advanced chunker that uses embeddings to find semantic boundaries
public actor SemanticChunker {

    public struct SemanticChunk: Sendable, Identifiable {
        public let id: UUID
        public let content: String
        public let startOffset: Int
        public let endOffset: Int
        public let semanticCoherence: Float
        public let topics: [String]
    }

    private let embeddingGenerator: Any  // Would be EmbeddingGenerator

    public init(embeddingGenerator: Any) {
        self.embeddingGenerator = embeddingGenerator
    }

    /// Chunk text based on semantic boundaries
    public func chunk(
        text: String,
        targetSize: Int = 512,
        threshold: Float = 0.5
    ) async throws -> [SemanticChunk] {
        // 1. Split into sentences
        let sentences = splitIntoSentences(text)

        // 2. Generate embeddings for each sentence
        // In production, batch generate embeddings

        // 3. Find semantic boundaries (where similarity drops)
        var chunks: [SemanticChunk] = []
        var currentChunk: [String] = []
        var currentOffset = 0

        for (index, sentence) in sentences.enumerated() {
            currentChunk.append(sentence)

            let estimatedTokens = currentChunk.joined(separator: " ").count / 4

            // Check if we should start a new chunk
            if estimatedTokens >= targetSize || index == sentences.count - 1 {
                let content = currentChunk.joined(separator: " ")
                chunks.append(SemanticChunk(
                    id: UUID(),
                    content: content,
                    startOffset: currentOffset,
                    endOffset: currentOffset + content.count,
                    semanticCoherence: 0.8,  // Would be calculated from embeddings
                    topics: extractTopics(from: content)
                ))
                currentOffset += content.count + 1
                currentChunk = []
            }
        }

        return chunks
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if sentenceEnders.contains(char.unicodeScalars.first!) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return sentences
    }

    private func extractTopics(from text: String) -> [String] {
        // Simple keyword extraction for topics
        let vmwareTerms = [
            "vsphere", "vcenter", "esxi", "vsan", "nsx", "tanzu", "aria",
            "cluster", "datastore", "network", "storage", "compute",
            "vm", "virtual machine", "host", "migration", "backup",
            "ha", "drs", "vmotion", "snapshot", "template"
        ]

        let lower = text.lowercased()
        return vmwareTerms.filter { lower.contains($0) }
    }
}

// MARK: - Multi-Hop Retrieval

/// Performs multi-hop retrieval for complex queries
public actor MultiHopRetriever {

    public struct MultiHopResult: Sendable {
        public let hops: [[HybridRetriever.RankedResult]]
        public let reasoning: String
        public let finalAnswer: String?
    }

    private let retriever: HybridRetriever

    public init(retriever: HybridRetriever) {
        self.retriever = retriever
    }

    /// Decompose complex query and retrieve in multiple hops
    public func retrieve(
        complexQuery: String,
        maxHops: Int = 3
    ) async throws -> MultiHopResult {
        // 1. Decompose query into sub-questions
        let subQueries = decomposeQuery(complexQuery)

        var allHops: [[HybridRetriever.RankedResult]] = []
        var context = ""

        // 2. Retrieve for each sub-query, building context
        for subQuery in subQueries.prefix(maxHops) {
            let processedQuery = await retriever.processQuery(subQuery)

            // Would perform actual retrieval here
            // let results = try await retriever.retrieve(...)

            // For now, return empty results
            allHops.append([])
        }

        return MultiHopResult(
            hops: allHops,
            reasoning: "Decomposed into \(subQueries.count) sub-queries",
            finalAnswer: nil
        )
    }

    private func decomposeQuery(_ query: String) -> [String] {
        // Simple decomposition based on conjunctions
        let lower = query.lowercased()

        if lower.contains(" and ") {
            return query.components(separatedBy: " and ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if lower.contains(" then ") {
            return query.components(separatedBy: " then ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        // Check for multi-part questions
        if lower.contains("how") && lower.contains("why") {
            // Split into how and why parts
            return [query]  // Simplified
        }

        return [query]
    }
}

// MARK: - Answer Grounding & Verification

/// Verifies that generated answers are grounded in retrieved context
public actor AnswerGrounder {

    public struct GroundingResult: Sendable {
        public let isGrounded: Bool
        public let groundedClaims: [String]
        public let ungroundedClaims: [String]
        public let confidence: Float
        public let suggestedRevision: String?
    }

    /// Verify that an answer is supported by the context
    public func verifyGrounding(
        answer: String,
        context: String,
        sources: [ContextAssembler.SourceReference]
    ) async -> GroundingResult {
        // Extract claims from answer
        let claims = extractClaims(from: answer)

        var grounded: [String] = []
        var ungrounded: [String] = []

        for claim in claims {
            if isClaimSupported(claim, by: context) {
                grounded.append(claim)
            } else {
                ungrounded.append(claim)
            }
        }

        let confidence = Float(grounded.count) / Float(max(claims.count, 1))

        return GroundingResult(
            isGrounded: ungrounded.isEmpty,
            groundedClaims: grounded,
            ungroundedClaims: ungrounded,
            confidence: confidence,
            suggestedRevision: ungrounded.isEmpty ? nil : "Some claims may need verification"
        )
    }

    private func extractClaims(from text: String) -> [String] {
        // Simple: split by sentences
        return text.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isClaimSupported(_ claim: String, by context: String) -> Bool {
        // Simple word overlap check
        let claimWords = Set(claim.lowercased().split(separator: " ").map(String.init))
        let contextLower = context.lowercased()

        let matches = claimWords.filter { contextLower.contains($0) }.count
        return Float(matches) / Float(max(claimWords.count, 1)) > 0.5
    }
}

// MARK: - Contextual Compression

/// Compresses retrieved context to fit more relevant information
public actor ContextCompressor {

    /// Compress context by removing redundancy and low-relevance content
    public func compress(
        chunks: [HybridRetriever.RankedResult],
        query: String,
        maxTokens: Int = 4000
    ) async -> String {
        var compressed: [String] = []
        var totalTokens = 0

        for chunk in chunks {
            // Extract most relevant sentences from each chunk
            let relevantContent = extractRelevantContent(
                from: chunk.content,
                query: query
            )

            let tokens = relevantContent.count / 4
            if totalTokens + tokens <= maxTokens {
                compressed.append(relevantContent)
                totalTokens += tokens
            } else {
                // Truncate this chunk to fit
                let remaining = maxTokens - totalTokens
                if remaining > 100 {
                    let truncated = String(relevantContent.prefix(remaining * 4))
                    compressed.append(truncated + "...")
                }
                break
            }
        }

        return compressed.joined(separator: "\n\n")
    }

    private func extractRelevantContent(from content: String, query: String) -> String {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let sentences = content.components(separatedBy: ". ")

        // Score sentences by relevance
        let scored = sentences.map { sentence -> (String, Int) in
            let sentenceWords = Set(sentence.lowercased().split(separator: " ").map(String.init))
            let overlap = queryWords.intersection(sentenceWords).count
            return (sentence, overlap)
        }

        // Keep top sentences
        let topSentences = scored
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }

        return topSentences.joined(separator: ". ")
    }
}
