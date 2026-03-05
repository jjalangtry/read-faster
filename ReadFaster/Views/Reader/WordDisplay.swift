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
    @State private var textNaturalWidth: CGFloat = 1

    private var focalIndex: Int {
        let chars = Array(word)
        guard !chars.isEmpty else { return 0 }
        return chars.count / 2
    }

    private var chunkView: some View {
        let chars = Array(word)
        let fidx = focalIndex
        guard fidx < chars.count else {
            return AnyView(
                Text(word)
                    .font(chunkFont)
                    .frame(maxWidth: .infinity)
            )
        }

        let before = String(chars[0..<fidx])
        let focal = String(chars[fidx])
        let after = fidx + 1 < chars.count ? String(chars[(fidx + 1)...]) : ""
        let shift = textNaturalWidth / 2 - focalLocalX

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
                .fixedSize()
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
                .onAppear { textNaturalWidth = geo.size.width }
                .onChange(of: word) { _, _ in
                    textNaturalWidth = geo.size.width
                }
        }
    }
}

#Preview("Words") {
    VStack(spacing: 20) {
        WordDisplay(word: "recognition")
        WordDisplay(word: "the quick brown", usesChunkLayout: true)
        WordDisplay(word: "Although there was", usesChunkLayout: true)
    }
    .padding()
}
