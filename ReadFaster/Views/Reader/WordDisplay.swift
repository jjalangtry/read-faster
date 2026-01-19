import SwiftUI

struct WordDisplay: View {
    let word: String

    @AppStorage("fontSize") private var fontSize: Double = 48
    @Environment(\.colorScheme) private var colorScheme

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 12) {
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
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .accessibilityElement()
        .accessibilityLabel(word)
        .accessibilityHint("Current word in RSVP reader")
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
