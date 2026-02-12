import SwiftUI

enum TimerPalette {
    static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
    static let accentStrong = Color(red: 0.05, green: 0.66, blue: 0.84)
    static let accentSoft = Color(red: 0.28, green: 0.88, blue: 0.98)
    static let cardTop = Color(red: 0.13, green: 0.16, blue: 0.20).opacity(0.90)
    static let cardBottom = Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.95)
}

struct TimerGlassBackground: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.02, green: 0.03, blue: 0.06),
                Color(red: 0.03, green: 0.06, blue: 0.10),
                Color(red: 0.02, green: 0.03, blue: 0.06),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            TimerPalette.accentSoft.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 320
                    )
                )
                .frame(width: 220, height: 300)
                .blur(radius: 24)
                .offset(x: animate ? 18 : -10, y: animate ? -102 : -116)
                .scaleEffect(animate ? 1.03 : 0.97)
        }
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            TimerPalette.accent.opacity(0.13),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 250
                    )
                )
                .frame(width: 320, height: 140)
                .blur(radius: 14)
                .offset(x: animate ? -14 : 10, y: animate ? 76 : 64)
                .scaleEffect(animate ? 1.04 : 0.98)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

extension View {
    func timerGlassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [TimerPalette.cardTop, TimerPalette.cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }

    func timerNeonFill(cornerRadius: CGFloat = 18) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TimerPalette.accentSoft.opacity(0.78), TimerPalette.accentStrong.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
