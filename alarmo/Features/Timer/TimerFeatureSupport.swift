import SwiftUI
import Combine

struct OLEDAntiBurnInModifier: ViewModifier {
    let enabled: Bool
    let isActive: Bool

    @State private var offsetIndex = 0

    private let offsets: [CGSize] = [
        .zero,
        CGSize(width: 3, height: -2),
        CGSize(width: -4, height: 2),
        CGSize(width: 2, height: 4),
        CGSize(width: -2, height: -3)
    ]

    func body(content: Content) -> some View {
        content
            .offset(activeOffset)
            .animation(.easeInOut(duration: 1.2), value: offsetIndex)
            .onReceive(Timer.publish(every: 18, on: .main, in: .common).autoconnect()) { _ in
                guard enabled, isActive else { return }
                offsetIndex = (offsetIndex + 1) % offsets.count
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    offsetIndex = 0
                }
            }
            .onChange(of: enabled) { _, isEnabled in
                if !isEnabled {
                    offsetIndex = 0
                }
            }
    }

    private var activeOffset: CGSize {
        guard enabled, isActive else { return .zero }
        return offsets[offsetIndex]
    }
}

extension View {
    func oledAntiBurnIn(enabled: Bool, isActive: Bool) -> some View {
        modifier(OLEDAntiBurnInModifier(enabled: enabled, isActive: isActive))
    }
}
