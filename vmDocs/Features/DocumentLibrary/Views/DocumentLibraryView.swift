import SwiftUI
import SwiftData
import vmDocsCore

/// Document library view for managing indexed documentation
struct DocumentLibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredDocument.ingestedAt, order: .reverse) private var documents: [StoredDocument]

    @State private var searchText = ""
    @State private var selectedProduct: VMwareProduct?
    @State private var sortOrder: SortOrder = .dateAdded

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case product = "Product"

        var icon: String {
            switch self {
            case .dateAdded: return "calendar"
            case .title: return "textformat"
            case .product: return "folder"
            }
        }
    }

    var filteredDocuments: [StoredDocument] {
        var result = documents

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { doc in
                doc.title.localizedCaseInsensitiveContains(searchText) ||
                doc.product.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply product filter
        if let product = selectedProduct {
            result = result.filter { $0.product == product.rawValue }
        }

        // Apply sort
        switch sortOrder {
        case .dateAdded:
            result.sort { $0.ingestedAt > $1.ingestedAt }
        case .title:
            result.sort { $0.title < $1.title }
        case .product:
            result.sort { $0.product < $1.product }
        }

        return result
    }

    var body: some View {
        NavigationSplitView {
            // Product sidebar
            List(selection: $selectedProduct) {
                Section("All Documents") {
                    Label("All (\(documents.count))", systemImage: "doc.text")
                        .tag(nil as VMwareProduct?)
                }

                Section("By Product") {
                    ForEach(VMwareProduct.allCases.filter { $0 != .Unknown }, id: \.self) { product in
                        let count = documents.filter { $0.product == product.rawValue }.count
                        if count > 0 {
                            Label("\(product.displayName) (\(count))", systemImage: product.iconName)
                                .tag(product as VMwareProduct?)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Library")
        } detail: {
            // Document list
            VStack(spacing: 0) {
                // Search and filter bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search documents...", text: $searchText)
                        .textFieldStyle(.plain)

                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                Label(order.rawValue, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))

                Divider()

                if filteredDocuments.isEmpty {
                    EmptyStateView(
                        title: "No Documents",
                        subtitle: searchText.isEmpty
                            ? "Import documents or run the web scraper to get started."
                            : "No documents match your search.",
                        icon: "doc.text"
                    )
                } else {
                    List(filteredDocuments, id: \.id) { document in
                        DocumentRowView(document: document)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.showImportSheet = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button {
                    appState.showScraperSheet = true
                } label: {
                    Label("Scrape Web", systemImage: "globe")
                }

                if appState.isIndexing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }
}

/// Row view for a document
struct DocumentRowView: View {
    let document: StoredDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(document.product)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack {
                if let version = document.version {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(document.chunkCount) chunks")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(document.ingestedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let url = document.sourceURL {
                Link(url.host ?? url.absoluteString, destination: url)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Import documents view
struct ImportDocumentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles: [URL] = []
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importStatus = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Drop zone
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Drop PDF or HTML files here")
                                .foregroundStyle(.secondary)
                            Text("or click to browse")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onTapGesture {
                        // Show file picker
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.pdf, .html]
                        panel.allowsMultipleSelection = true

                        if panel.runModal() == .OK {
                            selectedFiles = panel.urls
                        }
                    }

                // Selected files
                if !selectedFiles.isEmpty {
                    List(selectedFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: url.pathExtension == "pdf" ? "doc.text" : "globe")
                            Text(url.lastPathComponent)
                            Spacer()
                            Button {
                                selectedFiles.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 150)
                }

                // Progress
                if isImporting {
                    VStack(spacing: 8) {
                        ProgressView(value: importProgress)
                        Text(importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import Documents")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        Task {
                            await importFiles()
                        }
                    }
                    .disabled(selectedFiles.isEmpty || isImporting)
                }
            }
        }
        .frame(width: 500, height: 450)
    }

    private func importFiles() async {
        isImporting = true

        for (index, url) in selectedFiles.enumerated() {
            importStatus = "Processing \(url.lastPathComponent)..."
            importProgress = Double(index) / Double(selectedFiles.count)

            // Simulate processing
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        importProgress = 1.0
        importStatus = "Complete!"

        try? await Task.sleep(nanoseconds: 500_000_000)
        dismiss()
    }
}

/// Web scraper view
struct WebScraperView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedSources: Set<String> = ["techdocs"]
    @State private var isRunning = false
    @State private var progress: Double = 0
    @State private var status = ""
    @State private var pagesFound = 0
    @State private var pagesProcessed = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Documentation Sources") {
                    ForEach(DocumentationSources.allSources, id: \.id) { source in
                        Toggle(isOn: Binding(
                            get: { selectedSources.contains(source.id) },
                            set: { isOn in
                                if isOn {
                                    selectedSources.insert(source.id)
                                } else {
                                    selectedSources.remove(source.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(.headline)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("~\(source.estimatedPages) pages")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if isRunning {
                    Section("Progress") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress)

                            HStack {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pagesProcessed)/\(pagesFound) pages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scrape Documentation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isRunning {
                            // Cancel scraping
                            isRunning = false
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isRunning {
                        Button("Stop") {
                            isRunning = false
                        }
                    } else {
                        Button("Start Scraping") {
                            Task {
                                await startScraping()
                            }
                        }
                        .disabled(selectedSources.isEmpty)
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }

    private func startScraping() async {
        isRunning = true
        status = "Discovering pages..."
        pagesFound = 0
        pagesProcessed = 0

        // Simulate scraping progress
        for i in 0..<100 {
            guard isRunning else { break }

            progress = Double(i) / 100.0
            pagesFound = i * 50
            pagesProcessed = i * 45

            if i < 20 {
                status = "Discovering pages from sitemaps..."
            } else if i < 40 {
                status = "Crawling documentation..."
            } else if i < 80 {
                status = "Processing and indexing..."
            } else {
                status = "Finalizing..."
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if isRunning {
            progress = 1.0
            status = "Complete!"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        }
    }
}

/// Search view
struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var searchResults: [SearchResultDisplay] = []
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search documentation...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await performSearch()
                        }
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // Results
            if searchResults.isEmpty {
                EmptyStateView(
                    title: "Search Documentation",
                    subtitle: "Enter a search query to find relevant documentation.",
                    icon: "magnifyingglass"
                )
            } else {
                List(searchResults) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.title)
                                .font(.headline)
                            Spacer()
                            Text(result.product)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Text(result.snippet)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text("Score: \(result.score, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            if let url = result.url {
                                Link("Open", destination: url)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
    }

    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true

        // Simulate search
        try? await Task.sleep(nanoseconds: 500_000_000)

        searchResults = [
            SearchResultDisplay(
                id: UUID(),
                title: "vSphere Installation Guide",
                snippet: "This guide provides information about installing VMware vSphere...",
                product: "vSphere",
                score: 0.95,
                url: URL(string: "https://techdocs.broadcom.com/vsphere")
            ),
            SearchResultDisplay(
                id: UUID(),
                title: "NSX-T Data Center Administration",
                snippet: "NSX-T Data Center provides a full-featured networking and security...",
                product: "NSX",
                score: 0.87,
                url: URL(string: "https://techdocs.broadcom.com/nsx")
            )
        ]

        isSearching = false
    }
}

struct SearchResultDisplay: Identifiable {
    let id: UUID
    let title: String
    let snippet: String
    let product: String
    let score: Float
    let url: URL?
}

#Preview {
    DocumentLibraryView()
        .environment(AppState())
}
