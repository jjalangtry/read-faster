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
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .accessibilityElement()
        .accessibilityLabel(word)
    }

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

    // Chunk: single concatenated Text so minimumScaleFactor shrinks
    // all characters uniformly (red letter included).
    private var chunkView: some View {
        chunkText
            .font(AppFont.rsvpPhrase(size: max(30, fontSize * 0.72)))
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            .frame(maxWidth: .infinity, minHeight: 72)
            .multilineTextAlignment(.center)
    }

    private var chunkText: Text {
        let parts = chunkDisplayParts
        guard let focal = parts.anchor.focal else {
            return Text(parts.before + parts.anchor.fullWord + parts.after)
                .foregroundColor(.primary)
        }
        return Text(parts.leadingText).foregroundColor(.primary)
            + Text(String(focal)).foregroundColor(.red)
            + Text(parts.trailingText).foregroundColor(.primary)
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
