import SwiftUI
import SwiftData

/// View model for the chat interface
@Observable
final class ChatViewModel {

    // MARK: - State

    var messages: [ChatMessageDisplay] = []
    var isStreaming = false
    var streamingText = ""
    var tokensPerSecond: Double = 0
    var showContextSidebar = true
    var currentSources: [SourceDisplay] = []
    var lastRetrievalInfo: RetrievalInfoDisplay?

    // MARK: - Private State

    private var streamingTask: Task<Void, Never>?
    private var tokenCount = 0
    private var streamStartTime: Date?

    // MARK: - Actions

    func startNewChat() {
        messages = []
        currentSources = []
        lastRetrievalInfo = nil
        streamingText = ""
        isStreaming = false
    }

    func sendMessage(_ text: String, appState: AppState) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }

        // Add user message
        let userMessage = ChatMessageDisplay(
            id: UUID(),
            content: text,
            isUser: true,
            timestamp: Date(),
            sources: []
        )
        messages.append(userMessage)

        // Start streaming
        isStreaming = true
        streamingText = ""
        tokenCount = 0
        streamStartTime = Date()

        // Get product filters
        let productFilters = Array(appState.selectedProducts)

        // Perform RAG query
        do {
            try await performRAGQuery(text, productFilters: productFilters, appState: appState)
        } catch {
            // Add error message
            let errorMessage = ChatMessageDisplay(
                id: UUID(),
                content: "Error: \(error.localizedDescription)",
                isUser: false,
                timestamp: Date(),
                sources: []
            )
            messages.append(errorMessage)
        }

        isStreaming = false
    }

    func stopGeneration() {
        streamingTask?.cancel()
        streamingTask = nil

        if !streamingText.isEmpty {
            // Save partial response
            let partialMessage = ChatMessageDisplay(
                id: UUID(),
                content: streamingText + " [stopped]",
                isUser: false,
                timestamp: Date(),
                sources: currentSources
            )
            messages.append(partialMessage)
        }

        streamingText = ""
        isStreaming = false
    }

    func showSource(_ source: SourceDisplay) {
        // Open source URL if available
        if let url = source.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - RAG Query

    private func performRAGQuery(_ query: String, productFilters: [String], appState: AppState) async throws {
        guard let client = appState.ollamaClient else {
            throw ChatError.ollamaNotConnected
        }

        // For now, simulate RAG with direct LLM query
        // In full implementation, this would:
        // 1. Generate query embedding
        // 2. Perform hybrid search
        // 3. Assemble context
        // 4. Build prompt
        // 5. Stream response

        let systemPrompt = """
        You are a VMware documentation expert assistant. Answer questions about VMware products including vSphere, vCenter, ESXi, vSAN, NSX, Tanzu, Aria, and other VMware technologies.

        Provide accurate, helpful answers. If you're not sure about something, say so.
        """

        let messages = [
            OllamaMessage(role: "system", content: systemPrompt),
            OllamaMessage(role: "user", content: query)
        ]

        let model = appState.selectedChatModel

        streamingTask = Task {
            var fullResponse = ""

            do {
                for try await response in await client.chat(
                    model: model,
                    messages: messages,
                    options: ChatOptions(temperature: 0.7, numCtx: 4096)
                ) {
                    guard !Task.isCancelled else { break }

                    if let content = response.message?.content {
                        fullResponse += content
                        await MainActor.run {
                            self.streamingText = fullResponse
                            self.tokenCount += 1
                            self.updateTokensPerSecond()
                        }
                    }

                    if response.done {
                        await MainActor.run {
                            // Create assistant message
                            let assistantMessage = ChatMessageDisplay(
                                id: UUID(),
                                content: fullResponse,
                                isUser: false,
                                timestamp: Date(),
                                sources: self.currentSources
                            )
                            self.messages.append(assistantMessage)
                            self.streamingText = ""

                            // Mock retrieval info for demo
                            self.lastRetrievalInfo = RetrievalInfoDisplay(
                                chunksUsed: 5,
                                chunksAvailable: 10,
                                retrievalTimeMs: 45
                            )
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        let errorMessage = ChatMessageDisplay(
                            id: UUID(),
                            content: "Error: \(error.localizedDescription)",
                            isUser: false,
                            timestamp: Date(),
                            sources: []
                        )
                        self.messages.append(errorMessage)
                    }
                }
            }
        }

        await streamingTask?.value
    }

    private func updateTokensPerSecond() {
        guard let start = streamStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0 {
            tokensPerSecond = Double(tokenCount) / elapsed
        }
    }
}

// MARK: - Errors

enum ChatError: Error, LocalizedError {
    case ollamaNotConnected
    case embeddingFailed
    case searchFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .ollamaNotConnected:
            return "Ollama is not connected. Please check that Ollama is running."
        case .embeddingFailed:
            return "Failed to generate embeddings for the query."
        case .searchFailed:
            return "Search failed. Please try again."
        case .noResults:
            return "No relevant documentation found for your query."
        }
    }
}
