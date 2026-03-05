import SwiftUI

struct SentenceContextView: View {
    let allBookWords: [String]
    let globalWordIndex: Int

    private let contextWindow = 120

    private var displayRange: Range<Int> {
        let start = max(0, globalWordIndex - contextWindow)
        let end = min(allBookWords.count, globalWordIndex + contextWindow)
        return start..<end
    }

    private var localIndex: Int {
        globalWordIndex - displayRange.lowerBound
    }

    var body: some View {
        if allBookWords.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        wordFlow

                        underline
                    }
                    .coordinateSpace(name: "ctx")
                    .onPreferenceChange(WordFramePreference.self) { val in
                        frames = val
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                }
                .onChange(of: globalWordIndex) { _, _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(localIndex, anchor: .center)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(localIndex, anchor: .center)
                    }
                }
            }
        }
    }

    @State private var frames: [Int: CGRect] = [:]

    private var wordFlow: some View {
        ParagraphFlowLayout(spacing: 5, lineSpacing: 10) {
            ForEach(
                Array(allBookWords[displayRange].enumerated()),
                id: \.offset
            ) { index, word in
                Text(word)
                    .id(index)
                    .font(AppFont.contextWord(highlighted: false))
                    .foregroundColor(
                        index == localIndex
                            ? Color.primary
                            : index < localIndex
                                ? Color.primary.opacity(0.5)
                                : Color.primary.opacity(0.35)
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: WordFramePreference.self,
                                value: [index: geo.frame(in: .named("ctx"))]
                            )
                        }
                    )
            }
        }
    }

    @ViewBuilder
    private var underline: some View {
        if let frame = frames[localIndex] {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: frame.width, height: 2)
                .offset(x: frame.minX, y: frame.maxY + 1)
                .animation(.easeInOut(duration: 0.25), value: localIndex)
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
        for (idx, pos) in result.positions.enumerated() {
            subviews[idx].place(
                at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                proposal: ProposedViewSize(result.sizes[idx])
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> LayoutResult {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var lineWidths: [CGFloat] = []
        var lineStarts: [Int] = [0]
        var curX: CGFloat = 0
        var curY: CGFloat = 0
        var lineH: CGFloat = 0
        var curLW: CGFloat = 0

        for (idx, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            sizes.append(size)
            if curX + size.width > maxW && curX > 0 {
                lineWidths.append(curLW - spacing)
                lineStarts.append(idx)
                curX = 0; curY += lineH + lineSpacing
                lineH = 0; curLW = 0
            }
            positions.append(CGPoint(x: curX, y: curY))
            curX += size.width + spacing
            curLW = curX
            lineH = max(lineH, size.height)
        }
        lineWidths.append(curLW - spacing)

        for (lineIdx, startIdx) in lineStarts.enumerated() {
            let endIdx = lineIdx + 1 < lineStarts.count
                ? lineStarts[lineIdx + 1] : positions.count
            let off = max(0, (maxW - lineWidths[lineIdx]) / 2)
            for idx in startIdx..<endIdx { positions[idx].x += off }
        }

        return LayoutResult(
            size: CGSize(width: maxW, height: curY + lineH),
            positions: positions, sizes: sizes
        )
    }

    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
