import SwiftUI
import SwiftData

/// Main chat interface with streaming responses
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        HSplitView {
            // Main chat area
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if viewModel.messages.isEmpty {
                                EmptyStateView(
                                    title: "Ask about VMware",
                                    subtitle: "Ask questions about VMware products and get answers from the documentation.",
                                    icon: "bubble.left.and.bubble.right"
                                )
                                .padding(.top, 100)
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message) { source in
                                    viewModel.showSource(source)
                                }
                                .id(message.id)
                            }

                            // Streaming indicator
                            if viewModel.isStreaming {
                                StreamingMessageView(
                                    text: viewModel.streamingText,
                                    tokensPerSecond: viewModel.tokensPerSecond
                                )
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id)
                        }
                    }
                    .onChange(of: viewModel.streamingText) { _, _ in
                        withAnimation {
                            proxy.scrollTo("streaming")
                        }
                    }
                }

                Divider()

                // Input area
                ChatInputView(
                    text: $inputText,
                    isLoading: viewModel.isStreaming,
                    onSend: {
                        Task {
                            await viewModel.sendMessage(inputText, appState: appState)
                            inputText = ""
                        }
                    },
                    onStop: {
                        viewModel.stopGeneration()
                    }
                )
                .padding()
            }

            // Context sidebar
            if viewModel.showContextSidebar {
                ContextSidebarView(
                    sources: viewModel.currentSources,
                    retrievalInfo: viewModel.lastRetrievalInfo
                )
                .frame(minWidth: 250, maxWidth: 350)
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItemGroup {
                // Product filter menu
                Menu {
                    ForEach(VMwareProduct.allCases, id: \.self) { product in
                        Toggle(product.displayName, isOn: Binding(
                            get: { appState.selectedProducts.contains(product.rawValue) },
                            set: { _ in appState.toggleProduct(product.rawValue) }
                        ))
                    }

                    Divider()

                    Button("Clear All") {
                        appState.clearFilters()
                    }
                } label: {
                    Label("Filter Products", systemImage: "line.3.horizontal.decrease.circle")
                }

                // Toggle context sidebar
                Button {
                    withAnimation {
                        viewModel.showContextSidebar.toggle()
                    }
                } label: {
                    Label("Sources", systemImage: viewModel.showContextSidebar ? "sidebar.right" : "sidebar.left")
                }

                // New chat
                Button {
                    viewModel.startNewChat()
                    appState.startNewChat()
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
            }
        }
    }
}

/// Chat input area
struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            TextField("Ask about VMware documentation...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit {
                    if !text.isEmpty && !isLoading {
                        onSend()
                    }
                }

            // Send/Stop button
            if isLoading {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(text.isEmpty ? .gray : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
            }
        }
    }
}

/// Message bubble view
struct MessageBubbleView: View {
    let message: ChatMessageDisplay
    let onSourceTap: (SourceDisplay) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(message.isUser ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: message.isUser ? "person.fill" : "cpu")
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                }

            VStack(alignment: .leading, spacing: 8) {
                // Role label
                Text(message.isUser ? "You" : "VMware Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Content
                Text(message.content)
                    .textSelection(.enabled)

                // Source citations
                if !message.sources.isEmpty {
                    SourceCitationsView(sources: message.sources, onTap: onSourceTap)
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

/// Streaming message indicator
struct StreamingMessageView: View {
    let text: String
    let tokensPerSecond: Double

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.green)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "cpu")
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("VMware Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if text.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Thinking...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(text)
                        .textSelection(.enabled)
                }

                if tokensPerSecond > 0 {
                    Text("\(tokensPerSecond, specifier: "%.1f") tokens/sec")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

/// Source citations row with clickable links
struct SourceCitationsView: View {
    let sources: [SourceDisplay]
    let onTap: (SourceDisplay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption)
                Text("Sources")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)

            // Source cards with links
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sources) { source in
                    SourceCitationCard(source: source, onTap: { onTap(source) })
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Individual source citation card with link
struct SourceCitationCard: View {
    let source: SourceDisplay
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with reference number and product
            HStack(spacing: 6) {
                Text("[\(source.referenceNumber)]")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(source.product)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(Capsule())

                if let version = source.version {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Title (clickable)
            Button(action: onTap) {
                Text(source.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .underline(isHovering)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            // Section title if available
            if let section = source.sectionTitle {
                Text(section)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // URL link
            if let url = source.url {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                        Text(url.host ?? url.absoluteString)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Inline citation badge for embedding in text
struct InlineCitationBadge: View {
    let number: Int
    let url: URL?

    var body: some View {
        Group {
            if let url = url {
                Link(destination: url) {
                    citationLabel
                }
            } else {
                citationLabel
            }
        }
    }

    private var citationLabel: some View {
        Text("[\(number)]")
            .font(.caption.bold())
            .foregroundStyle(Color.accentColor)
            .baselineOffset(4)
    }
}

/// Context sidebar showing sources and retrieval info
struct ContextSidebarView: View {
    let sources: [SourceDisplay]
    let retrievalInfo: RetrievalInfoDisplay?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sources")
                .font(.headline)
                .padding()

            Divider()

            if sources.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No sources yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("[\(source.referenceNumber)]")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                            Text(source.product)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.controlBackgroundColor))
                                .clipShape(Capsule())
                        }

                        Text(source.title)
                            .font(.subheadline.bold())

                        if let section = source.sectionTitle {
                            Text(section)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let url = source.url {
                            Link(destination: url) {
                                Text("Open in browser")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

            if let info = retrievalInfo {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Retrieval")
                        .font(.caption.bold())
                    Text("\(info.chunksUsed) of \(info.chunksAvailable) chunks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(info.retrievalTimeMs)ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .background(Color(.controlBackgroundColor))
    }
}

/// Empty state view
struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Display Models

struct ChatMessageDisplay: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let sources: [SourceDisplay]
}

struct SourceDisplay: Identifiable {
    let id: UUID
    let referenceNumber: Int
    let title: String
    let product: String
    let version: String?
    let url: URL?
    let sectionTitle: String?
}

struct RetrievalInfoDisplay {
    let chunksUsed: Int
    let chunksAvailable: Int
    let retrievalTimeMs: Int
}

#Preview {
    ChatView()
        .environment(AppState())
}
