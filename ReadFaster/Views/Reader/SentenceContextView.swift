import SwiftUI

struct SentenceContextView: View {
    let allBookWords: [String]
    let globalWordIndex: Int
    var highlightCount: Int = 1

    private let contextWindow = 300

    private var windowStart: Int {
        max(0, globalWordIndex - contextWindow)
    }

    private var windowEnd: Int {
        min(allBookWords.count, globalWordIndex + contextWindow)
    }

    private var highlightedGlobalIndices: Set<Int> {
        let end = min(globalWordIndex + highlightCount, allBookWords.count)
        return Set(globalWordIndex..<end)
    }

    @State private var frames: [Int: CGRect] = [:]
    @State private var lastScrollLine: CGFloat = -1

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
                    .padding(.vertical, 40)
                }
                .scrollDisabled(true)
                .onChange(of: globalWordIndex) { _, _ in
                    scrollOnLineChange(proxy)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(globalWordIndex, anchor: .center)
                    }
                }
            }
        }
    }

    private func scrollOnLineChange(_ proxy: ScrollViewProxy) {
        guard let frame = frames[globalWordIndex] else {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(globalWordIndex, anchor: .center)
            }
            return
        }
        let lineY = frame.minY
        if abs(lineY - lastScrollLine) > 1 {
            lastScrollLine = lineY
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(globalWordIndex, anchor: .center)
            }
        }
    }

    private var textFlow: some View {
        ContextFlowLayout(spacing: 5, lineSpacing: 10) {
            ForEach(windowStart..<windowEnd, id: \.self) { globalIdx in
                Text(allBookWords[globalIdx])
                    .id(globalIdx)
                    .font(AppFont.contextWord(highlighted: false))
                    .foregroundColor(wordColor(for: globalIdx))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: WordFramePreference.self,
                                value: [globalIdx: geo.frame(
                                    in: .named("ctx")
                                )]
                            )
                        }
                    )
            }
        }
    }

    private func wordColor(for globalIdx: Int) -> Color {
        if highlightedGlobalIndices.contains(globalIdx) {
            return Color.primary
        }
        if globalIdx < globalWordIndex {
            return Color.primary.opacity(0.5)
        }
        return Color.primary.opacity(0.35)
    }

    @ViewBuilder
    private var underlines: some View {
        ForEach(
            Array(highlightedGlobalIndices.sorted()), id: \.self
        ) { globalIdx in
            if let frame = frames[globalIdx] {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: frame.width, height: 2)
                    .offset(x: frame.minX, y: frame.maxY + 1)
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: globalWordIndex
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

// MARK: - Left-aligned flow layout

struct ContextFlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize,
        subviews: Subviews, cache: inout ()
    ) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (idx, pos) in result.positions.enumerated() {
            subviews[idx].place(
                at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                proposal: ProposedViewSize(result.sizes[idx])
            )
        }
    }

    private func computeLayout(
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
