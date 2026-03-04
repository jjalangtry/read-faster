import SwiftUI

struct WordDisplay: View {
    let word: String
    var usesChunkLayout: Bool = false

    @AppStorage("fontSize") private var fontSize: Double = 48
    @State private var animate = false

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !usesChunkLayout {
                singleWordView
            } else {
                chunkHighlightedView
                    .font(AppFont.rsvpPhrase(size: max(30, fontSize * 0.72)))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
        .frame(minHeight: 180)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .accessibilityElement()
        .accessibilityLabel(word)
        .accessibilityHint(usesChunkLayout
                           ? "Current phrase in chunk reading mode"
                           : "Current word in RSVP reader")
        .onChange(of: word) { _, _ in
            animate = false
            withAnimation(.easeOut(duration: 0.06)) { animate = true }
        }
    }

    // MARK: - Single Word (no guide lines — glass card is the boundary)

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

    @ViewBuilder
    private var chunkHighlightedView: some View {
        let parts = chunkDisplayParts
        if let focal = parts.anchor.focal {
            HStack(spacing: 0) {
                Text(parts.leadingText)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                Text(String(focal))
                    .foregroundStyle(.red)
                Text(parts.trailingText)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        } else {
            Text(parts.before + parts.anchor.fullWord + parts.after)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
        }
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
