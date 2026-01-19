import SwiftUI

struct BookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImage
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(AppFont.headline)
                    .lineLimit(2)

                if let author = book.author {
                    Text(author)
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                progressView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let imageData = book.coverImage, let image = platformImage(from: imageData) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))

            VStack(spacing: 8) {
                Image(systemName: fileTypeIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text(book.title)
                    .font(AppFont.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fileTypeIcon: String {
        switch book.fileType {
        case .epub: return "book.closed"
        case .pdf: return "doc.richtext"
        case .txt: return "doc.text"
        }
    }

    @ViewBuilder
    private var progressView: some View {
        let percent = book.percentComplete

        HStack(spacing: 4) {
            ProgressView(value: percent, total: 100)
                .tint(percent >= 100 ? .green : .accentColor)

            Text("\(Int(percent))%")
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    #if os(macOS)
    private func platformImage(from data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
    }
    #else
    private func platformImage(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
    #endif
}

#Preview {
    BookCard(book: Book(
        title: "Sample Book with a Very Long Title That Should Wrap",
        author: "Author Name",
        fileName: "sample.epub",
        fileType: .epub,
        content: "Sample content",
        totalWords: 1000
    ))
    .frame(width: 160)
    .padding()
}
