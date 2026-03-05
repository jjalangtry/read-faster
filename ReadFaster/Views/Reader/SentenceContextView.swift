import SwiftUI

struct SentenceContextView: View {
    let words: [String]
    let currentWordIndex: Int
    let allBookWords: [String]
    let globalWordIndex: Int

    init(
        words: [String],
        currentWordIndex: Int,
        allBookWords: [String] = [],
        globalWordIndex: Int = 0
    ) {
        self.words = words
        self.currentWordIndex = currentWordIndex
        self.allBookWords = allBookWords
        self.globalWordIndex = globalWordIndex
    }

    private var displayWords: [String] {
        guard !allBookWords.isEmpty else { return words }
        let window = 80
        let start = max(0, globalWordIndex - window)
        let end = min(allBookWords.count, globalWordIndex + window)
        return Array(allBookWords[start..<end])
    }

    private var adjustedIndex: Int {
        guard !allBookWords.isEmpty else { return currentWordIndex }
        let window = 80
        let start = max(0, globalWordIndex - window)
        return globalWordIndex - start
    }

    var body: some View {
        if displayWords.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    flowContent
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .onChange(of: adjustedIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(adjustedIndex, anchor: .center)
                }
            }
            .frame(height: 100)
        }
    }

    private var flowContent: some View {
        ParagraphFlowLayout(spacing: 5, lineSpacing: 8) {
            ForEach(
                Array(displayWords.enumerated()), id: \.offset
            ) { index, word in
                let isCurrent = index == adjustedIndex
                let isPast = index < adjustedIndex

                Text(word)
                    .id(index)
                    .font(AppFont.contextWord(highlighted: isCurrent))
                    .foregroundColor(
                        isCurrent ? Color.primary
                            : isPast ? Color.primary.opacity(0.45)
                            : Color.primary.opacity(0.3)
                    )
            }
        }
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
    var lineSpacing: CGFloat = 8

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
