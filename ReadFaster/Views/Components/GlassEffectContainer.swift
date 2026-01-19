import SwiftUI

/// A container view that provides consistent glass effect styling for grouped controls.
/// This is a simple wrapper that doesn't apply additional glass effects to avoid
/// performance issues and visual artifacts.
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if spacing > 0 {
            HStack(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassEffectContainer {
            HStack(spacing: 16) {
                Button("Play") {}
                    .glassEffect(.regular.interactive(), in: Circle())
                Button("Stop") {}
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        }

        GlassEffectContainer(spacing: 12) {
            Text("Item 1")
            Text("Item 2")
            Text("Item 3")
        }
    }
    .padding()
}
