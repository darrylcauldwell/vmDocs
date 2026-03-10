import SwiftUI
import SwiftData

@main
struct vmDocsApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StoredDocument.self,
            StoredChunk.self,
            StoredConversation.self,
            StoredMessage.self,
            StoredBookmark.self,
            ScraperProgress.self,
            AppSettings.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    appState.startNewChat()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Chat") {
                Button("Clear History") {
                    appState.clearChatHistory()
                }

                Divider()

                Button("Export Conversation...") {
                    appState.exportConversation()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandMenu("Library") {
                Button("Import Documents...") {
                    appState.showImportSheet = true
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Start Web Scraper...") {
                    appState.showScraperSheet = true
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Refresh Index") {
                    Task {
                        await appState.refreshIndex()
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
        }
    }
}
