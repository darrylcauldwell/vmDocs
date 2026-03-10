import SwiftUI

/// Onboarding flow for first-time users
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @Binding var isPresented: Bool

    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to vmDocs",
            subtitle: "Your AI-Powered VMware Documentation Assistant",
            description: "Ask questions about any VMware product in natural language and get accurate answers with source citations.",
            imageName: "bubble.left.and.bubble.right.fill",
            imageColor: .blue
        ),
        OnboardingPage(
            title: "Powered by Local AI",
            subtitle: "Private & Offline-Capable",
            description: "vmDocs uses Ollama to run AI models locally on your Mac. Your data never leaves your computer.",
            imageName: "cpu.fill",
            imageColor: .purple
        ),
        OnboardingPage(
            title: "Smart Documentation Search",
            subtitle: "Hybrid RAG Technology",
            description: "Combines semantic understanding with keyword search to find the most relevant documentation for your questions.",
            imageName: "magnifyingglass.circle.fill",
            imageColor: .green
        ),
        OnboardingPage(
            title: "Add Your Own Documents",
            subtitle: "Design Guides, Books & More",
            description: "Drop PDFs, design guides, or any VMware-related documents to enhance your knowledge base.",
            imageName: "folder.badge.plus",
            imageColor: .orange
        ),
        OnboardingPage(
            title: "Source Citations",
            subtitle: "Verify Every Answer",
            description: "Every response includes clickable source citations so you can verify information and explore further.",
            imageName: "link.circle.fill",
            imageColor: .cyan
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            // Bottom controls
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 600, height: 500)
        .background(Color(.windowBackgroundColor))
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let imageColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.imageName)
                    .font(.system(size: 48))
                    .foregroundStyle(page.imageColor)
            }

            // Text content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Spacer()
        }
        .padding(24)
    }
}

/// Setup checklist shown after onboarding
struct SetupChecklistView: View {
    @Environment(AppState.self) private var appState
    @State private var ollamaStatus: SetupStatus = .checking
    @State private var chatModelStatus: SetupStatus = .checking
    @State private var embeddingModelStatus: SetupStatus = .checking
    @State private var documentsStatus: SetupStatus = .checking

    enum SetupStatus {
        case checking
        case ready
        case notReady
        case inProgress
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Setup Checklist")
                .font(.title.bold())

            Text("Let's make sure everything is ready")
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                SetupCheckItem(
                    title: "Ollama Running",
                    description: "Local AI server",
                    status: ollamaStatus,
                    action: "Install Ollama",
                    onAction: { openOllamaWebsite() }
                )

                SetupCheckItem(
                    title: "Chat Model",
                    description: "llama3.2 or similar",
                    status: chatModelStatus,
                    action: "Pull Model",
                    onAction: { pullChatModel() }
                )

                SetupCheckItem(
                    title: "Embedding Model",
                    description: "nomic-embed-text",
                    status: embeddingModelStatus,
                    action: "Pull Model",
                    onAction: { pullEmbeddingModel() }
                )

                SetupCheckItem(
                    title: "Documentation",
                    description: "VMware docs indexed",
                    status: documentsStatus,
                    action: "Start Scraper",
                    onAction: { appState.showScraperSheet = true }
                )
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if allReady {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All set! You're ready to start asking questions.")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            Button("Refresh Status") {
                Task {
                    await checkAllStatus()
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: 450)
        .onAppear {
            Task {
                await checkAllStatus()
            }
        }
    }

    private var allReady: Bool {
        ollamaStatus == .ready &&
        chatModelStatus == .ready &&
        embeddingModelStatus == .ready &&
        documentsStatus == .ready
    }

    private func checkAllStatus() async {
        // Check Ollama
        ollamaStatus = .checking
        await appState.checkOllamaConnection()
        ollamaStatus = appState.isOllamaConnected ? .ready : .notReady

        // Check models
        if appState.isOllamaConnected {
            await appState.refreshModels()

            let models = appState.availableModels.map { $0.lowercased() }
            chatModelStatus = models.contains(where: { $0.contains("llama") || $0.contains("mistral") || $0.contains("qwen") }) ? .ready : .notReady
            embeddingModelStatus = models.contains(where: { $0.contains("nomic") || $0.contains("embed") }) ? .ready : .notReady
        } else {
            chatModelStatus = .notReady
            embeddingModelStatus = .notReady
        }

        // Check documents
        documentsStatus = appState.totalDocuments > 0 ? .ready : .notReady
    }

    private func openOllamaWebsite() {
        if let url = URL(string: "https://ollama.com") {
            NSWorkspace.shared.open(url)
        }
    }

    private func pullChatModel() {
        let command = "ollama pull llama3.2"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        // Show notification that command was copied
    }

    private func pullEmbeddingModel() {
        let command = "ollama pull nomic-embed-text"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}

struct SetupCheckItem: View {
    let title: String
    let description: String
    let status: SetupChecklistView.SetupStatus
    let action: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Group {
                switch status {
                case .checking:
                    ProgressView()
                        .scaleEffect(0.8)
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notReady:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                case .inProgress:
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(width: 24, height: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action button (only if not ready)
            if status == .notReady {
                Button(action) {
                    onAction()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Quick tips tooltip overlay
struct QuickTipsOverlay: View {
    @Binding var isPresented: Bool
    let tips: [QuickTip]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Tips")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(tips) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tip.icon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(.subheadline.bold())
                        Text(tip.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

struct QuickTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(isPresented: .constant(true))
        .environment(AppState())
}

#Preview("Setup Checklist") {
    SetupChecklistView()
        .environment(AppState())
}
