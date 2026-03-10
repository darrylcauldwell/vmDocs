import Foundation

/// Intelligent text chunker for RAG optimization
/// Uses recursive character splitting with semantic awareness
public final class TextChunker: Sendable {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let targetSize: Int          // Target chunk size in tokens
        public let overlapSize: Int         // Overlap between chunks
        public let minChunkSize: Int        // Minimum chunk size
        public let maxChunkSize: Int        // Maximum chunk size
        public let preserveCodeBlocks: Bool
        public let preserveTables: Bool
        public let preserveHeaders: Bool

        public init(
            targetSize: Int = 512,
            overlapSize: Int = 50,
            minChunkSize: Int = 100,
            maxChunkSize: Int = 1024,
            preserveCodeBlocks: Bool = true,
            preserveTables: Bool = true,
            preserveHeaders: Bool = true
        ) {
            self.targetSize = targetSize
            self.overlapSize = overlapSize
            self.minChunkSize = minChunkSize
            self.maxChunkSize = maxChunkSize
            self.preserveCodeBlocks = preserveCodeBlocks
            self.preserveTables = preserveTables
            self.preserveHeaders = preserveHeaders
        }
    }

    // MARK: - Output Types

    public struct Chunk: Sendable, Identifiable {
        public let id: UUID
        public let content: String
        public let tokenCount: Int
        public let metadata: ChunkMetadata
        public let position: ChunkPosition

        public init(
            id: UUID = UUID(),
            content: String,
            tokenCount: Int,
            metadata: ChunkMetadata,
            position: ChunkPosition
        ) {
            self.id = id
            self.content = content
            self.tokenCount = tokenCount
            self.metadata = metadata
            self.position = position
        }
    }

    public struct ChunkMetadata: Sendable {
        public let sectionTitle: String?
        public let headingHierarchy: [String]
        public let containsCode: Bool
        public let containsTable: Bool

        public init(
            sectionTitle: String? = nil,
            headingHierarchy: [String] = [],
            containsCode: Bool = false,
            containsTable: Bool = false
        ) {
            self.sectionTitle = sectionTitle
            self.headingHierarchy = headingHierarchy
            self.containsCode = containsCode
            self.containsTable = containsTable
        }
    }

    public struct ChunkPosition: Sendable {
        public let startOffset: Int
        public let endOffset: Int
        public let chunkIndex: Int
        public var totalChunks: Int

        public init(
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

    // MARK: - Properties

    private let config: Config

    // Separators in order of preference (try to split on larger boundaries first)
    private let separators: [String] = [
        "\n\n\n",      // Major section breaks
        "\n\n",        // Paragraph breaks
        "\n",          // Line breaks
        ". ",          // Sentence boundaries
        "! ",
        "? ",
        "; ",
        ", ",          // Clause boundaries
        " "            // Word boundaries (last resort)
    ]

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Main Chunking Method

    /// Chunk text into optimally-sized pieces for RAG
    public func chunk(text: String, sectionTitle: String? = nil) -> [Chunk] {
        guard !text.isEmpty else { return [] }

        // Pre-process: identify special blocks
        let segments = segmentText(text)

        // Chunk each segment
        var chunks: [Chunk] = []
        var currentOffset = 0
        var currentHeadings: [String] = []

        for segment in segments {
            switch segment {
            case .text(let content):
                let textChunks = chunkTextSegment(
                    content,
                    startOffset: currentOffset,
                    sectionTitle: sectionTitle,
                    headings: currentHeadings
                )
                chunks.append(contentsOf: textChunks)
                currentOffset += content.count

            case .code(let content):
                if config.preserveCodeBlocks {
                    let codeChunks = chunkCodeBlock(
                        content,
                        startOffset: currentOffset,
                        sectionTitle: sectionTitle,
                        headings: currentHeadings
                    )
                    chunks.append(contentsOf: codeChunks)
                } else {
                    let textChunks = chunkTextSegment(
                        content,
                        startOffset: currentOffset,
                        sectionTitle: sectionTitle,
                        headings: currentHeadings
                    )
                    chunks.append(contentsOf: textChunks)
                }
                currentOffset += content.count

            case .table(let content):
                if config.preserveTables {
                    let tableChunk = createChunk(
                        content: content,
                        startOffset: currentOffset,
                        endOffset: currentOffset + content.count,
                        chunkIndex: chunks.count,
                        sectionTitle: sectionTitle,
                        headings: currentHeadings,
                        containsCode: false,
                        containsTable: true
                    )
                    chunks.append(tableChunk)
                } else {
                    let textChunks = chunkTextSegment(
                        content,
                        startOffset: currentOffset,
                        sectionTitle: sectionTitle,
                        headings: currentHeadings
                    )
                    chunks.append(contentsOf: textChunks)
                }
                currentOffset += content.count

            case .heading(let content, let level):
                // Update heading hierarchy
                while currentHeadings.count >= level {
                    currentHeadings.removeLast()
                }
                currentHeadings.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
                currentOffset += content.count
            }
        }

        // Update total chunks count
        let totalCount = chunks.count
        return chunks.enumerated().map { index, chunk in
            var updatedChunk = chunk
            updatedChunk = Chunk(
                id: chunk.id,
                content: chunk.content,
                tokenCount: chunk.tokenCount,
                metadata: chunk.metadata,
                position: ChunkPosition(
                    startOffset: chunk.position.startOffset,
                    endOffset: chunk.position.endOffset,
                    chunkIndex: index,
                    totalChunks: totalCount
                )
            )
            return updatedChunk
        }
    }

    // MARK: - Segmentation

    private enum TextSegment {
        case text(String)
        case code(String)
        case table(String)
        case heading(String, Int)
    }

    private func segmentText(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentText = ""
        var position = text.startIndex

        while position < text.endIndex {
            // Check for code block (``` or indented)
            if let codeRange = findCodeBlock(in: text, from: position) {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                segments.append(.code(String(text[codeRange])))
                position = codeRange.upperBound
                continue
            }

            // Check for markdown heading
            if let (headingRange, level) = findHeading(in: text, from: position) {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                segments.append(.heading(String(text[headingRange]), level))
                position = headingRange.upperBound
                continue
            }

            // Check for table
            if let tableRange = findTable(in: text, from: position) {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                segments.append(.table(String(text[tableRange])))
                position = tableRange.upperBound
                continue
            }

            // Regular text
            currentText.append(text[position])
            position = text.index(after: position)
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }

        return segments
    }

    private func findCodeBlock(in text: String, from position: String.Index) -> Range<String.Index>? {
        let remaining = text[position...]

        // Fenced code block (```)
        if remaining.hasPrefix("```") {
            if let endFence = remaining.dropFirst(3).range(of: "```") {
                let endIndex = text.index(endFence.upperBound, offsetBy: 0)
                return position..<endIndex
            }
        }

        // Indented code block (4 spaces at start of line after newline)
        if position == text.startIndex || text[text.index(before: position)] == "\n" {
            if remaining.hasPrefix("    ") || remaining.hasPrefix("\t") {
                var endPosition = position
                var lineStart = position

                while endPosition < text.endIndex {
                    let char = text[endPosition]
                    if char == "\n" {
                        lineStart = text.index(after: endPosition)
                        if lineStart < text.endIndex {
                            let nextLine = text[lineStart...]
                            if !nextLine.hasPrefix("    ") && !nextLine.hasPrefix("\t") && !nextLine.hasPrefix("\n") {
                                break
                            }
                        }
                    }
                    endPosition = text.index(after: endPosition)
                }

                if endPosition > position {
                    return position..<endPosition
                }
            }
        }

        return nil
    }

    private func findHeading(in text: String, from position: String.Index) -> (Range<String.Index>, Int)? {
        // Only check at start of text or after newline
        guard position == text.startIndex || text[text.index(before: position)] == "\n" else {
            return nil
        }

        let remaining = text[position...]

        // Count # characters
        var hashCount = 0
        var checkPos = position
        while checkPos < text.endIndex && text[checkPos] == "#" && hashCount < 6 {
            hashCount += 1
            checkPos = text.index(after: checkPos)
        }

        guard hashCount > 0, checkPos < text.endIndex, text[checkPos] == " " else {
            return nil
        }

        // Find end of heading (next newline)
        if let newlineIndex = text[checkPos...].firstIndex(of: "\n") {
            return (position..<text.index(after: newlineIndex), hashCount)
        } else {
            return (position..<text.endIndex, hashCount)
        }
    }

    private func findTable(in text: String, from position: String.Index) -> Range<String.Index>? {
        guard position == text.startIndex || text[text.index(before: position)] == "\n" else {
            return nil
        }

        let remaining = text[position...]

        // Simple table detection: line starting with | and containing |
        guard remaining.hasPrefix("|") else { return nil }

        var endPosition = position
        var lastPipeLineEnd = position

        while endPosition < text.endIndex {
            if text[endPosition] == "\n" {
                let nextLineStart = text.index(after: endPosition)
                if nextLineStart < text.endIndex {
                    // Check if next line is part of table
                    let nextLine = text[nextLineStart...]
                    if nextLine.hasPrefix("|") || nextLine.hasPrefix(" |") {
                        lastPipeLineEnd = endPosition
                    } else if !nextLine.hasPrefix("-") && !nextLine.hasPrefix("|-") {
                        break
                    }
                }
            }
            endPosition = text.index(after: endPosition)
        }

        let tableEnd = lastPipeLineEnd < endPosition ? text.index(after: lastPipeLineEnd) : endPosition
        if tableEnd > position {
            return position..<tableEnd
        }

        return nil
    }

    // MARK: - Text Chunking

    private func chunkTextSegment(
        _ text: String,
        startOffset: Int,
        sectionTitle: String?,
        headings: [String]
    ) -> [Chunk] {
        var chunks: [Chunk] = []
        var currentPosition = 0
        var chunkIndex = 0

        while currentPosition < text.count {
            let remainingText = String(text.dropFirst(currentPosition))
            let (chunkContent, chunkLength) = extractChunk(from: remainingText)

            if !chunkContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let chunk = createChunk(
                    content: chunkContent,
                    startOffset: startOffset + currentPosition,
                    endOffset: startOffset + currentPosition + chunkLength,
                    chunkIndex: chunkIndex,
                    sectionTitle: sectionTitle,
                    headings: headings,
                    containsCode: false,
                    containsTable: false
                )
                chunks.append(chunk)
                chunkIndex += 1
            }

            // Move position, accounting for overlap
            let moveDistance = max(1, chunkLength - config.overlapSize)
            currentPosition += moveDistance

            // Prevent infinite loop
            if chunkLength == 0 {
                currentPosition += 1
            }
        }

        return chunks
    }

    private func extractChunk(from text: String) -> (content: String, length: Int) {
        let targetTokens = config.targetSize
        let maxTokens = config.maxChunkSize

        // Estimate character count from tokens (rough: 4 chars per token)
        let targetChars = targetTokens * 4
        let maxChars = maxTokens * 4

        if text.count <= targetChars {
            return (text, text.count)
        }

        // Try each separator
        for separator in separators {
            if let splitPoint = findOptimalSplitPoint(
                in: text,
                targetChars: targetChars,
                maxChars: maxChars,
                separator: separator
            ) {
                let chunkEnd = text.index(text.startIndex, offsetBy: splitPoint)
                return (String(text[..<chunkEnd]), splitPoint)
            }
        }

        // Fallback: hard cut at max chars
        let cutPoint = min(maxChars, text.count)
        let cutIndex = text.index(text.startIndex, offsetBy: cutPoint)
        return (String(text[..<cutIndex]), cutPoint)
    }

    private func findOptimalSplitPoint(
        in text: String,
        targetChars: Int,
        maxChars: Int,
        separator: String
    ) -> Int? {
        let searchRange = min(maxChars, text.count)
        let searchText = String(text.prefix(searchRange))

        // Find all occurrences of separator
        var splitPoints: [Int] = []
        var searchStart = searchText.startIndex

        while let range = searchText.range(of: separator, range: searchStart..<searchText.endIndex) {
            let offset = searchText.distance(from: searchText.startIndex, to: range.upperBound)
            splitPoints.append(offset)
            searchStart = range.upperBound
        }

        // Find the split point closest to target
        var bestSplit: Int? = nil
        var bestDistance = Int.max

        for point in splitPoints {
            if point >= config.minChunkSize * 4 {  // Minimum chunk size
                let distance = abs(point - targetChars)
                if distance < bestDistance {
                    bestDistance = distance
                    bestSplit = point
                }
            }
        }

        return bestSplit
    }

    // MARK: - Code Block Chunking

    private func chunkCodeBlock(
        _ code: String,
        startOffset: Int,
        sectionTitle: String?,
        headings: [String]
    ) -> [Chunk] {
        let tokenCount = estimateTokens(code)

        // If code block fits in one chunk, keep it together
        if tokenCount <= config.maxChunkSize {
            return [createChunk(
                content: code,
                startOffset: startOffset,
                endOffset: startOffset + code.count,
                chunkIndex: 0,
                sectionTitle: sectionTitle,
                headings: headings,
                containsCode: true,
                containsTable: false
            )]
        }

        // Split large code blocks by logical boundaries
        return splitLargeCodeBlock(
            code,
            startOffset: startOffset,
            sectionTitle: sectionTitle,
            headings: headings
        )
    }

    private func splitLargeCodeBlock(
        _ code: String,
        startOffset: Int,
        sectionTitle: String?,
        headings: [String]
    ) -> [Chunk] {
        var chunks: [Chunk] = []
        let lines = code.components(separatedBy: "\n")
        var currentChunk = ""
        var chunkStartOffset = startOffset
        var chunkIndex = 0

        for line in lines {
            let potentialChunk = currentChunk.isEmpty ? line : currentChunk + "\n" + line
            let tokenCount = estimateTokens(potentialChunk)

            if tokenCount > config.maxChunkSize && !currentChunk.isEmpty {
                // Save current chunk
                chunks.append(createChunk(
                    content: currentChunk,
                    startOffset: chunkStartOffset,
                    endOffset: chunkStartOffset + currentChunk.count,
                    chunkIndex: chunkIndex,
                    sectionTitle: sectionTitle,
                    headings: headings,
                    containsCode: true,
                    containsTable: false
                ))
                chunkIndex += 1
                chunkStartOffset += currentChunk.count + 1
                currentChunk = line
            } else {
                currentChunk = potentialChunk
            }
        }

        // Add remaining content
        if !currentChunk.isEmpty {
            chunks.append(createChunk(
                content: currentChunk,
                startOffset: chunkStartOffset,
                endOffset: chunkStartOffset + currentChunk.count,
                chunkIndex: chunkIndex,
                sectionTitle: sectionTitle,
                headings: headings,
                containsCode: true,
                containsTable: false
            ))
        }

        return chunks
    }

    // MARK: - Helpers

    private func createChunk(
        content: String,
        startOffset: Int,
        endOffset: Int,
        chunkIndex: Int,
        sectionTitle: String?,
        headings: [String],
        containsCode: Bool,
        containsTable: Bool
    ) -> Chunk {
        Chunk(
            content: content,
            tokenCount: estimateTokens(content),
            metadata: ChunkMetadata(
                sectionTitle: sectionTitle,
                headingHierarchy: headings,
                containsCode: containsCode,
                containsTable: containsTable
            ),
            position: ChunkPosition(
                startOffset: startOffset,
                endOffset: endOffset,
                chunkIndex: chunkIndex
            )
        )
    }

    private func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        // This is a simplification; real tokenizers vary
        max(1, text.count / 4)
    }
}
