import SwiftUI

/// Displays the current sentence with the active word highlighted
/// Features a smoothly animating underline that moves between words
struct SentenceContextView: View {
    let words: [String]
    let currentWordIndex: Int
    
    @State private var wordFrames: [Int: CGRect] = [:]
    @Namespace private var animation
    
    var body: some View {
        if words.isEmpty {
            EmptyView()
        } else {
            ZStack(alignment: .topLeading) {
                // Words
                ParagraphFlowLayout(spacing: 5, lineSpacing: 12) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        wordView(word: word, index: index)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: WordFramePreference.self,
                                        value: [index: geo.frame(in: .named("sentenceContainer"))]
                                    )
                                }
                            )
                    }
                }
                
                // Animated underline
                if let frame = wordFrames[currentWordIndex] {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: frame.width, height: 2)
                        .offset(x: frame.minX, y: frame.maxY + 1)
                        .animation(.easeOut(duration: 0.15), value: currentWordIndex)
                }
            }
            .coordinateSpace(name: "sentenceContainer")
            .onPreferenceChange(WordFramePreference.self) { frames in
                wordFrames = frames
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
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
        if isCurrent {
            return .primary
        } else if isPast {
            return .primary.opacity(0.5)
        } else {
            return .primary.opacity(0.35)
        }
    }
}

// MARK: - Preference Key for tracking word positions

struct WordFramePreference: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Flow Layout

/// A flow layout optimized for paragraph-like text display
struct ParagraphFlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 12
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var lineWidths: [CGFloat] = []
        var lineStartIndices: [Int] = [0]
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                lineWidths.append(currentLineWidth - spacing)
                lineStartIndices.append(index)
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
                currentLineWidth = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            currentLineWidth = currentX
            lineHeight = max(lineHeight, size.height)
        }
        
        // Don't forget the last line
        lineWidths.append(currentLineWidth - spacing)
        
        let totalHeight = currentY + lineHeight
        
        // Center each line horizontally
        for (lineIndex, startIndex) in lineStartIndices.enumerated() {
            let endIndex = lineIndex + 1 < lineStartIndices.count ? lineStartIndices[lineIndex + 1] : positions.count
            let lineWidth = lineWidths[lineIndex]
            let horizontalOffset = max(0, (maxWidth - lineWidth) / 2)
            
            for i in startIndex..<endIndex {
                positions[i].x += horizontalOffset
            }
        }
        
        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }
    
    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}

// MARK: - Preview

#Preview("Animated underline") {
    struct PreviewWrapper: View {
        @State private var index = 5
        let words = ["The", "quick", "brown", "fox", "jumps", "over", "the", "lazy", "dog."]
        
        var body: some View {
            VStack(spacing: 30) {
                SentenceContextView(words: words, currentWordIndex: index)
                    .frame(maxHeight: 100)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 400)
                
                HStack {
                    Button("Previous") { 
                        if index > 0 { index -= 1 }
                    }
                    Button("Next") { 
                        if index < words.count - 1 { index += 1 }
                    }
                }
            }
            .padding()
        }
    }
    return PreviewWrapper()
}

#Preview("Long sentence") {
    SentenceContextView(
        words: ["System", "Architecture", "A", "system's", "architecture", "is", "a", "representation", "of", "a", "system", "in", "which", "there", "is", "a", "mapping", "of", "the", "software", "architecture", "onto", "the", "hardware", "architecture."],
        currentWordIndex: 18
    )
    .frame(maxHeight: 150)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .frame(maxWidth: 600)
    .padding()
}
