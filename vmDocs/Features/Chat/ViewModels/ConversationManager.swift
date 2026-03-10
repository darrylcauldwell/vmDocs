import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - Conversation Memory Manager

/// Manages conversation history and context for multi-turn interactions
@Observable
final class ConversationMemoryManager {

    // MARK: - Configuration

    struct Config {
        var maxHistoryTurns: Int = 10
        var summaryThreshold: Int = 20  // Summarize after this many turns
        var persistHistory: Bool = true
    }

    // MARK: - Memory Types

    struct ConversationContext {
        var recentMessages: [MemoryMessage]
        var summary: String?
        var extractedEntities: [String: String]  // entity type -> value
        var topicHistory: [String]
        var productContext: [String]  // Products mentioned
    }

    struct MemoryMessage: Codable, Identifiable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
        let entities: [String: String]
        let topics: [String]
    }

    // MARK: - State

    private var conversations: [UUID: ConversationContext] = [:]
    private var currentConversationId: UUID?
    private let config: Config

    // MARK: - Suggested Questions

    var suggestedQuestions: [String] = []
    var relatedTopics: [String] = []

    // MARK: - Initialization

    init(config: Config = Config()) {
        self.config = config
        generateInitialSuggestions()
    }

    // MARK: - Conversation Management

    /// Start a new conversation
    func startNewConversation() -> UUID {
        let id = UUID()
        conversations[id] = ConversationContext(
            recentMessages: [],
            summary: nil,
            extractedEntities: [:],
            topicHistory: [],
            productContext: []
        )
        currentConversationId = id
        generateInitialSuggestions()
        return id
    }

    /// Add a message to the current conversation
    func addMessage(role: String, content: String) {
        guard let id = currentConversationId else { return }

        let entities = extractEntities(from: content)
        let topics = extractTopics(from: content)

        let message = MemoryMessage(
            id: UUID(),
            role: role,
            content: content,
            timestamp: Date(),
            entities: entities,
            topics: topics
        )

        conversations[id]?.recentMessages.append(message)
        conversations[id]?.topicHistory.append(contentsOf: topics)

        // Update product context
        for (key, value) in entities where key == "product" {
            if !(conversations[id]?.productContext.contains(value) ?? false) {
                conversations[id]?.productContext.append(value)
            }
        }

        // Trim history if needed
        if let count = conversations[id]?.recentMessages.count, count > config.maxHistoryTurns * 2 {
            // Keep most recent messages, summarize older ones
            if count > config.summaryThreshold {
                Task {
                    await summarizeOlderMessages()
                }
            }
            conversations[id]?.recentMessages = Array(conversations[id]!.recentMessages.suffix(config.maxHistoryTurns * 2))
        }

        // Generate follow-up suggestions
        generateContextualSuggestions(basedOn: content, topics: topics)
    }

    /// Get context for the current conversation
    func getCurrentContext() -> ConversationContext? {
        guard let id = currentConversationId else { return nil }
        return conversations[id]
    }

    /// Build context string for RAG prompt
    func buildContextString() -> String {
        guard let context = getCurrentContext() else { return "" }

        var parts: [String] = []

        // Add summary if available
        if let summary = context.summary {
            parts.append("Previous conversation summary: \(summary)")
        }

        // Add relevant entities
        if !context.extractedEntities.isEmpty {
            let entityStr = context.extractedEntities
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            parts.append("Relevant context: \(entityStr)")
        }

        // Add recent messages
        let recentHistory = context.recentMessages.suffix(config.maxHistoryTurns)
            .map { "\($0.role.capitalized): \($0.content)" }
            .joined(separator: "\n")

        if !recentHistory.isEmpty {
            parts.append("Recent conversation:\n\(recentHistory)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Entity Extraction

    private func extractEntities(from text: String) -> [String: String] {
        var entities: [String: String] = [:]
        let lower = text.lowercased()

        // Extract products
        let products = [
            ("vsphere", "vSphere"), ("vcenter", "vCenter"), ("esxi", "ESXi"),
            ("vsan", "vSAN"), ("nsx", "NSX"), ("tanzu", "Tanzu"),
            ("aria", "Aria"), ("horizon", "Horizon"), ("vcf", "Cloud Foundation")
        ]

        for (pattern, product) in products {
            if lower.contains(pattern) {
                entities["product"] = product
                break
            }
        }

        // Extract versions
        let versionPattern = #"\b(\d+\.\d+(?:\.\d+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: versionPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            entities["version"] = String(text[range])
        }

        // Extract actions
        let actions = ["install", "configure", "upgrade", "troubleshoot", "backup", "migrate"]
        for action in actions {
            if lower.contains(action) {
                entities["action"] = action
                break
            }
        }

        return entities
    }

    private func extractTopics(from text: String) -> [String] {
        let lower = text.lowercased()
        var topics: [String] = []

        let topicKeywords = [
            "networking", "storage", "compute", "security", "backup",
            "disaster recovery", "high availability", "clustering",
            "performance", "monitoring", "automation", "api",
            "vm", "virtual machine", "host", "datastore", "port group"
        ]

        for topic in topicKeywords {
            if lower.contains(topic) {
                topics.append(topic)
            }
        }

        return topics
    }

    // MARK: - Suggestions

    private func generateInitialSuggestions() {
        suggestedQuestions = [
            "How do I install vSphere 8?",
            "What are the requirements for vSAN?",
            "How do I configure NSX-T networking?",
            "How do I set up vCenter High Availability?",
            "What's new in VMware Cloud Foundation 5?",
            "How do I troubleshoot VM performance issues?"
        ]

        relatedTopics = [
            "vSphere Installation",
            "vSAN Configuration",
            "NSX Networking",
            "Backup & Recovery",
            "Performance Tuning"
        ]
    }

    private func generateContextualSuggestions(basedOn content: String, topics: [String]) {
        guard let context = getCurrentContext() else { return }

        var suggestions: [String] = []

        // Based on extracted product
        if let product = context.extractedEntities["product"] {
            suggestions.append("What are the system requirements for \(product)?")
            suggestions.append("How do I upgrade \(product)?")
            suggestions.append("What's new in the latest version of \(product)?")
        }

        // Based on action
        if let action = context.extractedEntities["action"] {
            switch action {
            case "install":
                suggestions.append("What are the post-installation steps?")
                suggestions.append("How do I verify the installation?")
            case "configure":
                suggestions.append("What are the best practices for this configuration?")
                suggestions.append("How do I test this configuration?")
            case "troubleshoot":
                suggestions.append("Where can I find the relevant log files?")
                suggestions.append("What are common causes of this issue?")
            default:
                break
            }
        }

        // Based on topics
        for topic in topics.prefix(2) {
            suggestions.append("Tell me more about \(topic)")
        }

        // Keep unique and limit
        suggestedQuestions = Array(Set(suggestions)).prefix(5).map { $0 }

        // Update related topics
        relatedTopics = Array(Set(context.topicHistory)).suffix(5).map { $0 }
    }

    // MARK: - Summarization

    private func summarizeOlderMessages() async {
        guard let id = currentConversationId,
              let context = conversations[id],
              context.recentMessages.count > config.summaryThreshold else { return }

        // Messages to summarize (older ones)
        let toSummarize = Array(context.recentMessages.prefix(context.recentMessages.count - config.maxHistoryTurns))

        // Build summary prompt
        let messagesText = toSummarize
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")

        // In production, call LLM to generate summary
        // For now, create simple extractive summary
        let summary = "Previous discussion covered: " +
            context.topicHistory.prefix(5).joined(separator: ", ")

        conversations[id]?.summary = summary
    }
}

// MARK: - Keyboard Shortcuts Manager

/// Manages keyboard shortcuts for the application
@Observable
final class KeyboardShortcutsManager {

    struct Shortcut: Identifiable {
        let id: String
        let key: String
        let modifiers: String
        let description: String
        var isEnabled: Bool = true
    }

    var shortcuts: [Shortcut] = [
        Shortcut(id: "newChat", key: "N", modifiers: "⌘", description: "New Chat"),
        Shortcut(id: "search", key: "F", modifiers: "⌘", description: "Focus Search"),
        Shortcut(id: "send", key: "↩", modifiers: "⌘", description: "Send Message"),
        Shortcut(id: "stop", key: ".", modifiers: "⌘", description: "Stop Generation"),
        Shortcut(id: "clearChat", key: "K", modifiers: "⌘", description: "Clear Chat"),
        Shortcut(id: "toggleSidebar", key: "S", modifiers: "⌘⇧", description: "Toggle Sidebar"),
        Shortcut(id: "settings", key: ",", modifiers: "⌘", description: "Open Settings"),
        Shortcut(id: "exportChat", key: "E", modifiers: "⌘⇧", description: "Export Chat"),
        Shortcut(id: "previousChat", key: "↑", modifiers: "⌘", description: "Previous Message"),
        Shortcut(id: "nextChat", key: "↓", modifiers: "⌘", description: "Next Message")
    ]

    func getShortcut(for action: String) -> Shortcut? {
        shortcuts.first { $0.id == action }
    }

    func isEnabled(_ action: String) -> Bool {
        shortcuts.first { $0.id == action }?.isEnabled ?? false
    }

    func setEnabled(_ action: String, enabled: Bool) {
        if let index = shortcuts.firstIndex(where: { $0.id == action }) {
            shortcuts[index].isEnabled = enabled
        }
    }
}

// MARK: - Export Manager

/// Handles exporting conversations and search results
final class ExportManager {

    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case json = "JSON"
        case pdf = "PDF"
        case html = "HTML"

        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .json: return "json"
            case .pdf: return "pdf"
            case .html: return "html"
            }
        }
    }

    struct ExportOptions {
        var format: ExportFormat = .markdown
        var includeSources: Bool = true
        var includeTimestamps: Bool = true
        var includeMetadata: Bool = false
    }

    /// Export a conversation to the specified format
    func exportConversation(
        messages: [ChatMessageDisplay],
        sources: [SourceDisplay],
        options: ExportOptions
    ) -> Data? {
        switch options.format {
        case .markdown:
            return exportToMarkdown(messages: messages, sources: sources, options: options)
        case .json:
            return exportToJSON(messages: messages, sources: sources, options: options)
        case .html:
            return exportToHTML(messages: messages, sources: sources, options: options)
        case .pdf:
            // Would use PDFKit to generate PDF
            return exportToMarkdown(messages: messages, sources: sources, options: options)
        }
    }

    private func exportToMarkdown(
        messages: [ChatMessageDisplay],
        sources: [SourceDisplay],
        options: ExportOptions
    ) -> Data? {
        var md = "# VMware Documentation Chat Export\n\n"
        md += "Exported: \(Date().formatted())\n\n"
        md += "---\n\n"

        for message in messages {
            let role = message.isUser ? "**You**" : "**VMware Assistant**"

            if options.includeTimestamps {
                md += "\(role) - \(message.timestamp.formatted(date: .omitted, time: .shortened))\n\n"
            } else {
                md += "\(role)\n\n"
            }

            md += "\(message.content)\n\n"

            if options.includeSources && !message.sources.isEmpty {
                md += "<details><summary>Sources</summary>\n\n"
                for source in message.sources {
                    md += "- [\(source.title)](\(source.url?.absoluteString ?? "#"))\n"
                }
                md += "\n</details>\n\n"
            }

            md += "---\n\n"
        }

        if options.includeSources && !sources.isEmpty {
            md += "## All Sources\n\n"
            for source in sources {
                md += "- **\(source.title)** (\(source.product))"
                if let url = source.url {
                    md += " - [\(url.host ?? "link")](\(url.absoluteString))"
                }
                md += "\n"
            }
        }

        return md.data(using: .utf8)
    }

    private func exportToJSON(
        messages: [ChatMessageDisplay],
        sources: [SourceDisplay],
        options: ExportOptions
    ) -> Data? {
        struct ExportData: Encodable {
            let exportDate: String
            let messages: [MessageData]
            let sources: [SourceData]
        }

        struct MessageData: Encodable {
            let role: String
            let content: String
            let timestamp: String?
            let sources: [String]
        }

        struct SourceData: Encodable {
            let title: String
            let product: String
            let url: String?
        }

        let exportData = ExportData(
            exportDate: Date().ISO8601Format(),
            messages: messages.map { msg in
                MessageData(
                    role: msg.isUser ? "user" : "assistant",
                    content: msg.content,
                    timestamp: options.includeTimestamps ? msg.timestamp.ISO8601Format() : nil,
                    sources: msg.sources.map { $0.title }
                )
            },
            sources: sources.map { src in
                SourceData(
                    title: src.title,
                    product: src.product,
                    url: src.url?.absoluteString
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(exportData)
    }

    private func exportToHTML(
        messages: [ChatMessageDisplay],
        sources: [SourceDisplay],
        options: ExportOptions
    ) -> Data? {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>VMware Documentation Chat Export</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                .message { margin: 20px 0; padding: 15px; border-radius: 8px; }
                .user { background: #e3f2fd; }
                .assistant { background: #f5f5f5; }
                .role { font-weight: bold; margin-bottom: 10px; }
                .timestamp { color: #666; font-size: 12px; }
                .sources { margin-top: 10px; font-size: 14px; }
                .sources a { color: #1976d2; }
            </style>
        </head>
        <body>
            <h1>VMware Documentation Chat</h1>
            <p>Exported: \(Date().formatted())</p>
            <hr>
        """

        for message in messages {
            let roleClass = message.isUser ? "user" : "assistant"
            let roleName = message.isUser ? "You" : "VMware Assistant"

            html += """
            <div class="message \(roleClass)">
                <div class="role">\(roleName)</div>
            """

            if options.includeTimestamps {
                html += "<div class=\"timestamp\">\(message.timestamp.formatted())</div>"
            }

            html += "<p>\(message.content.replacingOccurrences(of: "\n", with: "<br>"))</p>"

            if options.includeSources && !message.sources.isEmpty {
                html += "<div class=\"sources\">Sources: "
                html += message.sources.map { source in
                    if let url = source.url {
                        return "<a href=\"\(url.absoluteString)\">\(source.title)</a>"
                    }
                    return source.title
                }.joined(separator: ", ")
                html += "</div>"
            }

            html += "</div>"
        }

        html += """
        </body>
        </html>
        """

        return html.data(using: .utf8)
    }

    /// Save export to file
    func saveExport(data: Data, filename: String, format: ExportFormat) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(filename).\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
