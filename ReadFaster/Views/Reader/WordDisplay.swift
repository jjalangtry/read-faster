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

    @State private var focalLocalX: CGFloat = 0
    @State private var measuredWidth: CGFloat = 1

    private var focalIndex: Int {
        let stripped = word.filter { !$0.isWhitespace }
        guard !stripped.isEmpty else { return 0 }
        let mid = stripped.count / 2
        var nonSpaceCount = 0
        for (idx, char) in word.enumerated() {
            if !char.isWhitespace {
                if nonSpaceCount == mid { return idx }
                nonSpaceCount += 1
            }
        }
        return word.count / 2
    }

    private var chunkView: some View {
        let chars = Array(word)
        let fidx = min(focalIndex, max(0, chars.count - 1))

        guard !chars.isEmpty else {
            return AnyView(
                Text(word).font(chunkFont).frame(maxWidth: .infinity)
            )
        }

        let before = fidx > 0 ? String(chars[0..<fidx]) : ""
        let focal = String(chars[fidx])
        let after = fidx + 1 < chars.count
            ? String(chars[(fidx + 1)...]) : ""
        let shift = measuredWidth > 0
            ? measuredWidth / 2 - focalLocalX : 0

        return AnyView(
            GeometryReader { container in
                HStack(spacing: 0) {
                    Text(before).foregroundColor(.primary)
                    Text(focal).foregroundColor(.red)
                        .background(focalMeasure)
                    Text(after).foregroundColor(.primary)
                }
                .font(chunkFont)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .coordinateSpace(name: "phrase")
                .background(widthMeasure)
                .offset(x: shift)
                .frame(
                    width: container.size.width,
                    height: container.size.height,
                    alignment: .center
                )
            }
        )
    }

    private var chunkFont: Font {
        AppFont.rsvpPhrase(size: max(28, fontSize * 0.65))
    }

    private var focalMeasure: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    focalLocalX = geo.frame(in: .named("phrase")).midX
                }
                .onChange(of: word) { _, _ in
                    focalLocalX = geo.frame(in: .named("phrase")).midX
                }
        }
    }

    private var widthMeasure: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { measuredWidth = geo.size.width }
                .onChange(of: word) { _, _ in
                    measuredWidth = geo.size.width
                }
        }
    }
}

#Preview("Words") {
    VStack(spacing: 20) {
        WordDisplay(word: "recognition")
        WordDisplay(word: "the quick brown", usesChunkLayout: true)
        WordDisplay(word: "Although there was", usesChunkLayout: true)
        WordDisplay(word: "1", usesChunkLayout: true)
    }
    .padding()
}
