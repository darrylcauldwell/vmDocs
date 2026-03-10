import Foundation

/// Robust web scraper for Broadcom TechDocs VMware documentation
/// Uses multiple strategies to ensure comprehensive coverage
public actor BroadcomDocsScraper {

    // MARK: - Configuration

    public struct Config: Sendable {
        public let baseURL: URL
        public let vmwareDocsPath: String
        public let maxConcurrentRequests: Int
        public let requestDelay: TimeInterval
        public let maxDepth: Int
        public let maxPages: Int
        public let userAgent: String

        public init(
            baseURL: URL = URL(string: "https://techdocs.broadcom.com")!,
            vmwareDocsPath: String = "/us/en/vmware-cis",
            maxConcurrentRequests: Int = 5,
            requestDelay: TimeInterval = 0.5,
            maxDepth: Int = 10,
            maxPages: Int = 50000,
            userAgent: String = "vmDocs/1.0 (macOS; Documentation Indexer)"
        ) {
            self.baseURL = baseURL
            self.vmwareDocsPath = vmwareDocsPath
            self.maxConcurrentRequests = maxConcurrentRequests
            self.requestDelay = requestDelay
            self.maxDepth = maxDepth
            self.maxPages = maxPages
            self.userAgent = userAgent
        }

        public var sitemapURLs: [URL] {
            (1...24).compactMap { URL(string: "https://techdocs.broadcom.com/sitemap-\($0).xml") }
        }

        public var entryPointURL: URL {
            baseURL.appendingPathComponent(vmwareDocsPath + ".html")
        }
    }

    // MARK: - State

    public enum ScraperState: Sendable {
        case idle
        case discoveringSitemaps(progress: Double, sitemapsProcessed: Int)
        case discoveringLinks(progress: Double, pagesScanned: Int, urlsFound: Int)
        case scraping(progress: Double, pagesProcessed: Int, total: Int)
        case completed(totalPages: Int, totalChunks: Int)
        case failed(String)
        case cancelled
    }

    public struct ScrapedPage: Sendable {
        public let url: URL
        public let title: String
        public let content: String
        public let htmlContent: String
        public let breadcrumbs: [String]
        public let product: String
        public let version: String?
        public let links: [URL]
        public let scrapedAt: Date

        public init(
            url: URL,
            title: String,
            content: String,
            htmlContent: String,
            breadcrumbs: [String],
            product: String,
            version: String?,
            links: [URL],
            scrapedAt: Date = Date()
        ) {
            self.url = url
            self.title = title
            self.content = content
            self.htmlContent = htmlContent
            self.breadcrumbs = breadcrumbs
            self.product = product
            self.version = version
            self.links = links
            self.scrapedAt = scrapedAt
        }
    }

    // MARK: - Properties

    private let config: Config
    private let session: URLSession
    private var visitedURLs: Set<URL> = []
    private var urlFrontier: [URL] = []
    private var discoveredURLs: Set<URL> = []
    private var isCancelled = false
    private var state: ScraperState = .idle

    // MARK: - Initialization

    public init(config: Config = Config()) {
        self.config = config

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = config.maxConcurrentRequests
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Get current scraper state
    public func getState() -> ScraperState {
        state
    }

    /// Cancel ongoing scraping
    public func cancel() {
        isCancelled = true
        state = .cancelled
    }

    /// Reset scraper state for a new run
    public func reset() {
        visitedURLs.removeAll()
        urlFrontier.removeAll()
        discoveredURLs.removeAll()
        isCancelled = false
        state = .idle
    }

    /// Main scraping entry point - uses multiple discovery strategies
    public func scrapeAllDocumentation() -> AsyncThrowingStream<ScrapedPage, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Phase 1: Discover URLs from sitemaps
                    await discoverFromSitemaps()

                    // Phase 2: Discover URLs by crawling from entry point
                    await discoverByCrawling()

                    // Phase 3: Scrape all discovered URLs
                    let allURLs = Array(discoveredURLs)
                    state = .scraping(progress: 0, pagesProcessed: 0, total: allURLs.count)

                    var processed = 0
                    for batch in allURLs.chunked(into: config.maxConcurrentRequests) {
                        guard !isCancelled else {
                            state = .cancelled
                            continuation.finish()
                            return
                        }

                        // Process batch concurrently
                        try await withThrowingTaskGroup(of: ScrapedPage?.self) { group in
                            for url in batch {
                                group.addTask {
                                    try await self.scrapePage(url: url)
                                }
                            }

                            for try await page in group {
                                if let page = page {
                                    continuation.yield(page)

                                    // Discover more links from this page
                                    for link in page.links {
                                        if isValidVMwareDocURL(link) && !visitedURLs.contains(link) {
                                            discoveredURLs.insert(link)
                                        }
                                    }
                                }
                                processed += 1
                                state = .scraping(
                                    progress: Double(processed) / Double(allURLs.count),
                                    pagesProcessed: processed,
                                    total: allURLs.count
                                )
                            }
                        }

                        // Rate limiting
                        try await Task.sleep(nanoseconds: UInt64(config.requestDelay * 1_000_000_000))
                    }

                    state = .completed(totalPages: processed, totalChunks: 0)
                    continuation.finish()

                } catch {
                    state = .failed(error.localizedDescription)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Discovery Strategies

    /// Strategy 1: Parse all sitemaps to find VMware documentation URLs
    private func discoverFromSitemaps() async {
        state = .discoveringSitemaps(progress: 0, sitemapsProcessed: 0)

        for (index, sitemapURL) in config.sitemapURLs.enumerated() {
            guard !isCancelled else { return }

            do {
                let urls = try await parseSitemap(url: sitemapURL)
                for url in urls where isValidVMwareDocURL(url) {
                    discoveredURLs.insert(url)
                }

                state = .discoveringSitemaps(
                    progress: Double(index + 1) / Double(config.sitemapURLs.count),
                    sitemapsProcessed: index + 1
                )
            } catch {
                // Continue with other sitemaps if one fails
                print("Failed to parse sitemap \(sitemapURL): \(error)")
            }

            // Small delay between sitemap requests
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// Strategy 2: Crawl from entry point to discover linked pages
    private func discoverByCrawling() async {
        // Start with entry point and any discovered URLs
        urlFrontier = [config.entryPointURL] + Array(discoveredURLs.prefix(100))
        var depth = 0
        var totalScanned = 0

        state = .discoveringLinks(progress: 0, pagesScanned: 0, urlsFound: discoveredURLs.count)

        while !urlFrontier.isEmpty && depth < config.maxDepth && !isCancelled {
            let currentBatch = Array(urlFrontier.prefix(config.maxConcurrentRequests * 2))
            urlFrontier.removeFirst(min(currentBatch.count, urlFrontier.count))

            for url in currentBatch {
                guard !visitedURLs.contains(url) else { continue }
                visitedURLs.insert(url)

                do {
                    let links = try await extractLinks(from: url)
                    for link in links where isValidVMwareDocURL(link) && !visitedURLs.contains(link) {
                        discoveredURLs.insert(link)
                        if !urlFrontier.contains(link) {
                            urlFrontier.append(link)
                        }
                    }
                    totalScanned += 1

                    state = .discoveringLinks(
                        progress: min(0.99, Double(totalScanned) / 1000.0),
                        pagesScanned: totalScanned,
                        urlsFound: discoveredURLs.count
                    )
                } catch {
                    // Continue on individual page failures
                }

                try? await Task.sleep(nanoseconds: UInt64(config.requestDelay * 500_000_000))
            }

            depth += 1
        }
    }

    // MARK: - Parsing

    /// Parse a sitemap XML file
    private func parseSitemap(url: URL) async throws -> [URL] {
        var request = URLRequest(url: url)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return []
        }

        // Simple XML parsing for sitemap
        var urls: [URL] = []
        let pattern = #"<loc>(https?://[^<]+)</loc>"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(xmlString.startIndex..., in: xmlString)

        regex.enumerateMatches(in: xmlString, range: range) { match, _, _ in
            if let matchRange = match?.range(at: 1),
               let swiftRange = Range(matchRange, in: xmlString),
               let url = URL(string: String(xmlString[swiftRange])) {
                urls.append(url)
            }
        }

        return urls
    }

    /// Extract all links from a page
    private func extractLinks(from url: URL) async throws -> [URL] {
        var request = URLRequest(url: url)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }

        return extractLinksFromHTML(html, baseURL: url)
    }

    /// Scrape a single page
    private func scrapePage(url: URL) async throws -> ScrapedPage? {
        guard !visitedURLs.contains(url) else { return nil }
        visitedURLs.insert(url)

        var request = URLRequest(url: url)
        request.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Extract content
        let title = extractTitle(from: html)
        let content = extractTextContent(from: html)
        let breadcrumbs = extractBreadcrumbs(from: html)
        let links = extractLinksFromHTML(html, baseURL: url)
        let (product, version) = inferProductAndVersion(from: url, html: html)

        // Skip pages with very little content
        guard content.count > 100 else { return nil }

        return ScrapedPage(
            url: url,
            title: title,
            content: content,
            htmlContent: html,
            breadcrumbs: breadcrumbs,
            product: product,
            version: version,
            links: links
        )
    }

    // MARK: - HTML Extraction Helpers

    private func extractTitle(from html: String) -> String {
        // Try <title> tag
        if let titleMatch = html.range(of: #"<title[^>]*>([^<]+)</title>"#, options: .regularExpression) {
            let match = String(html[titleMatch])
            if let contentStart = match.firstIndex(of: ">"),
               let contentEnd = match.lastIndex(of: "<") {
                let startIndex = match.index(after: contentStart)
                return String(match[startIndex..<contentEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Try <h1> tag
        if let h1Match = html.range(of: #"<h1[^>]*>([^<]+)</h1>"#, options: .regularExpression) {
            let match = String(html[h1Match])
            if let contentStart = match.firstIndex(of: ">"),
               let contentEnd = match.lastIndex(of: "<") {
                let startIndex = match.index(after: contentStart)
                return String(match[startIndex..<contentEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return "Untitled"
    }

    private func extractTextContent(from html: String) -> String {
        var content = html

        // Remove script and style tags with their content
        content = content.replacingOccurrences(
            of: #"<script[^>]*>[\s\S]*?</script>"#,
            with: "",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"<style[^>]*>[\s\S]*?</style>"#,
            with: "",
            options: .regularExpression
        )

        // Remove navigation, header, footer
        content = content.replacingOccurrences(
            of: #"<nav[^>]*>[\s\S]*?</nav>"#,
            with: "",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"<header[^>]*>[\s\S]*?</header>"#,
            with: "",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"<footer[^>]*>[\s\S]*?</footer>"#,
            with: "",
            options: .regularExpression
        )

        // Remove HTML tags
        content = content.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        content = content
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        // Normalize whitespace
        content = content.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractBreadcrumbs(from html: String) -> [String] {
        var breadcrumbs: [String] = []

        // Look for breadcrumb nav patterns
        let patterns = [
            #"<nav[^>]*breadcrumb[^>]*>[\s\S]*?</nav>"#,
            #"<[^>]*class="[^"]*breadcrumb[^"]*"[^>]*>[\s\S]*?</[^>]+>"#,
            #"<ol[^>]*breadcrumb[^>]*>[\s\S]*?</ol>"#
        ]

        for pattern in patterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let breadcrumbHTML = String(html[match])

                // Extract text from links within breadcrumb
                let linkPattern = #"<a[^>]*>([^<]+)</a>"#
                let regex = try? NSRegularExpression(pattern: linkPattern)
                let range = NSRange(breadcrumbHTML.startIndex..., in: breadcrumbHTML)

                regex?.enumerateMatches(in: breadcrumbHTML, range: range) { linkMatch, _, _ in
                    if let textRange = linkMatch?.range(at: 1),
                       let swiftRange = Range(textRange, in: breadcrumbHTML) {
                        let text = String(breadcrumbHTML[swiftRange])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            breadcrumbs.append(text)
                        }
                    }
                }

                if !breadcrumbs.isEmpty {
                    break
                }
            }
        }

        return breadcrumbs
    }

    private func extractLinksFromHTML(_ html: String, baseURL: URL) -> [URL] {
        var links: [URL] = []
        let pattern = #"<a[^>]+href="([^"]+)"[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..., in: html)

        regex?.enumerateMatches(in: html, range: range) { match, _, _ in
            if let hrefRange = match?.range(at: 1),
               let swiftRange = Range(hrefRange, in: html) {
                let href = String(html[swiftRange])

                // Resolve relative URLs
                if let url = URL(string: href, relativeTo: baseURL)?.absoluteURL {
                    links.append(url)
                }
            }
        }

        return links
    }

    private func inferProductAndVersion(from url: URL, html: String) -> (String, String?) {
        let path = url.path.lowercased()

        // Product inference
        var product = "Unknown"
        let productMappings: [(pattern: String, product: String)] = [
            ("vsphere", "vSphere"),
            ("vcenter", "vCenter"),
            ("esxi", "ESXi"),
            ("vsan", "vSAN"),
            ("nsx", "NSX"),
            ("tanzu", "Tanzu"),
            ("aria", "Aria"),
            ("workstation", "Workstation"),
            ("fusion", "Fusion"),
            ("hcx", "HCX"),
            ("cloud-foundation", "VCF"),
            ("vcf", "VCF"),
            ("cloud-director", "CloudDirector"),
            ("horizon", "Horizon"),
            ("live-recovery", "LiveRecovery"),
            ("skyline", "Skyline"),
            ("private-ai", "PrivateAI")
        ]

        for mapping in productMappings {
            if path.contains(mapping.pattern) {
                product = mapping.product
                break
            }
        }

        // Version inference (look for patterns like /8.0/, /7.0u3/, etc.)
        var version: String? = nil
        let versionPattern = #"/(\d+\.\d+[a-z0-9]*)/"#
        if let match = path.range(of: versionPattern, options: .regularExpression) {
            let versionMatch = String(path[match])
            version = versionMatch.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return (product, version)
    }

    // MARK: - URL Validation

    private func isValidVMwareDocURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // Must be from Broadcom TechDocs
        guard host.contains("techdocs.broadcom.com") else { return false }

        let path = url.path.lowercased()

        // Must be in VMware CIS section
        guard path.contains("/vmware") || path.contains("vmware-cis") else { return false }

        // Exclude non-documentation URLs
        let excludePatterns = [
            "/search",
            "/login",
            "/register",
            "/feedback",
            "/download",
            ".pdf",
            ".zip",
            ".exe",
            "/api/",
            "javascript:",
            "mailto:",
            "#"
        ]

        for pattern in excludePatterns {
            if path.contains(pattern) || url.absoluteString.contains(pattern) {
                return false
            }
        }

        return true
    }
}

// Array.chunked(into:) extension is defined in CacheManager.swift
