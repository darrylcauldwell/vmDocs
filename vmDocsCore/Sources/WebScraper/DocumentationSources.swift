import Foundation

/// Configuration for all VMware documentation sources
public struct DocumentationSources: Sendable {

    /// All available documentation source configurations
    public static let allSources: [DocumentSource] = [
        // Primary Documentation Portals
        techdocs,
        knowledgeBase,

        // Compatibility & Lifecycle (Critical for real-world deployments)
        compatibilityGuide,
        interoperabilityMatrix,
        productLifecycle,
        configurationMaximums,

        // Developer & Automation Resources
        developerCenter,
        powerCLIDocs,
        vmwareGitHub,
        tanzuDeveloperCenter,

        // Blogs
        cloudFoundationBlog,
        vSphereBlog,
        nsxBlog,
        supportInsiderBlog,
        ariaBlog,
        tanzuBlog,
        coreTechZone,

        // Community & Learning
        vmwareCommunity,
        vmwareFlings,
        handsOnLabs,

        // Resource Centers
        resourceCenter,
        validatedDesigns,
        solutionExchange
    ]

    // MARK: - Primary Documentation Portals

    /// TechDocs - Core product guides, APIs, release notes
    public static let techdocs = DocumentSource(
        id: "techdocs",
        name: "VMware TechDocs",
        description: "Installation, operations, APIs, release notes for VCF, vSphere, NSX, Aria",
        baseURL: URL(string: "https://techdocs.broadcom.com")!,
        entryPoints: [
            "/us/en/vmware-cis.html"
        ],
        sitemapURLs: (1...24).map { "https://techdocs.broadcom.com/sitemap-\($0).xml" },
        urlPatterns: [
            URLPattern(include: "/us/en/vmware", exclude: nil),
            URLPattern(include: "/vmware-cis", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".content", "#content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".breadcrumb", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 50000
    )

    /// Knowledge Base - 50,000+ troubleshooting articles
    public static let knowledgeBase = DocumentSource(
        id: "knowledge-base",
        name: "VMware Knowledge Base",
        description: "50,000+ articles on errors, fixes, best practices",
        baseURL: URL(string: "https://knowledge.broadcom.com")!,
        entryPoints: [
            "/external/home"
        ],
        sitemapURLs: [],  // May need to discover dynamically
        urlPatterns: [
            URLPattern(include: "/external/article", exclude: nil),
            URLPattern(include: "/kb/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".kb-content", ".article-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 50000
    )

    // MARK: - Blogs

    /// Cloud Foundation Blog
    public static let cloudFoundationBlog = DocumentSource(
        id: "vcf-blog",
        name: "VCF Blog",
        description: "VCF deep dives, architecture examples, VCF 9.0 updates",
        baseURL: URL(string: "https://blogs.vmware.com")!,
        entryPoints: [
            "/cloud-foundation/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/cloud-foundation/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 500
    )

    /// vSphere Blog
    public static let vSphereBlog = DocumentSource(
        id: "vsphere-blog",
        name: "vSphere Blog",
        description: "vSphere scenarios, integrations, customer stories",
        baseURL: URL(string: "https://blogs.vmware.com")!,
        entryPoints: [
            "/vsphere/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/vsphere/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 1000
    )

    /// NSX Blog
    public static let nsxBlog = DocumentSource(
        id: "nsx-blog",
        name: "NSX Blog",
        description: "NSX networking scenarios and integrations",
        baseURL: URL(string: "https://blogs.vmware.com")!,
        entryPoints: [
            "/nsx/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/nsx/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 500
    )

    /// Support Insider Blog
    public static let supportInsiderBlog = DocumentSource(
        id: "support-insider",
        name: "Support Insider Blog",
        description: "Proactive tips, known issues, troubleshooting workflows",
        baseURL: URL(string: "https://blogs.vmware.com")!,
        entryPoints: [
            "/supportinsider/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/supportinsider/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .high,  // High priority for troubleshooting
        estimatedPages: 300
    )

    // MARK: - Resource Centers

    /// VMware Resource Center
    public static let resourceCenter = DocumentSource(
        id: "resource-center",
        name: "Resource Center",
        description: "Datasheets, whitepapers, solution briefs, ConfigMax tool",
        baseURL: URL(string: "https://www.vmware.com")!,
        entryPoints: [
            "/resources.html"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/resources/", exclude: nil),
            URLPattern(include: "/content/dam/", exclude: nil)  // PDFs
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".resource-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .low,
        estimatedPages: 2000
    )

    /// Validated Designs
    public static let validatedDesigns = DocumentSource(
        id: "validated-designs",
        name: "Validated Designs",
        description: "Architecture blueprints, sizing guides",
        baseURL: URL(string: "https://www.vmware.com")!,
        entryPoints: [
            "/solutions/validated-designs.html"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/validated-design", exclude: nil),
            URLPattern(include: "/design/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".design-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 200
    )

    // MARK: - Compatibility & Lifecycle (Critical for Production)

    /// Hardware Compatibility List (HCL)
    public static let compatibilityGuide = DocumentSource(
        id: "compatibility-guide",
        name: "Compatibility Guide (HCL)",
        description: "Hardware, software, and guest OS compatibility for vSphere, vSAN, NSX",
        baseURL: URL(string: "https://www.vmware.com")!,
        entryPoints: [
            "/resources/compatibility/search.php"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/compatibility/", exclude: nil),
            URLPattern(include: "/resources/compatibility", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".compatibility-content", "#results"],
            removeElements: ["nav", "header", "footer", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 5000
    )

    /// Product Interoperability Matrix
    public static let interoperabilityMatrix = DocumentSource(
        id: "interoperability",
        name: "Interoperability Matrix",
        description: "Product version compatibility between VMware products",
        baseURL: URL(string: "https://interopmatrix.vmware.com")!,
        entryPoints: [
            "/Interoperability"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/Interoperability", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".matrix-content", "#interop-results"],
            removeElements: ["nav", "header", "footer", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 1000
    )

    /// Product Lifecycle Matrix
    public static let productLifecycle = DocumentSource(
        id: "lifecycle",
        name: "Product Lifecycle",
        description: "Support dates, end-of-life, upgrade paths for all VMware products",
        baseURL: URL(string: "https://lifecycle.vmware.com")!,
        entryPoints: [
            "/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".lifecycle-content", "#product-list"],
            removeElements: ["nav", "header", "footer", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 500
    )

    /// Configuration Maximums
    public static let configurationMaximums = DocumentSource(
        id: "configmax",
        name: "Configuration Maximums",
        description: "Max VMs, hosts, clusters, and other limits for vSphere, vSAN, NSX",
        baseURL: URL(string: "https://configmax.esp.vmware.com")!,
        entryPoints: [
            "/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".configmax-content", "#results"],
            removeElements: ["nav", "header", "footer", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 200
    )

    // MARK: - Developer & Automation Resources

    /// VMware Developer Center
    public static let developerCenter = DocumentSource(
        id: "developer-center",
        name: "Developer Center",
        description: "APIs, SDKs, code samples, automation guides",
        baseURL: URL(string: "https://developer.vmware.com")!,
        entryPoints: [
            "/apis",
            "/samples",
            "/docs"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/apis/", exclude: nil),
            URLPattern(include: "/samples/", exclude: nil),
            URLPattern(include: "/docs/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".api-content", ".doc-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 10000
    )

    /// PowerCLI Documentation
    public static let powerCLIDocs = DocumentSource(
        id: "powercli",
        name: "PowerCLI Reference",
        description: "PowerShell cmdlets for vSphere, vSAN, NSX automation",
        baseURL: URL(string: "https://developer.vmware.com")!,
        entryPoints: [
            "/docs/vmware-powercli/latest/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/powercli/", exclude: nil),
            URLPattern(include: "/vmware-powercli/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".cmdlet-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 3000
    )

    /// VMware GitHub Repositories
    public static let vmwareGitHub = DocumentSource(
        id: "vmware-github",
        name: "VMware GitHub",
        description: "Open source tools, SDKs, samples, and community projects",
        baseURL: URL(string: "https://github.com")!,
        entryPoints: [
            "/vmware",
            "/vmware-samples",
            "/vmware-tanzu"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/vmware/", exclude: "/issues"),
            URLPattern(include: "/vmware-samples/", exclude: "/issues"),
            URLPattern(include: "/vmware-tanzu/", exclude: "/issues")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".markdown-body", "readme"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 5000
    )

    /// Tanzu Developer Center
    public static let tanzuDeveloperCenter = DocumentSource(
        id: "tanzu-developer",
        name: "Tanzu Developer Center",
        description: "Kubernetes, containers, cloud-native development guides",
        baseURL: URL(string: "https://tanzu.vmware.com")!,
        entryPoints: [
            "/developer/",
            "/guides/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/developer/", exclude: nil),
            URLPattern(include: "/guides/", exclude: nil),
            URLPattern(include: "/content/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".guide-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 2000
    )

    // MARK: - Additional Blogs

    /// Aria (vRealize) Blog
    public static let ariaBlog = DocumentSource(
        id: "aria-blog",
        name: "Aria Blog",
        description: "VMware Aria Operations, Automation, and Orchestration insights",
        baseURL: URL(string: "https://blogs.vmware.com")!,
        entryPoints: [
            "/management/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/management/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 800
    )

    /// Tanzu Blog
    public static let tanzuBlog = DocumentSource(
        id: "tanzu-blog",
        name: "Tanzu Blog",
        description: "Kubernetes, DevOps, cloud-native application platform insights",
        baseURL: URL(string: "https://tanzu.vmware.com")!,
        entryPoints: [
            "/blog/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/blog/", exclude: "/page/")
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["article", ".post-content", ".entry-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".comments", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 1000
    )

    /// Core Tech Zone
    public static let coreTechZone = DocumentSource(
        id: "core-tech-zone",
        name: "Core Tech Zone",
        description: "Technical deep-dives, architecture discussions, advanced topics",
        baseURL: URL(string: "https://core.vmware.com")!,
        entryPoints: [
            "/",
            "/resource/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/resource/", exclude: nil),
            URLPattern(include: "/blog/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".resource-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 1500
    )

    // MARK: - Community & Learning

    /// VMware Community Forums
    public static let vmwareCommunity = DocumentSource(
        id: "community",
        name: "VMware Community",
        description: "User discussions, solutions, and community knowledge",
        baseURL: URL(string: "https://community.broadcom.com")!,
        entryPoints: [
            "/vmware-cloud-foundation",
            "/vmware-nsx",
            "/vmware-vsphere"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/vmware-", exclude: nil),
            URLPattern(include: "/discussion/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: [".discussion-content", ".message-body", "article"],
            removeElements: ["nav", "header", "footer", ".sidebar", ".user-info", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 100000  // Large community archive
    )

    /// VMware Flings
    public static let vmwareFlings = DocumentSource(
        id: "flings",
        name: "VMware Flings",
        description: "Unsupported community tools with documentation (HCIBench, RVTools alternatives, etc.)",
        baseURL: URL(string: "https://flings.vmware.com")!,
        entryPoints: [
            "/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/flings/", exclude: nil),
            URLPattern(include: "/tools/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", "article", ".fling-content", ".tool-description"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .medium,
        estimatedPages: 200
    )

    /// Hands-on Labs
    public static let handsOnLabs = DocumentSource(
        id: "hands-on-labs",
        name: "Hands-on Labs",
        description: "Step-by-step lab guides for all VMware products",
        baseURL: URL(string: "https://labs.hol.vmware.com")!,
        entryPoints: [
            "/HOL/catalogs/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/HOL/", exclude: nil),
            URLPattern(include: "/catalogs/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".lab-content", ".manual-content"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .high,
        estimatedPages: 500
    )

    // MARK: - Additional Resource Centers

    /// Solution Exchange / Marketplace
    public static let solutionExchange = DocumentSource(
        id: "solution-exchange",
        name: "Solution Exchange",
        description: "Partner solutions, integrations, and certified applications",
        baseURL: URL(string: "https://marketplace.cloud.vmware.com")!,
        entryPoints: [
            "/"
        ],
        sitemapURLs: [],
        urlPatterns: [
            URLPattern(include: "/services/", exclude: nil),
            URLPattern(include: "/solutions/", exclude: nil)
        ],
        contentSelectors: ContentSelectors(
            mainContent: ["main", ".solution-content", ".product-details"],
            removeElements: ["nav", "header", "footer", ".sidebar", "script", "style"]
        ),
        priority: .low,
        estimatedPages: 3000
    )
}

// MARK: - Supporting Types

public struct DocumentSource: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let baseURL: URL
    public let entryPoints: [String]
    public let sitemapURLs: [String]
    public let urlPatterns: [URLPattern]
    public let contentSelectors: ContentSelectors
    public let priority: SourcePriority
    public let estimatedPages: Int

    public var entryPointURLs: [URL] {
        entryPoints.compactMap { baseURL.appendingPathComponent($0) }
    }

    public init(
        id: String,
        name: String,
        description: String,
        baseURL: URL,
        entryPoints: [String],
        sitemapURLs: [String],
        urlPatterns: [URLPattern],
        contentSelectors: ContentSelectors,
        priority: SourcePriority,
        estimatedPages: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.baseURL = baseURL
        self.entryPoints = entryPoints
        self.sitemapURLs = sitemapURLs
        self.urlPatterns = urlPatterns
        self.contentSelectors = contentSelectors
        self.priority = priority
        self.estimatedPages = estimatedPages
    }

    /// Check if a URL belongs to this source
    public func matchesURL(_ url: URL) -> Bool {
        // Check base URL host
        guard let host = url.host,
              let baseHost = baseURL.host,
              host.contains(baseHost) || baseHost.contains(host) else {
            return false
        }

        let path = url.path.lowercased()

        // Check URL patterns
        for pattern in urlPatterns {
            let matchesInclude = path.contains(pattern.include.lowercased())
            let matchesExclude = pattern.exclude.map { path.contains($0.lowercased()) } ?? false

            if matchesInclude && !matchesExclude {
                return true
            }
        }

        return false
    }
}

public struct URLPattern: Sendable {
    public let include: String
    public let exclude: String?

    public init(include: String, exclude: String?) {
        self.include = include
        self.exclude = exclude
    }
}

public struct ContentSelectors: Sendable {
    public let mainContent: [String]
    public let removeElements: [String]

    public init(mainContent: [String], removeElements: [String]) {
        self.mainContent = mainContent
        self.removeElements = removeElements
    }
}

public enum SourcePriority: String, Sendable, CaseIterable {
    case high
    case medium
    case low

    public var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    public var weight: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}
