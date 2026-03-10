import Foundation

/// Assembles retrieved chunks into context for LLM prompts
public final class ContextAssembler: Sendable {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let maxContextTokens: Int
        public let maxChunksPerSource: Int
        public let includeMetadata: Bool
        public let deduplicateContent: Bool

        public init(
            maxContextTokens: Int = 4000,
            maxChunksPerSource: Int = 3,
            includeMetadata: Bool = true,
            deduplicateContent: Bool = true
        ) {
            self.maxContextTokens = maxContextTokens
            self.maxChunksPerSource = maxChunksPerSource
            self.includeMetadata = includeMetadata
            self.deduplicateContent = deduplicateContent
        }
    }

    // MARK: - Result Types

    public struct AssembledContext: Sendable {
        public let contextText: String
        public let sources: [SourceReference]
        public let tokenCount: Int
        public let truncated: Bool
        public let chunksUsed: Int
        public let chunksAvailable: Int

        public init(
            contextText: String,
            sources: [SourceReference],
            tokenCount: Int,
            truncated: Bool,
            chunksUsed: Int,
            chunksAvailable: Int
        ) {
            self.contextText = contextText
            self.sources = sources
            self.tokenCount = tokenCount
            self.truncated = truncated
            self.chunksUsed = chunksUsed
            self.chunksAvailable = chunksAvailable
        }
    }

    public struct SourceReference: Sendable, Identifiable {
        public let id: UUID
        public let referenceNumber: Int
        public let title: String
        public let product: String
        public let version: String?
        public let url: URL?
        public let sectionTitle: String?
        public let relevanceScore: Float

        public init(
            referenceNumber: Int,
            title: String,
            product: String,
            version: String?,
            url: URL?,
            sectionTitle: String?,
            relevanceScore: Float
        ) {
            self.id = UUID()
            self.referenceNumber = referenceNumber
            self.title = title
            self.product = product
            self.version = version
            self.url = url
            self.sectionTitle = sectionTitle
            self.relevanceScore = relevanceScore
        }
    }

    // MARK: - Properties

    private let config: Config

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Assembly

    /// Assemble ranked chunks into a context string with source references
    public func assemble(
        rankedChunks: [HybridRetriever.RankedResult]
    ) -> AssembledContext {
        var contextParts: [String] = []
        var sources: [SourceReference] = []
        var totalTokens = 0
        var truncated = false
        var seenContent: Set<String> = []
        var chunksUsed = 0

        // Group chunks by document to limit per-source
        var documentChunkCounts: [String: Int] = [:]

        for chunk in rankedChunks {
            // Check per-document limit
            let docKey = chunk.documentTitle
            let currentCount = documentChunkCounts[docKey] ?? 0
            if currentCount >= config.maxChunksPerSource {
                continue
            }

            // Deduplicate if enabled
            if config.deduplicateContent {
                let contentHash = simpleHash(chunk.content)
                if seenContent.contains(contentHash) {
                    continue
                }
                seenContent.insert(contentHash)
            }

            // Format chunk
            let formattedChunk = formatChunk(chunk, referenceNumber: sources.count + 1)
            let chunkTokens = estimateTokens(formattedChunk)

            // Check token limit
            if totalTokens + chunkTokens > config.maxContextTokens {
                truncated = true
                break
            }

            contextParts.append(formattedChunk)
            totalTokens += chunkTokens
            chunksUsed += 1
            documentChunkCounts[docKey] = currentCount + 1

            // Add source reference
            sources.append(SourceReference(
                referenceNumber: sources.count + 1,
                title: chunk.documentTitle,
                product: chunk.product,
                version: chunk.version,
                url: chunk.sourceURL,
                sectionTitle: chunk.sectionTitle,
                relevanceScore: chunk.combinedScore
            ))
        }

        let contextText = contextParts.joined(separator: "\n\n---\n\n")

        return AssembledContext(
            contextText: contextText,
            sources: sources,
            tokenCount: totalTokens,
            truncated: truncated,
            chunksUsed: chunksUsed,
            chunksAvailable: rankedChunks.count
        )
    }

    // MARK: - Formatting

    private func formatChunk(
        _ chunk: HybridRetriever.RankedResult,
        referenceNumber: Int
    ) -> String {
        var parts: [String] = []

        // Header with source reference
        var header = "[Source \(referenceNumber)]"

        if config.includeMetadata {
            header += " \(chunk.product)"
            if let version = chunk.version {
                header += " \(version)"
            }
            if let section = chunk.sectionTitle {
                header += " - \(section)"
            }
        }

        parts.append(header)

        // Content
        parts.append(chunk.content.trimmingCharacters(in: .whitespacesAndNewlines))

        return parts.joined(separator: "\n")
    }

    private func simpleHash(_ text: String) -> String {
        // Simple hash for deduplication
        let normalized = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(20)
            .joined(separator: " ")
        return normalized
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        max(1, text.count / 4)
    }
}

