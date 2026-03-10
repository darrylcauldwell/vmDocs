import Foundation

/// Represents an ingested documentation page or file
struct Document: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var sourceURL: URL?
    var localPath: URL?
    var product: VMwareProduct
    var version: String?
    var documentType: DocumentType
    var contentHash: String
    var chunkCount: Int
    var ingestedAt: Date
    var lastAccessedAt: Date?
    var breadcrumbs: [String]

    init(
        id: UUID = UUID(),
        title: String,
        sourceURL: URL? = nil,
        localPath: URL? = nil,
        product: VMwareProduct,
        version: String? = nil,
        documentType: DocumentType = .conceptual,
        contentHash: String,
        chunkCount: Int = 0,
        breadcrumbs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.product = product
        self.version = version
        self.documentType = documentType
        self.contentHash = contentHash
        self.chunkCount = chunkCount
        self.ingestedAt = Date()
        self.lastAccessedAt = nil
        self.breadcrumbs = breadcrumbs
    }
}

/// Classification of document types
enum DocumentType: String, Codable, CaseIterable, Sendable {
    case installationGuide = "installation"
    case administrationGuide = "administration"
    case apiReference = "api"
    case releaseNotes = "release-notes"
    case troubleshooting = "troubleshooting"
    case quickStart = "quickstart"
    case conceptual = "conceptual"
    case howTo = "howto"
    case reference = "reference"
    case securityGuide = "security"
    case upgradeGuide = "upgrade"
    case configurationGuide = "configuration"

    var displayName: String {
        switch self {
        case .installationGuide: return "Installation Guide"
        case .administrationGuide: return "Administration Guide"
        case .apiReference: return "API Reference"
        case .releaseNotes: return "Release Notes"
        case .troubleshooting: return "Troubleshooting"
        case .quickStart: return "Quick Start"
        case .conceptual: return "Concepts"
        case .howTo: return "How-To"
        case .reference: return "Reference"
        case .securityGuide: return "Security Guide"
        case .upgradeGuide: return "Upgrade Guide"
        case .configurationGuide: return "Configuration Guide"
        }
    }

    /// Infer document type from URL or content
    static func infer(from url: URL?, content: String) -> DocumentType {
        let path = url?.path.lowercased() ?? ""
        let lowerContent = content.lowercased().prefix(500)

        if path.contains("install") || lowerContent.contains("installation") {
            return .installationGuide
        }
        if path.contains("admin") || lowerContent.contains("administration") {
            return .administrationGuide
        }
        if path.contains("api") || path.contains("reference") {
            return .apiReference
        }
        if path.contains("release") || lowerContent.contains("release notes") {
            return .releaseNotes
        }
        if path.contains("troubleshoot") || lowerContent.contains("troubleshooting") {
            return .troubleshooting
        }
        if path.contains("quick") || lowerContent.contains("quick start") {
            return .quickStart
        }
        if path.contains("security") {
            return .securityGuide
        }
        if path.contains("upgrade") {
            return .upgradeGuide
        }
        if path.contains("config") {
            return .configurationGuide
        }

        return .conceptual
    }
}
