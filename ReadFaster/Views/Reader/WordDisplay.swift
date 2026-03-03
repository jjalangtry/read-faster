import SwiftUI

struct WordDisplay: View {
    let word: String
    var showsORPHighlight: Bool = true

    @AppStorage("fontSize") private var fontSize: Double = 48

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 12) {
            if showsORPHighlight {
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
                // Phrase mode (3-word chunk) favors serif readability.
                Text(word)
                    .font(AppFont.rsvpPhrase(size: max(30, fontSize * 0.72)))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.7)
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
        .accessibilityHint(showsORPHighlight ? "Current word in RSVP reader" : "Current phrase in chunk reading mode")
    }

    private var guideLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 1)
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
    WordDisplay(word: "the quick brown", showsORPHighlight: false)
        .padding()
}
