import Foundation

// MARK: - Watch Folder Manager

/// Monitors a folder for new PDFs and documents to automatically index
public actor WatchFolderManager {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let watchPath: URL
        public let supportedExtensions: [String]
        public let scanInterval: TimeInterval
        public let autoIndex: Bool
        public let organizeByProduct: Bool

        public init(
            watchPath: URL? = nil,
            supportedExtensions: [String] = ["pdf", "html", "htm", "txt", "md"],
            scanInterval: TimeInterval = 60,
            autoIndex: Bool = true,
            organizeByProduct: Bool = true
        ) {
            // Default to ~/Documents/vmDocs
            self.watchPath = watchPath ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("vmDocs")
            self.supportedExtensions = supportedExtensions
            self.scanInterval = scanInterval
            self.autoIndex = autoIndex
            self.organizeByProduct = organizeByProduct
        }
    }

    // MARK: - File Info

    public struct WatchedFile: Sendable, Identifiable {
        public let id: UUID
        public let url: URL
        public let filename: String
        public let fileExtension: String
        public let size: Int64
        public let modifiedDate: Date
        public let addedDate: Date
        public var status: FileStatus
        public var product: String?
        public var errorMessage: String?

        public enum FileStatus: String, Sendable {
            case pending = "Pending"
            case indexing = "Indexing"
            case indexed = "Indexed"
            case failed = "Failed"
            case ignored = "Ignored"
        }
    }

    // MARK: - State

    public enum WatcherState: Sendable, Equatable {
        case stopped
        case watching
        case scanning
        case indexing(progress: Double)

        public static func == (lhs: WatcherState, rhs: WatcherState) -> Bool {
            switch (lhs, rhs) {
            case (.stopped, .stopped): return true
            case (.watching, .watching): return true
            case (.scanning, .scanning): return true
            case (.indexing(let p1), .indexing(let p2)): return p1 == p2
            default: return false
            }
        }
    }

    private let config: Config
    private var watchedFiles: [URL: WatchedFile] = [:]
    private var state: WatcherState = .stopped
    private var watchTask: Task<Void, Never>?
    private var fileMonitor: DispatchSourceFileSystemObject?

    // Event handlers
    private var onFileAdded: ((WatchedFile) -> Void)?
    private var onFileIndexed: ((WatchedFile) -> Void)?
    private var onError: ((Error) -> Void)?

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Public API

    /// Get current watcher state
    public func getState() -> WatcherState {
        state
    }

    /// Get all watched files
    public func getWatchedFiles() -> [WatchedFile] {
        Array(watchedFiles.values).sorted { $0.addedDate > $1.addedDate }
    }

    /// Get the watch folder path
    public func getWatchPath() -> URL {
        config.watchPath
    }

    /// Set up event handlers
    public func setEventHandlers(
        onFileAdded: @escaping (WatchedFile) -> Void,
        onFileIndexed: @escaping (WatchedFile) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onFileAdded = onFileAdded
        self.onFileIndexed = onFileIndexed
        self.onError = onError
    }

    /// Start watching the folder
    public func startWatching() async throws {
        guard state == .stopped else { return }

        // Ensure watch directory exists
        try createWatchDirectory()

        // Initial scan
        await scanFolder()

        // Start periodic scanning
        state = .watching
        watchTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.scanInterval * 1_000_000_000))
                await scanFolder()
            }
        }

        // Set up file system monitoring for immediate detection
        setupFileMonitor()
    }

    /// Stop watching
    public func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        fileMonitor?.cancel()
        fileMonitor = nil
        state = .stopped
    }

    /// Manually trigger a scan
    public func triggerScan() async {
        await scanFolder()
    }

    /// Add a file manually (for drag-and-drop)
    public func addFile(from sourceURL: URL) async throws -> WatchedFile {
        // Copy to watch folder
        let filename = sourceURL.lastPathComponent
        let destURL = config.watchPath.appendingPathComponent(filename)

        // Handle duplicates
        var finalURL = destURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let name = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            finalURL = config.watchPath.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        }

        try FileManager.default.copyItem(at: sourceURL, to: finalURL)

        // Create watched file entry
        let file = createWatchedFile(at: finalURL)
        watchedFiles[finalURL] = file
        onFileAdded?(file)

        return file
    }

    /// Remove a file from watching (and optionally delete)
    public func removeFile(_ url: URL, deleteFromDisk: Bool = false) throws {
        watchedFiles.removeValue(forKey: url)

        if deleteFromDisk {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Update file status after indexing
    public func updateFileStatus(_ url: URL, status: WatchedFile.FileStatus, error: String? = nil) {
        watchedFiles[url]?.status = status
        watchedFiles[url]?.errorMessage = error

        if let file = watchedFiles[url] {
            onFileIndexed?(file)
        }
    }

    /// Infer product from filename or content
    public func inferProduct(for url: URL) -> String {
        let filename = url.lastPathComponent.lowercased()

        let productPatterns: [(pattern: String, product: String)] = [
            ("vsphere", "vSphere"),
            ("vcenter", "vCenter"),
            ("esxi", "ESXi"),
            ("vsan", "vSAN"),
            ("nsx", "NSX"),
            ("tanzu", "Tanzu"),
            ("aria", "Aria"),
            ("horizon", "Horizon"),
            ("vcf", "Cloud Foundation"),
            ("cloud-foundation", "Cloud Foundation"),
            ("workstation", "Workstation"),
            ("fusion", "Fusion")
        ]

        for (pattern, product) in productPatterns {
            if filename.contains(pattern) {
                return product
            }
        }

        return "General"
    }

    // MARK: - Private Methods

    private func createWatchDirectory() throws {
        let fm = FileManager.default

        if !fm.fileExists(atPath: config.watchPath.path) {
            try fm.createDirectory(at: config.watchPath, withIntermediateDirectories: true)
        }

        // Create subdirectories for organization
        if config.organizeByProduct {
            let products = ["vSphere", "vCenter", "vSAN", "NSX", "Tanzu", "Aria", "General"]
            for product in products {
                let subdir = config.watchPath.appendingPathComponent(product)
                if !fm.fileExists(atPath: subdir.path) {
                    try fm.createDirectory(at: subdir, withIntermediateDirectories: true)
                }
            }
        }
    }

    private func scanFolder() async {
        state = .scanning

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: config.watchPath,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            state = .watching
            return
        }

        var newFiles: [WatchedFile] = []

        while let url = enumerator.nextObject() as? URL {
            // Check if it's a supported file type
            let ext = url.pathExtension.lowercased()
            guard config.supportedExtensions.contains(ext) else { continue }

            // Skip if already tracked
            if watchedFiles[url] != nil { continue }

            // Create watched file entry
            let file = createWatchedFile(at: url)
            watchedFiles[url] = file
            newFiles.append(file)
        }

        // Notify about new files
        for file in newFiles {
            onFileAdded?(file)
        }

        // Remove deleted files
        let existingURLs = Set(watchedFiles.keys)
        for url in existingURLs {
            if !fm.fileExists(atPath: url.path) {
                watchedFiles.removeValue(forKey: url)
            }
        }

        state = .watching
    }

    private func createWatchedFile(at url: URL) -> WatchedFile {
        let fm = FileManager.default
        var size: Int64 = 0
        var modifiedDate = Date()

        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
            size = attrs[.size] as? Int64 ?? 0
            modifiedDate = attrs[.modificationDate] as? Date ?? Date()
        }

        return WatchedFile(
            id: UUID(),
            url: url,
            filename: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            size: size,
            modifiedDate: modifiedDate,
            addedDate: Date(),
            status: .pending,
            product: inferProduct(for: url)
        )
    }

    private func setupFileMonitor() {
        let fd = open(config.watchPath.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .global()
        )

        fileMonitor?.setEventHandler { [weak self] in
            Task {
                await self?.scanFolder()
            }
        }

        fileMonitor?.setCancelHandler {
            close(fd)
        }

        fileMonitor?.resume()
    }
}

