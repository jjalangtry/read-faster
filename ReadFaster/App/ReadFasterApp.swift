import SwiftUI
import SwiftData

@main
struct ReadFasterApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Book.self,
                ReadingProgress.self,
                Bookmark.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Book...") {
                    NotificationCenter.default.post(
                        name: .importBook,
                        object: nil
                    )
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

extension Notification.Name {
    static let importBook = Notification.Name("importBook")
}
