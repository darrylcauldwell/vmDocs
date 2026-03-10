import Foundation

/// Represents a message in a chat conversation
struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var sources: [Source]
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        sources: [Source] = [],
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sources = sources
        self.isStreaming = isStreaming
    }
}

/// Role of a message participant
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// A source citation for RAG responses
struct Source: Identifiable, Codable, Sendable {
    let id: UUID
    var referenceNumber: Int
    var title: String
    var product: String  // VMwareProduct.rawValue
    var version: String?
    var url: URL?
    var sectionTitle: String?
    var relevanceScore: Float

    init(
        id: UUID = UUID(),
        referenceNumber: Int,
        title: String,
        product: String,
        version: String? = nil,
        url: URL? = nil,
        sectionTitle: String? = nil,
        relevanceScore: Float = 0.0
    ) {
        self.id = id
        self.referenceNumber = referenceNumber
        self.title = title
        self.product = product
        self.version = version
        self.url = url
        self.sectionTitle = sectionTitle
        self.relevanceScore = relevanceScore
    }
}

/// A chat conversation containing multiple messages
struct ChatConversation: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    var messages: [ChatMessage]
    var productFilters: [String]  // VMwareProduct.rawValue

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        productFilters: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.messages = messages
        self.productFilters = productFilters
    }

    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastMessageAt = message.timestamp

        // Auto-generate title from first user message
        if title == "New Chat",
           message.role == .user,
           messages.filter({ $0.role == .user }).count == 1 {
            title = String(message.content.prefix(50))
            if message.content.count > 50 {
                title += "..."
            }
        }
    }
}
