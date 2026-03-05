import SwiftUI

struct SentenceContextView: View {
    let allBookWords: [String]
    let globalWordIndex: Int
    var highlightCount: Int = 1

    private let contextWindow = 150

    private var displayRange: Range<Int> {
        let start = max(0, globalWordIndex - contextWindow)
        let end = min(allBookWords.count, globalWordIndex + contextWindow)
        return start..<end
    }

    private var localIndex: Int {
        globalWordIndex - displayRange.lowerBound
    }

    private var highlightedIndices: Set<Int> {
        let count = min(highlightCount, displayRange.count - localIndex)
        return Set(localIndex..<(localIndex + count))
    }

    @State private var frames: [Int: CGRect] = [:]
    @State private var lastScrolledLine: CGFloat = 0

    var body: some View {
        if allBookWords.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        textFlow
                        underlines
                    }
                    .coordinateSpace(name: "ctx")
                    .onPreferenceChange(WordFramePreference.self) { val in
                        frames = val
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .scrollDisabled(true)
                .onChange(of: globalWordIndex) { _, _ in
                    scrollIfNeeded(proxy)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(localIndex, anchor: .center)
                    }
                }
            }
        }
    }

    private func scrollIfNeeded(_ proxy: ScrollViewProxy) {
        guard let frame = frames[localIndex] else { return }
        let lineY = frame.minY
        if lineY != lastScrolledLine {
            lastScrolledLine = lineY
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(localIndex, anchor: .center)
            }
        }
    }

    private var textFlow: some View {
        ContextFlowLayout(spacing: 5, lineSpacing: 10) {
            ForEach(
                Array(allBookWords[displayRange].enumerated()),
                id: \.offset
            ) { index, word in
                Text(word)
                    .id(index)
                    .font(AppFont.contextWord(highlighted: false))
                    .foregroundColor(
                        highlightedIndices.contains(index)
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
    private var underlines: some View {
        ForEach(Array(highlightedIndices.sorted()), id: \.self) { idx in
            if let frame = frames[idx] {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: frame.width, height: 2)
                    .offset(x: frame.minX, y: frame.maxY + 1)
                    .animation(
                        .easeInOut(duration: 0.2), value: globalWordIndex
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

// MARK: - Left-aligned flow layout (no centering — like source text)

struct ContextFlowLayout: Layout {
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
        var curX: CGFloat = 0
        var curY: CGFloat = 0
        var lineH: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            sizes.append(size)
            if curX + size.width > maxW && curX > 0 {
                curX = 0
                curY += lineH + lineSpacing
                lineH = 0
            }
            positions.append(CGPoint(x: curX, y: curY))
            curX += size.width + spacing
            lineH = max(lineH, size.height)
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
