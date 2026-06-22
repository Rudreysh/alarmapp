import SwiftUI

enum TimerPalette {
    static var accent: Color { Colors.accentTeal }
    static var accentStrong: Color { Colors.accentBlue.opacity(0.82) }
    static var accentSoft: Color { Colors.accentBlue.opacity(0.92) }
    static var cardTop: Color { Colors.cardSurface.opacity(0.90) }
    static var cardBottom: Color { Colors.bgSecondary.opacity(0.95) }
}

struct TimerGlassBackground: View {
    @ObservedObject private var settingsStore = SettingsStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var animate = false

    var body: some View {
        LinearGradient(
            colors: [
                Colors.bgPrimary,
                Colors.bgSecondary,
                Colors.bgPrimary
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .id("\(settingsStore.alarmThemeStyleRaw)-\(themeManager.paletteRevision)")
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
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .shadow(color: Colors.shadow.opacity(0.45), radius: 10, x: 0, y: 5)
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
