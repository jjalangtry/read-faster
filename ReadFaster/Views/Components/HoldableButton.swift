import SwiftUI

/// A button that supports both tap and hold-to-repeat interactions.
/// - Tap: Executes `onTap` once
/// - Hold: Executes `onHoldTick` repeatedly with accelerating frequency
struct HoldableButton: View {
    let icon: String
    let onTap: () -> Void
    let onHoldTick: () -> Void
    var disabled: Bool = false
    var size: CGFloat = 52
    var iconFont: Font = .title3
    var accentedBackground: Bool = false
    
    @State private var isPressed = false
    @State private var holdTimer: Timer?
    @State private var tickCount = 0
    
    /// Initial delay before hold-repeat starts (ms)
    private let holdDelay: TimeInterval = 0.3
    /// Initial tick interval (ms)
    private let initialTickInterval: TimeInterval = 0.18
    /// Minimum tick interval after acceleration (ms)
    private let minimumTickInterval: TimeInterval = 0.06
    /// Ticks before acceleration kicks in
    private let accelerationThreshold = 5
    
    var body: some View {
        Image(systemName: icon)
            .font(iconFont)
            .foregroundStyle(disabled ? .tertiary : .primary)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .background {
                if accentedBackground {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
                } else {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !disabled, !isPressed else { return }
                        isPressed = true
                        startHoldTimer()
                    }
                    .onEnded { _ in
                        guard !disabled else { return }
                        let wasHolding = tickCount > 0
                        stopHoldTimer()
                        isPressed = false
                        
                        // Only fire tap if we weren't holding
                        if !wasHolding {
                            onTap()
                        }
                    }
            )
            .allowsHitTesting(!disabled)
    }
    
    private func startHoldTimer() {
        tickCount = 0
        
        // Initial delay before repeating starts
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { _ in
            Task { @MainActor in
                guard isPressed else { return }
                // Fire first tick
                tickCount += 1
                onHoldTick()
                // Start repeating
                startRepeatingTimer()
            }
        }
    }
    
    private func startRepeatingTimer() {
        let interval = currentTickInterval
        
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                guard isPressed else { return }
                tickCount += 1
                onHoldTick()
                // Schedule next tick (with potentially faster interval)
                startRepeatingTimer()
            }
        }
    }
    
    private var currentTickInterval: TimeInterval {
        if tickCount < accelerationThreshold {
            return initialTickInterval
        } else {
            // Accelerate: decrease interval down to minimum
            let acceleration = Double(tickCount - accelerationThreshold) * 0.02
            return max(minimumTickInterval, initialTickInterval - acceleration)
        }
    }
    
    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        tickCount = 0
    }
}

// MARK: - Preview

#Preview("Normal") {
    HStack(spacing: 20) {
        HoldableButton(
            icon: "backward.fill",
            onTap: { print("Tap back") },
            onHoldTick: { print("Hold tick back") }
        )
        
        HoldableButton(
            icon: "forward.fill",
            onTap: { print("Tap forward") },
            onHoldTick: { print("Hold tick forward") }
        )
    }
    .padding()
}

#Preview("Large Play") {
    HoldableButton(
        icon: "play.fill",
        onTap: { print("Play") },
        onHoldTick: { },
        size: 72,
        iconFont: .title,
        accentedBackground: true
    )
    .padding()
}

#Preview("Disabled") {
    HoldableButton(
        icon: "backward.fill",
        onTap: { },
        onHoldTick: { },
        disabled: true
    )
    .padding()
}
