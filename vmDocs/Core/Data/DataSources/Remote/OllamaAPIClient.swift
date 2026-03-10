import Foundation

/// Client for interacting with the Ollama API
actor OllamaAPIClient {

    struct Config {
        var baseURL: URL
        var timeout: TimeInterval
        var streamingEnabled: Bool

        init(
            baseURL: URL = URL(string: "http://localhost:11434")!,
            timeout: TimeInterval = 120,
            streamingEnabled: Bool = true
        ) {
            self.baseURL = baseURL
            self.timeout = timeout
            self.streamingEnabled = streamingEnabled
        }
    }

    private let config: Config
    private let session: URLSession
    private let decoder: JSONDecoder

    init(config: Config = Config()) {
        self.config = config

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Health Check

    /// Check if Ollama is running and accessible
    func isHealthy() async -> Bool {
        let url = config.baseURL.appendingPathComponent("/api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Models

    /// List all available models
    func listModels() async throws -> [OllamaModel] {
        let url = config.baseURL.appendingPathComponent("/api/tags")
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(ModelsResponse.self, from: data)
        return response.models
    }

    /// Pull a model from the Ollama library
    func pullModel(_ name: String) -> AsyncStream<PullProgress> {
        AsyncStream { continuation in
            Task {
                let url = config.baseURL.appendingPathComponent("/api/pull")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = try? JSONEncoder().encode(["name": name])
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                do {
                    let (stream, _) = try await session.bytes(for: request)

                    for try await line in stream.lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        if let progress = try? self.decoder.decode(PullProgress.self, from: data) {
                            continuation.yield(progress)
                            if progress.status == "success" {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    /// Delete a model
    func deleteModel(_ name: String) async throws {
        let url = config.baseURL.appendingPathComponent("/api/delete")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.httpBody = try JSONEncoder().encode(["name": name])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.deleteFailed
        }
    }

    // MARK: - Chat (Streaming)

    /// Send a chat message and receive a streaming response
    func chat(
        model: String,
        messages: [OllamaMessage],
        options: ChatOptions = ChatOptions()
    ) -> AsyncThrowingStream<ChatStreamResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let url = config.baseURL.appendingPathComponent("/api/chat")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body = ChatRequest(
                    model: model,
                    messages: messages,
                    stream: true,
                    options: options
                )

                do {
                    request.httpBody = try JSONEncoder().encode(body)
                    let (stream, _) = try await session.bytes(for: request)

                    for try await line in stream.lines {
                        guard let data = line.data(using: .utf8) else { continue }

                        do {
                            let response = try self.decoder.decode(ChatStreamResponse.self, from: data)
                            continuation.yield(response)

                            if response.done {
                                continuation.finish()
                                return
                            }
                        } catch {
                            // Skip malformed lines
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Send a chat message and receive a complete response (non-streaming)
    func chatComplete(
        model: String,
        messages: [OllamaMessage],
        options: ChatOptions = ChatOptions()
    ) async throws -> ChatCompleteResponse {
        let url = config.baseURL.appendingPathComponent("/api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: messages,
            stream: false,
            options: options
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await session.data(for: request)
        return try decoder.decode(ChatCompleteResponse.self, from: data)
    }

    // MARK: - Embeddings

    /// Generate embeddings for a single text
    func embeddings(model: String, prompt: String) async throws -> EmbeddingsResponse {
        let url = config.baseURL.appendingPathComponent("/api/embeddings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = EmbeddingsRequest(model: model, prompt: prompt)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await session.data(for: request)
        return try decoder.decode(EmbeddingsResponse.self, from: data)
    }

    /// Generate embeddings for multiple texts in batch
    func embeddingsBatch(model: String, prompts: [String]) async throws -> [[Float]] {
        try await withThrowingTaskGroup(of: (Int, [Float]).self) { group in
            for (index, prompt) in prompts.enumerated() {
                group.addTask {
                    let response = try await self.embeddings(model: model, prompt: prompt)
                    return (index, response.embedding)
                }
            }

            var results: [(Int, [Float])] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

// MARK: - Models

struct OllamaModel: Codable, Identifiable, Sendable {
    let name: String
    let modifiedAt: Date
    let size: Int64
    let digest: String
    let details: ModelDetails?

    var id: String { name }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

struct ModelDetails: Codable, Sendable {
    let format: String?
    let family: String?
    let families: [String]?
    let parameterSize: String?
    let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case format
        case family
        case families
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

struct ModelsResponse: Codable {
    let models: [OllamaModel]
}

struct PullProgress: Codable, Sendable {
    let status: String
    let digest: String?
    let total: Int64?
    let completed: Int64?

    var progress: Double {
        guard let total = total, let completed = completed, total > 0 else {
            return 0
        }
        return Double(completed) / Double(total)
    }
}

struct OllamaMessage: Codable, Sendable {
    let role: String
    let content: String

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct ChatOptions: Codable, Sendable {
    var temperature: Float
    var topP: Float
    var topK: Int
    var numCtx: Int
    var repeatPenalty: Float

    init(
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int = 40,
        numCtx: Int = 4096,
        repeatPenalty: Float = 1.1
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.numCtx = numCtx
        self.repeatPenalty = repeatPenalty
    }

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numCtx = "num_ctx"
        case repeatPenalty = "repeat_penalty"
    }
}

struct ChatRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let options: ChatOptions
}

struct ChatStreamResponse: Codable, Sendable {
    let model: String
    let createdAt: Date
    let message: OllamaMessage?
    let done: Bool
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalCount: Int?
    let evalCount: Int?
    let evalDuration: Int64?

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

struct ChatCompleteResponse: Codable, Sendable {
    let model: String
    let createdAt: Date
    let message: OllamaMessage
    let done: Bool
    let totalDuration: Int64?
    let evalCount: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case totalDuration = "total_duration"
        case evalCount = "eval_count"
    }
}

struct EmbeddingsRequest: Codable {
    let model: String
    let prompt: String
}

struct EmbeddingsResponse: Codable, Sendable {
    let embedding: [Float]
}

// MARK: - Errors

enum OllamaError: Error, LocalizedError {
    case connectionFailed
    case modelNotFound(String)
    case deleteFailed
    case invalidResponse
    case embeddingFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to Ollama. Make sure Ollama is running."
        case .modelNotFound(let model):
            return "Model '\(model)' not found. Please pull the model first."
        case .deleteFailed:
            return "Failed to delete the model."
        case .invalidResponse:
            return "Received an invalid response from Ollama."
        case .embeddingFailed(let reason):
            return "Failed to generate embeddings: \(reason)"
        }
    }
}
