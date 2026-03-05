import SwiftUI

struct SentenceContextView: View {
    let words: [String]
    let currentWordIndex: Int

    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if words.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        ParagraphFlowLayout(spacing: 5, lineSpacing: 10) {
                            ForEach(
                                Array(words.enumerated()), id: \.offset
                            ) { index, word in
                                wordView(word: word, index: index)
                                    .id(index)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: WordFramePreference.self,
                                                value: [index: geo.frame(
                                                    in: .named("ctx")
                                                )]
                                            )
                                        }
                                    )
                            }
                        }

                        if let frame = wordFrames[currentWordIndex] {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: frame.width, height: 2)
                                .offset(x: frame.minX, y: frame.maxY + 1)
                                .animation(
                                    .easeOut(duration: 0.15),
                                    value: currentWordIndex
                                )
                        }
                    }
                    .coordinateSpace(name: "ctx")
                    .onPreferenceChange(WordFramePreference.self) { frames in
                        wordFrames = frames
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                contentHeight = geo.size.height
                            }
                            .onChange(of: words.count) { _, _ in
                                contentHeight = geo.size.height
                            }
                        }
                    )
                }
                .frame(maxHeight: min(contentHeight, 120))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onChange(of: currentWordIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func wordView(word: String, index: Int) -> some View {
        let isCurrent = index == currentWordIndex
        let isPast = index < currentWordIndex

        Text(word)
            .font(AppFont.contextWord(highlighted: isCurrent))
            .foregroundStyle(wordColor(isCurrent: isCurrent, isPast: isPast))
            .animation(.easeOut(duration: 0.12), value: currentWordIndex)
    }

    private func wordColor(isCurrent: Bool, isPast: Bool) -> Color {
        if isCurrent { return .primary }
        if isPast { return .primary.opacity(0.45) }
        return .primary.opacity(0.3)
    }
}

// MARK: - Preference Key

struct WordFramePreference: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(
        value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Flow Layout

struct ParagraphFlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize,
        subviews: Subviews, cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var lineWidths: [CGFloat] = []
        var lineStartIndices: [Int] = [0]
        var curX: CGFloat = 0
        var curY: CGFloat = 0
        var lineH: CGFloat = 0
        var curLineW: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if curX + size.width > maxWidth && curX > 0 {
                lineWidths.append(curLineW - spacing)
                lineStartIndices.append(index)
                curX = 0
                curY += lineH + lineSpacing
                lineH = 0
                curLineW = 0
            }

            positions.append(CGPoint(x: curX, y: curY))
            curX += size.width + spacing
            curLineW = curX
            lineH = max(lineH, size.height)
        }

        lineWidths.append(curLineW - spacing)
        let totalHeight = curY + lineH

        for (lineIdx, startIdx) in lineStartIndices.enumerated() {
            let endIdx = lineIdx + 1 < lineStartIndices.count
                ? lineStartIndices[lineIdx + 1] : positions.count
            let lineWidth = lineWidths[lineIdx]
            let offset = max(0, (maxWidth - lineWidth) / 2)
            for idx in startIdx..<endIdx {
                positions[idx].x += offset
            }
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions, sizes: sizes
        )
    }

    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}

#Preview("Animated underline") {
    struct PreviewWrapper: View {
        @State private var index = 5
        let words = ["The", "quick", "brown", "fox", "jumps",
                     "over", "the", "lazy", "dog."]
        var body: some View {
            VStack(spacing: 30) {
                SentenceContextView(words: words, currentWordIndex: index)
                    .frame(maxWidth: 400)
                HStack {
                    Button("Prev") { if index > 0 { index -= 1 } }
                    Button("Next") { if index < words.count - 1 { index += 1 } }
                }
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
