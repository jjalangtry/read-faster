import SwiftUI

struct WordDisplay: View {
    let word: String
    var usesChunkLayout: Bool = false

    @AppStorage("fontSize") private var fontSize: Double = 48

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    private let boxHeight: CGFloat = 180

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
        .frame(height: boxHeight)
        .clipped()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .accessibilityElement()
        .accessibilityLabel(word)
    }

    // MARK: - Single Word

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

    // MARK: - Chunk Mode
    // HStack centering: leading gets maxWidth right-aligned,
    // trailing gets maxWidth left-aligned. The focal character
    // sits exactly at the geometric center regardless of text length.
    // Both sides use the same font; minimumScaleFactor may differ
    // slightly per side but the red letter position is always exact.

    private var chunkView: some View {
        let parts = chunkDisplayParts
        let chunkFont = AppFont.rsvpPhrase(size: max(28, fontSize * 0.65))

        return HStack(spacing: 0) {
            if let focal = parts.anchor.focal {
                Text(parts.leadingText)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

                Text(String(focal))
                    .foregroundStyle(.red)

                Text(parts.trailingText)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            } else {
                Text(parts.before + parts.anchor.fullWord + parts.after)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(chunkFont)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
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
