import SwiftUI

/// Displays the current sentence with the active word highlighted
/// Uses a fixed height to prevent layout shifts in the reading view
struct SentenceContextView: View {
    let words: [String]
    let currentWordIndex: Int
    
    /// Fixed height for the context area (accommodates ~2-3 lines)
    private let fixedHeight: CGFloat = 72
    
    var body: some View {
        if words.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                                wordView(word: word, index: index)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(minWidth: geometry.size.width)
                    }
                    .onChange(of: currentWordIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(currentWordIndex, anchor: .center)
                    }
                }
            }
            .frame(height: fixedHeight)
            .mask(horizontalFadeMask)
        }
    }
    
    /// Gradient mask for smooth fade at edges
    private var horizontalFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
            
            Color.black
            
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
        }
    }
    
    @ViewBuilder
    private func wordView(word: String, index: Int) -> some View {
        let isCurrent = index == currentWordIndex
        let isPast = index < currentWordIndex
        
        Text(word)
            .font(.system(size: isCurrent ? 18 : 15, weight: isCurrent ? .semibold : .regular))
            .foregroundStyle(wordColor(isCurrent: isCurrent, isPast: isPast))
            .padding(.horizontal, isCurrent ? 12 : 4)
            .padding(.vertical, isCurrent ? 8 : 4)
            .background {
                if isCurrent {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .animation(.easeOut(duration: 0.15), value: isCurrent)
    }
    
    private func wordColor(isCurrent: Bool, isPast: Bool) -> Color {
        if isCurrent {
            return .primary
        } else if isPast {
            return .secondary.opacity(0.5)
        } else {
            return .secondary.opacity(0.35)
        }
    }
}

// MARK: - Preview

#Preview("Short sentence") {
    VStack(spacing: 20) {
        Text("RSVP Word Here")
            .font(.largeTitle)
        
        SentenceContextView(
            words: ["The", "quick", "brown", "fox", "jumps."],
            currentWordIndex: 2
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .frame(maxWidth: 500)
}

#Preview("Long sentence") {
    VStack(spacing: 20) {
        Text("RSVP Word Here")
            .font(.largeTitle)
        
        SentenceContextView(
            words: ["In", "the", "beginning", "of", "a", "very", "long", "and", "complicated", "sentence,", "we", "find", "ourselves", "wondering", "about", "the", "nature", "of", "existence", "itself."],
            currentWordIndex: 12
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .frame(maxWidth: 500)
}

#Preview("At start") {
    SentenceContextView(
        words: ["Hello", "world!"],
        currentWordIndex: 0
    )
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
}

#Preview("At end") {
    SentenceContextView(
        words: ["This", "is", "a", "longer", "sentence", "to", "test", "scrolling", "behavior", "properly."],
        currentWordIndex: 9
    )
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
}
