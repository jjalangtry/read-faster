import SwiftUI

struct WordDisplay: View {
    let word: String
    var usesChunkLayout: Bool = false

    @AppStorage("fontSize") private var fontSize: Double = 48

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !usesChunkLayout {
                singleWordView
            } else {
                chunkView
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
        .frame(minHeight: 180)
        .clipped()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .accessibilityElement()
        .accessibilityLabel(word)
    }

    // MARK: - Single Word (HStack centering keeps focal in center)

    private var singleWordView: some View {
        HStack(spacing: 0) {
            Text(orpWord.before)
                .foregroundStyle(.primary)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

            if let focal = orpWord.focal {
                Text(String(focal))
                    .foregroundStyle(.red)
            }

            Text(orpWord.after)
                .foregroundStyle(.primary)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .font(AppFont.rsvpWord(size: fontSize))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    // MARK: - Chunk Mode (uniform scale, then offset to center focal)

    @State private var focalOffset: CGFloat = 0

    private var chunkView: some View {
        let parts = chunkDisplayParts
        let chunkFont = AppFont.rsvpPhrase(size: max(30, fontSize * 0.72))

        return GeometryReader { containerGeo in
            let containerCenter = containerGeo.size.width / 2

            HStack(spacing: 0) {
                Text(parts.leadingText)
                    .foregroundColor(.primary)

                if let focal = parts.anchor.focal {
                    Text(String(focal))
                        .foregroundColor(.red)
                        .background(
                            GeometryReader { focalGeo in
                                Color.clear.onAppear {
                                    let focalCenter = focalGeo.frame(
                                        in: .named("chunkContainer")
                                    ).midX
                                    focalOffset = containerCenter - focalCenter
                                }
                                .onChange(of: word) { _, _ in
                                    DispatchQueue.main.async {
                                        let focalCenter = focalGeo.frame(
                                            in: .named("chunkContainer")
                                        ).midX
                                        focalOffset = containerCenter
                                            - focalCenter
                                    }
                                }
                            }
                        )
                }

                Text(parts.trailingText)
                    .foregroundColor(.primary)
            }
            .font(chunkFont)
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            .fixedSize()
            .offset(x: focalOffset)
            .frame(
                width: containerGeo.size.width,
                height: containerGeo.size.height,
                alignment: .center
            )
            .coordinateSpace(name: "chunkContainer")
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }

    private var chunkDisplayParts: ChunkDisplayParts {
        let words = word.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else {
            return ChunkDisplayParts(
                before: "", anchor: ORPWord(word: ""), after: ""
            )
        }
        let anchorIndex = words.count >= 2 ? 1 : 0
        let beforeWords = words.prefix(anchorIndex).joined(separator: " ")
        let afterWords = words.dropFirst(anchorIndex + 1).joined(separator: " ")
        let anchorWord = ORPWord(word: words[anchorIndex])
        let before = beforeWords.isEmpty ? "" : beforeWords + " "
        let after = afterWords.isEmpty ? "" : " " + afterWords
        return ChunkDisplayParts(
            before: before, anchor: anchorWord, after: after
        )
    }

    private struct ChunkDisplayParts {
        let before: String
        let anchor: ORPWord
        let after: String
        var leadingText: String { before + anchor.before }
        var trailingText: String { anchor.after + after }
    }
}

#Preview("Short word") {
    VStack(spacing: 40) {
        WordDisplay(word: "I")
        WordDisplay(word: "the")
        WordDisplay(word: "word")
    }
    .padding()
}

#Preview("Phrase mode") {
    WordDisplay(word: "the quick brown", usesChunkLayout: true)
        .padding()
}
