import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case library
    case search
    case settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .library
    @State private var selectedBook: Book?
    @State private var showingImport = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical", value: .library) {
                NavigationStack(path: $navigationPath) {
                    LibraryView(
                        selectedBook: $selectedBook,
                        showingImport: $showingImport
                    )
                    .navigationDestination(for: Book.self) { book in
                        RSVPView(book: book)
                    }
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                NavigationStack {
                    SearchResultsView(searchText: $searchText)
                }
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search your library")
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .sheet(isPresented: $showingImport) {
            ImportView()
        }
        .onChange(of: selectedBook) { _, newBook in
            if let book = newBook {
                navigationPath.append(book)
                selectedBook = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importBook)) { _ in
            showingImport = true
        }
    }
}

struct SearchResultsView: View {
    @Binding var searchText: String
    @Query private var books: [Book]

    private var filteredBooks: [Book] {
        guard !searchText.isEmpty else { return [] }
        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Search Your Library",
                    systemImage: "magnifyingglass",
                    description: Text("Find books by title or author")
                )
            } else if filteredBooks.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredBooks) { book in
                    NavigationLink(value: book) {
                        BookSearchRow(book: book)
                    }
                }
                .navigationDestination(for: Book.self) { book in
                    RSVPView(book: book)
                }
            }
        }
        .navigationTitle("Search")
    }
}

struct BookSearchRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = book.coverImage {
                #if os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                #else
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                #endif
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 60)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)

                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(book.percentComplete))% complete")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self], inMemory: true)
}
