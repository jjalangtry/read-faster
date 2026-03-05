import SwiftUI

struct WordDisplay: View {
    let word: String
    var usesChunkLayout: Bool = false

    @AppStorage("fontSize") private var fontSize: Double = 48

    private var orpWord: ORPWord { ORPWord(word: word) }
    private let boxHeight: CGFloat = 180

    var body: some View {
        Group {
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

    // MARK: - Single Word (HStack centering, ORP in center)

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

    // MARK: - Chunk Mode (uniform font, centered focal)
    // Single concatenated Text for guaranteed uniform scaling.
    // The whole phrase is centered; the red letter is always the
    // ORP of the middle word of the chunk, which is the character
    // closest to the center of the full phrase string.

    private var chunkView: some View {
        chunkText
            .font(AppFont.rsvpPhrase(size: max(28, fontSize * 0.65)))
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var chunkText: Text {
        let full = word
        let words = full.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else {
            return Text(full).foregroundColor(.primary)
        }

        let anchorIdx = words.count >= 2 ? 1 : 0
        let anchorWord = words[anchorIdx]
        let orpPos = ORPCalculator.calculate(for: anchorWord)

        var charIndex = 0
        for idx in 0..<anchorIdx {
            charIndex += words[idx].count + 1
        }
        charIndex += orpPos
        let focalGlobalIndex = charIndex

        let chars = Array(full)
        guard focalGlobalIndex < chars.count else {
            return Text(full).foregroundColor(.primary)
        }

        let before = String(chars[0..<focalGlobalIndex])
        let focal = String(chars[focalGlobalIndex])
        let after = String(chars[(focalGlobalIndex + 1)...])

        return Text(before).foregroundColor(.primary)
            + Text(focal).foregroundColor(.red)
            + Text(after).foregroundColor(.primary)
    }
}

#Preview("Words") {
    VStack(spacing: 20) {
        WordDisplay(word: "recognition")
        WordDisplay(word: "the quick brown", usesChunkLayout: true)
    }
    .padding()
}
