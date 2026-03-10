import SwiftUI
import UniformTypeIdentifiers

/// View for managing the watch folder and custom document uploads
struct WatchFolderView: View {
    @Environment(AppState.self) private var appState
    @State private var watchedFiles: [WatchedFileDisplay] = []
    @State private var isScanning = false
    @State private var isDragging = false
    @State private var showFilePicker = false
    @State private var selectedProduct: String = "Auto-detect"

    let products = ["Auto-detect", "vSphere", "vCenter", "vSAN", "NSX", "Tanzu", "Aria", "Cloud Foundation", "General"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Document Library")
                        .font(.title2.bold())
                    Text("Drop PDFs, design guides, or books to index them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Product filter
                Picker("Product", selection: $selectedProduct) {
                    ForEach(products, id: \.self) { product in
                        Text(product).tag(product)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Add Files", systemImage: "plus")
                }

                Button {
                    openWatchFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
            }
            .padding()

            Divider()

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragging ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                    .strokeBorder(
                        isDragging ? Color.accentColor : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: isDragging ? [] : [8])
                    )

                VStack(spacing: 12) {
                    Image(systemName: isDragging ? "arrow.down.doc.fill" : "doc.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(isDragging ? Color.accentColor : Color.secondary)

                    Text(isDragging ? "Drop files here" : "Drag and drop PDF, HTML, or Markdown files")
                        .font(.headline)
                        .foregroundStyle(isDragging ? Color.accentColor : Color.secondary)

                    Text("Supported: PDF, HTML, TXT, MD")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 150)
            .padding()
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
                return true
            }

            Divider()

            // File list
            if watchedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No custom documents yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add VMware design guides, books, or other PDFs to enhance your knowledge base")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        SuggestedDocButton(
                            title: "VMware Validated Designs",
                            icon: "checkmark.seal"
                        )
                        SuggestedDocButton(
                            title: "Architecture Guides",
                            icon: "building.2"
                        )
                        SuggestedDocButton(
                            title: "Best Practices",
                            icon: "star"
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(watchedFiles) { file in
                        WatchedFileRow(file: file) {
                            reindexFile(file)
                        } onDelete: {
                            deleteFile(file)
                        }
                    }
                }
                .listStyle(.plain)
            }

            // Footer status
            HStack {
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning for new files...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("\(watchedFiles.count) documents in library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Watch folder: ~/Documents/vmDocs")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .html, .plainText],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
        .onAppear {
            loadWatchedFiles()
        }
    }

    // MARK: - Actions

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
                guard let urlData = data as? Data,
                      let path = String(data: urlData, encoding: .utf8),
                      let url = URL(string: path) else { return }

                DispatchQueue.main.async {
                    addFile(url: url)
                }
            }
        }
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                addFile(url: url)
            }
        case .failure(let error):
            print("File picker error: \(error)")
        }
    }

    private func addFile(url: URL) {
        let file = WatchedFileDisplay(
            id: UUID(),
            url: url,
            filename: url.lastPathComponent,
            fileExtension: url.pathExtension,
            size: getFileSize(url),
            product: selectedProduct == "Auto-detect" ? inferProduct(url) : selectedProduct,
            status: .pending,
            addedDate: Date()
        )
        watchedFiles.append(file)

        // Trigger indexing
        Task {
            await indexFile(file)
        }
    }

    private func indexFile(_ file: WatchedFileDisplay) async {
        // Update status
        if let index = watchedFiles.firstIndex(where: { $0.id == file.id }) {
            watchedFiles[index].status = .indexing
        }

        // Simulate indexing
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Update status
        if let index = watchedFiles.firstIndex(where: { $0.id == file.id }) {
            watchedFiles[index].status = .indexed
            watchedFiles[index].chunkCount = Int.random(in: 10...100)
        }
    }

    private func reindexFile(_ file: WatchedFileDisplay) {
        Task {
            await indexFile(file)
        }
    }

    private func deleteFile(_ file: WatchedFileDisplay) {
        watchedFiles.removeAll { $0.id == file.id }
    }

    private func openWatchFolder() {
        let watchPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("vmDocs")

        // Create if doesn't exist
        try? FileManager.default.createDirectory(at: watchPath, withIntermediateDirectories: true)

        NSWorkspace.shared.open(watchPath)
    }

    private func loadWatchedFiles() {
        // Load from watch folder
        isScanning = true

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isScanning = false
        }
    }

    private func getFileSize(_ url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return "Unknown"
    }

    private func inferProduct(_ url: URL) -> String {
        let filename = url.lastPathComponent.lowercased()

        let patterns: [(String, String)] = [
            ("vsphere", "vSphere"),
            ("vcenter", "vCenter"),
            ("vsan", "vSAN"),
            ("nsx", "NSX"),
            ("tanzu", "Tanzu"),
            ("aria", "Aria"),
            ("vcf", "Cloud Foundation"),
            ("cloud-foundation", "Cloud Foundation")
        ]

        for (pattern, product) in patterns {
            if filename.contains(pattern) {
                return product
            }
        }

        return "General"
    }
}

// MARK: - Supporting Views

struct WatchedFileRow: View {
    let file: WatchedFileDisplay
    let onReindex: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: iconForExtension(file.fileExtension))
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.product)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())

                    Text(file.size)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let chunks = file.chunkCount {
                        Text("\(chunks) chunks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Status
            statusView

            // Actions
            Menu {
                Button("Re-index", action: onReindex)
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                }
                Divider()
                Button("Remove", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var statusView: some View {
        switch file.status {
        case .pending:
            Label("Pending", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .indexing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Indexing...")
                    .font(.caption)
            }
            .foregroundStyle(.blue)
        case .indexed:
            Label("Indexed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.text.fill"
        case "html", "htm": return "globe"
        case "md": return "text.badge.checkmark"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }
}

struct SuggestedDocButton: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 80)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Display Models

struct WatchedFileDisplay: Identifiable {
    let id: UUID
    let url: URL
    let filename: String
    let fileExtension: String
    let size: String
    var product: String
    var status: FileStatus
    var chunkCount: Int?
    let addedDate: Date

    enum FileStatus {
        case pending
        case indexing
        case indexed
        case failed
    }
}

#Preview {
    WatchFolderView()
        .environment(AppState())
        .frame(width: 800, height: 600)
}
