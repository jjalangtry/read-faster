import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    quickImportCard

                    if isProcessing {
                        progressSection
                    }

                    supportedFormatsInfo
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bring in a file or any link")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Paste an article URL, share a link from another app, or import a local document.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickImportCard: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 46, height: 46)

                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Import")
                            .font(.headline)

                        Text("Files, pasted links, and share-sheet links all land in the same library.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                browseFilesRow

                Divider()

                linkImportSection
            }
            .frame(maxWidth: .infinity)
            .padding(24)
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

    private var browseFilesRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse local files")
                    .font(.headline)

                Text("EPUB, PDF, and plain text are supported. You can also drop a file onto this card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button("Browse Files") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isProcessing)
        }
    }

    private var linkImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import from link")
                    .font(.headline)

                Text("Paste `example.com/article` or a full `https://` link.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            remoteURLField

            HStack(spacing: 12) {
                Button {
                    Task {
                        await importRemoteLink()
                    }
                } label: {
                    Label("Import Link", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing || normalizedRemoteURLInput.isEmpty)

                #if os(iOS)
                Button {
                    remoteURL = UIPasteboard.general.string ?? remoteURL
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
                #endif
            }

            Text("No scheme needed. If you omit it, Read Faster uses `https://`.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField("example.com/article", text: $remoteURL)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08))
        )
        #else
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField("example.com/article", text: $remoteURL)
                .disabled(isProcessing)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task {
                        await importRemoteLink()
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08))
        )
        #endif
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text(processingMessage)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.regularMaterial)
        )
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
        let rawURL = normalizedRemoteURLInput
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

    private var normalizedRemoteURLInput: String {
        remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
