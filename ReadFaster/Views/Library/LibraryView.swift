import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Book.lastOpened, order: .reverse), SortDescriptor(\Book.dateAdded, order: .reverse)])
    private var books: [Book]

    @Binding var selectedBook: Book?
    @Binding var showingImport: Bool

    var body: some View {
        Group {
            if books.isEmpty {
                emptyLibraryView
            } else {
                libraryGrid
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Label("Import", systemImage: "plus")
                }
            }
        }
    }

    private var emptyLibraryView: some View {
        ContentUnavailableView {
            Label("No Books", systemImage: "books.vertical")
        } description: {
            Text("Import an EPUB, PDF, or text file to get started.")
        } actions: {
            Button("Import Book") {
                showingImport = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180))], spacing: 20) {
                ForEach(books) { book in
                    BookCard(book: book)
                        .onTapGesture {
                            selectedBook = book
                        }
                        .contextMenu {
                            Button {
                                selectedBook = book
                            } label: {
                                Label("Read", systemImage: "book")
                            }

                            Divider()

                            Button(role: .destructive) {
                                deleteBook(book)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    private func deleteBook(_ book: Book) {
        withAnimation {
            modelContext.delete(book)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView(selectedBook: .constant(nil), showingImport: .constant(false))
    }
    .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self], inMemory: true)
}
