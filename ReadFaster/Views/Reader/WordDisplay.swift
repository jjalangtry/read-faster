import SwiftUI

struct WordDisplay: View {
    let word: String
    var usesChunkLayout: Bool = false

    @AppStorage("fontSize") private var fontSize: Double = 48

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 12) {
            if !usesChunkLayout {
                // Guide line above
                guideLine

                // Word display with ORP highlight
                HStack(spacing: 0) {
                    // Before ORP (right-aligned to the focal point)
                    Text(orpWord.before)
                        .foregroundStyle(.primary)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

                    // Focal character (red) - visual anchor point
                    if let focal = orpWord.focal {
                        Text(String(focal))
                            .foregroundStyle(.red)
                    }

                    // After ORP (left-aligned from focal point)
                    Text(orpWord.after)
                        .foregroundStyle(.primary)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .font(AppFont.rsvpWord(size: fontSize))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

                // Guide line below with focal indicator
                ZStack {
                    guideLine

                    // Focal point indicator - red triangle pointing up
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(180))
                        .offset(y: -6)
                }
            } else {
                // 3-word chunk mode still preserves ORP-style focal highlight.
                chunkHighlightedView
                    .font(AppFont.rsvpPhrase(size: max(30, fontSize * 0.72)))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .frame(minHeight: 170)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .accessibilityElement()
        .accessibilityLabel(word)
        .accessibilityHint(usesChunkLayout ? "Current phrase in chunk reading mode" : "Current word in RSVP reader")
    }

    private var guideLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 1)
    }

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
            return ChunkDisplayParts(before: "", anchor: ORPWord(word: ""), after: "")
        }

        let anchorIndex = words.count >= 2 ? 1 : 0
        let beforeWords = words.prefix(anchorIndex).joined(separator: " ")
        let afterWords = words.dropFirst(anchorIndex + 1).joined(separator: " ")
        let anchorWord = ORPWord(word: words[anchorIndex])

        let before = beforeWords.isEmpty ? "" : beforeWords + " "
        let after = afterWords.isEmpty ? "" : " " + afterWords
        return ChunkDisplayParts(before: before, anchor: anchorWord, after: after)
    }

    private struct ChunkDisplayParts {
        let before: String
        let anchor: ORPWord
        let after: String

        var leadingText: String {
            before + anchor.before
        }

        var trailingText: String {
            anchor.after + after
        }
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

#Preview("Long word") {
    VStack(spacing: 40) {
        WordDisplay(word: "recognition")
        WordDisplay(word: "extraordinary")
        WordDisplay(word: "supercalifragilisticexpialidocious")
    }
    .padding()
}

#Preview("Empty") {
    WordDisplay(word: "")
        .padding()
}

#Preview("Phrase mode") {
    WordDisplay(word: "the quick brown", usesChunkLayout: true)
        .padding()
}
