import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var isProcessing = false
    @State private var processingMessage = "Importing..."
    @State private var isDragOver = false
    @State private var remoteURL = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                dropZone

                linkImportSection

                if isProcessing {
                    progressSection
                }

                supportedFormatsInfo

                Spacer()
            }
            .padding()
            .navigationTitle("Import Book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error occurred")
            }
        }
    }

    private var dropZone: some View {
        GlassEffectContainer {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(isDragOver ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isDragOver)

                VStack(spacing: 8) {
                    Text("Drop a file here")
                        .font(.title3)
                        .fontWeight(.medium)

                    Text("or")
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporting = true
                } label: {
                    Text("Browse Files")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing)
            }
            .frame(maxWidth: .infinity)
            .padding(48)
            .glassEffect(
                isDragOver ? .regular.tint(.accentColor) : .regular,
                in: RoundedRectangle(cornerRadius: 24)
            )
        }
        .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
            guard !isProcessing else { return false }
            handleDrop(providers)
            return true
        }
    }

    private var linkImportSection: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Import from Link", systemImage: "link")
                        .font(.headline)

                    Text("Paste a web article, PDF, EPUB, or text URL.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                remoteURLField

                Button {
                    Task {
                        await importRemoteLink()
                    }
                } label: {
                    Label("Import Link", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing || remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var supportedFormatsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Formats")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    FormatBadge(icon: "book.closed", label: "EPUB", description: "Best quality")
                    FormatBadge(icon: "doc.richtext", label: "PDF", description: "With OCR")
                    FormatBadge(icon: "doc.text", label: "TXT", description: "Plain text")
                    FormatBadge(icon: "link", label: "Web", description: "Article text")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var remoteURLField: some View {
        #if os(iOS)
        TextField("https://example.com/article", text: $remoteURL)
            .textFieldStyle(.roundedBorder)
            .disabled(isProcessing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .submitLabel(.go)
            .onSubmit {
                Task {
                    await importRemoteLink()
                }
            }
        #else
        TextField("https://example.com/article", text: $remoteURL)
            .textFieldStyle(.roundedBorder)
            .disabled(isProcessing)
            .onSubmit {
                Task {
                    await importRemoteLink()
                }
            }
        #endif
    }

    private var progressSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(processingMessage)
                .font(.headline)
        }
        .padding()
    }

    private var supportedTypes: [UTType] {
        [.epub, .pdf, .plainText, .text]
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        for type in supportedTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                    if let url = url {
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(url.lastPathComponent)

                        try? FileManager.default.removeItem(at: tempURL)
                        try? FileManager.default.copyItem(at: url, to: tempURL)

                        Task { @MainActor in
                            await importFile(from: tempURL)
                        }
                    }
                }
                break
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importFile(from: url)
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }

    private func importFile(from url: URL) async {
        isProcessing = true
        processingMessage = "Importing file..."
        defer { isProcessing = false }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let storage = StorageService(modelContext: modelContext)
            _ = try await storage.importBook(from: url)

            dismiss()
        } catch {
            importError = error.localizedDescription
            showingError = true
        }
    }

    private func importRemoteLink() async {
        let rawURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty else { return }

        isProcessing = true
        processingMessage = "Fetching link..."
        defer { isProcessing = false }

        do {
            let storage = StorageService(modelContext: modelContext)
            _ = try await storage.importBook(fromRemoteURLString: rawURL)
            dismiss()
        } catch {
            importError = error.localizedDescription
            showingError = true
        }
    }
}

struct FormatBadge: View {
    let icon: String
    let label: String
    let description: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(label)
                .font(.caption)
                .fontWeight(.semibold)

            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}

#Preview {
    ImportView()
        .modelContainer(for: [Book.self], inMemory: true)
}