// MARK: - PDF Extractor

/// Extracts text and metadata from PDF files
public final class PDFExtractor: Sendable {

    public struct ExtractedPDF: Sendable {
        public let url: URL
        public let title: String
        public let author: String?
        public let creationDate: Date?
        public let pageCount: Int
        public let pages: [ExtractedPage]
        public let tableOfContents: [TOCEntry]
        public let metadata: [String: String]
    }

    public struct ExtractedPage: Sendable {
        public let pageNumber: Int
        public let text: String
        public let wordCount: Int
    }

    public struct TOCEntry: Sendable {
        public let title: String
        public let pageNumber: Int
        public let level: Int
    }

    public enum ExtractionError: Error, LocalizedError {
        case fileNotFound
        case invalidPDF
        case extractionFailed(String)
        case passwordProtected

        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "PDF file not found"
            case .invalidPDF: return "Invalid or corrupted PDF file"
            case .extractionFailed(let reason): return "Extraction failed: \(reason)"
            case .passwordProtected: return "PDF is password protected"
            }
        }
    }

    public init() {}

    /// Extract text and metadata from a PDF
    public func extract(from url: URL) throws -> ExtractedPDF {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.fileNotFound
        }

        // Use PDFKit for extraction
        // Note: In production, would use actual PDFKit APIs
        // This is a simplified implementation

        let text = try extractText(from: url)
        let pages = splitIntoPages(text)
        let metadata = extractMetadata(from: url)
        let toc = extractTableOfContents(from: url)

        return ExtractedPDF(
            url: url,
            title: metadata["Title"] ?? url.deletingPathExtension().lastPathComponent,
            author: metadata["Author"],
            creationDate: nil,
            pageCount: pages.count,
            pages: pages.enumerated().map { index, text in
                ExtractedPage(
                    pageNumber: index + 1,
                    text: text,
                    wordCount: text.split(separator: " ").count
                )
            },
            tableOfContents: toc,
            metadata: metadata
        )
    }

    private func extractText(from url: URL) throws -> String {
        // In production, use PDFKit:
        // guard let document = PDFDocument(url: url) else { throw ExtractionError.invalidPDF }
        // var text = ""
        // for i in 0..<document.pageCount {
        //     if let page = document.page(at: i), let pageText = page.string {
        //         text += pageText + "\n\n--- Page \(i+1) ---\n\n"
        //     }
        // }
        // return text

        // Placeholder implementation
        guard let data = try? Data(contentsOf: url) else {
            throw ExtractionError.fileNotFound
        }

        // Simple PDF text extraction (very basic)
        let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""

        // Try to extract readable text between stream markers
        var extractedText = ""
        let streamPattern = #"stream\s*([\s\S]*?)\s*endstream"#

        if let regex = try? NSRegularExpression(pattern: streamPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let textRange = Range(match.range(at: 1), in: content) {
                    let streamContent = String(content[textRange])
                    // Filter to printable ASCII
                    let printable = streamContent.unicodeScalars
                        .filter { $0.value >= 32 && $0.value < 127 }
                        .map { Character($0) }
                    extractedText += String(printable) + " "
                }
            }
        }

        // If no text extracted, return placeholder
        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            extractedText = "[PDF content requires PDFKit for proper extraction. File: \(url.lastPathComponent)]"
        }

        return extractedText
    }

    private func splitIntoPages(_ text: String) -> [String] {
        // Split by page markers if present
        let pagePattern = #"--- Page \d+ ---"#

        guard let regex = try? NSRegularExpression(pattern: pagePattern) else {
            return [text]
        }

        let range = NSRange(text.startIndex..., in: text)
        var pages: [String] = []
        var lastEnd = text.startIndex

        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let matchRange = Range(match.range, in: text) else { return }

            let pageContent = String(text[lastEnd..<matchRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !pageContent.isEmpty {
                pages.append(pageContent)
            }
            lastEnd = matchRange.upperBound
        }

        // Add remaining content after last match
        let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            pages.append(remaining)
        }

        return pages.isEmpty ? [text] : pages
    }

    private func extractMetadata(from url: URL) -> [String: String] {
        // In production, use PDFKit document.documentAttributes
        var metadata: [String: String] = [:]

        // Infer from filename
        let filename = url.deletingPathExtension().lastPathComponent
        metadata["Title"] = filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        return metadata
    }

    private func extractTableOfContents(from url: URL) -> [TOCEntry] {
        // In production, use PDFKit document.outlineRoot
        return []
    }

    /// Chunk a PDF into RAG-optimized chunks
    public func chunkPDF(_ pdf: ExtractedPDF, targetTokens: Int = 512) -> [PDFChunk] {
        var chunks: [PDFChunk] = []

        for page in pdf.pages {
            let pageChunks = chunkPageText(
                page.text,
                pageNumber: page.pageNumber,
                documentTitle: pdf.title,
                targetTokens: targetTokens
            )
            chunks.append(contentsOf: pageChunks)
        }

        return chunks
    }

    public struct PDFChunk: Sendable, Identifiable {
        public let id: UUID
        public let content: String
        public let pageNumber: Int
        public let chunkIndex: Int
        public let documentTitle: String
        public let estimatedTokens: Int
    }

    private func chunkPageText(
        _ text: String,
        pageNumber: Int,
        documentTitle: String,
        targetTokens: Int
    ) -> [PDFChunk] {
        var chunks: [PDFChunk] = []

        // Split into paragraphs
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var currentChunk = ""
        var chunkIndex = 0

        for para in paragraphs {
            let potentialChunk = currentChunk.isEmpty ? para : currentChunk + "\n\n" + para
            let estimatedTokens = potentialChunk.count / 4

            if estimatedTokens > targetTokens && !currentChunk.isEmpty {
                // Save current chunk and start new one
                chunks.append(PDFChunk(
                    id: UUID(),
                    content: currentChunk,
                    pageNumber: pageNumber,
                    chunkIndex: chunkIndex,
                    documentTitle: documentTitle,
                    estimatedTokens: currentChunk.count / 4
                ))
                chunkIndex += 1
                currentChunk = para
            } else {
                currentChunk = potentialChunk
            }
        }

        // Don't forget last chunk
        if !currentChunk.isEmpty {
            chunks.append(PDFChunk(
                id: UUID(),
                content: currentChunk,
                pageNumber: pageNumber,
                chunkIndex: chunkIndex,
                documentTitle: documentTitle,
                estimatedTokens: currentChunk.count / 4
            ))
        }

        return chunks
    }
}

// MARK: - Drag and Drop Handler

/// Handles file drag and drop operations
public final class DragDropHandler: Sendable {

    public struct DropResult: Sendable {
        public let acceptedFiles: [URL]
        public let rejectedFiles: [(url: URL, reason: String)]
    }

    private let supportedExtensions: Set<String>
    private let maxFileSize: Int64

    public init(
        supportedExtensions: [String] = ["pdf", "html", "htm", "txt", "md"],
        maxFileSize: Int64 = 100 * 1024 * 1024  // 100MB
    ) {
        self.supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
        self.maxFileSize = maxFileSize
    }

    /// Validate dropped files
    public func validateDrop(urls: [URL]) -> DropResult {
        var accepted: [URL] = []
        var rejected: [(URL, String)] = []

        for url in urls {
            // Check extension
            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else {
                rejected.append((url, "Unsupported file type: .\(ext)"))
                continue
            }

            // Check file size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                if size > maxFileSize {
                    let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                    rejected.append((url, "File too large: \(sizeStr)"))
                    continue
                }
            }

            // Check readability
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                rejected.append((url, "File not readable"))
                continue
            }

            accepted.append(url)
        }

        return DropResult(acceptedFiles: accepted, rejectedFiles: rejected)
    }
}
