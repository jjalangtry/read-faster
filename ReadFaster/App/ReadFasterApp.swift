import SwiftUI
import SwiftData

@main
struct ReadFasterApp: App {
    let modelContainer: ModelContainer

    init() {
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
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // If migration fails, try to delete and recreate
            print("ModelContainer error: \(error)")
            print("Attempting to recreate database...")
            
            // Get the default store URL and delete it
            if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = url.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                // Also try removing the .sqlite files SwiftData might create
                let sqliteURL = url.appendingPathComponent("default.sqlite")
                try? FileManager.default.removeItem(at: sqliteURL)
            }
            
            // Try again with fresh database
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
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