/// Builds prompts for RAG queries
public final class PromptBuilder: Sendable {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let includeSystemPrompt: Bool
        public let maxHistoryTurns: Int

        public init(
            includeSystemPrompt: Bool = true,
            maxHistoryTurns: Int = 4
        ) {
            self.includeSystemPrompt = includeSystemPrompt
            self.maxHistoryTurns = maxHistoryTurns
        }
    }

    // MARK: - Result Types

    public struct RAGPrompt: Sendable {
        public let systemPrompt: String
        public let userPrompt: String
        public let estimatedTokens: Int

        public init(systemPrompt: String, userPrompt: String, estimatedTokens: Int) {
            self.systemPrompt = systemPrompt
            self.userPrompt = userPrompt
            self.estimatedTokens = estimatedTokens
        }
    }

    // MARK: - Properties

    private let config: Config

    // System prompt for VMware documentation assistant
    private let systemPromptTemplate = """
    You are a VMware documentation expert assistant. Your role is to provide accurate, helpful answers about VMware products based on the official documentation provided.

    Guidelines:
    1. Base your answers ONLY on the provided context from VMware documentation
    2. If the context doesn't contain enough information to fully answer the question, say so clearly
    3. Always cite your sources using [Source N] references when providing information
    4. For technical procedures, provide step-by-step instructions when available in the documentation
    5. Include relevant version-specific information when applicable
    6. If asked about multiple products, organize your response by product
    7. Use proper VMware terminology and product names
    8. If the question is outside the scope of VMware documentation, politely indicate that

    Products covered: vSphere, vCenter Server, ESXi, vSAN, NSX, Tanzu, Aria, Workstation, Fusion, HCX, Cloud Foundation, Cloud Director, Horizon, Live Recovery, Skyline, and Private AI.
    """

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Prompt Building

    /// Build a RAG prompt from query and context
    public func buildPrompt(
        query: String,
        context: ContextAssembler.AssembledContext
    ) -> RAGPrompt {
        let systemPrompt = config.includeSystemPrompt ? systemPromptTemplate : ""

        let userPrompt = """
        Context from VMware Documentation:

        \(context.contextText)

        ---

        Question: \(query)

        Please provide a comprehensive answer based on the documentation above. Cite specific sources using [Source N] notation.
        """

        let estimatedTokens = estimateTokens(systemPrompt) + estimateTokens(userPrompt) + context.tokenCount

        return RAGPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            estimatedTokens: estimatedTokens
        )
    }

    /// Build a follow-up prompt with conversation history
    public func buildFollowUpPrompt(
        query: String,
        context: ContextAssembler.AssembledContext,
        conversationHistory: [(role: String, content: String)]
    ) -> RAGPrompt {
        let systemPrompt = config.includeSystemPrompt ? systemPromptTemplate : ""

        // Include recent history
        let recentHistory = conversationHistory.suffix(config.maxHistoryTurns * 2)
        let historyText = recentHistory.map { turn in
            "\(turn.role.capitalized): \(turn.content)"
        }.joined(separator: "\n\n")

        let userPrompt: String
        if historyText.isEmpty {
            userPrompt = """
            Context from VMware Documentation:

            \(context.contextText)

            ---

            Question: \(query)

            Please provide a comprehensive answer based on the documentation above. Cite specific sources using [Source N] notation.
            """
        } else {
            userPrompt = """
            Previous conversation:
            \(historyText)

            ---

            Context from VMware Documentation:

            \(context.contextText)

            ---

            Follow-up question: \(query)

            Please provide a comprehensive answer based on the documentation and conversation context above. Cite specific sources using [Source N] notation.
            """
        }

        let estimatedTokens = estimateTokens(systemPrompt) + estimateTokens(userPrompt) + context.tokenCount

        return RAGPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            estimatedTokens: estimatedTokens
        )
    }

    private func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
