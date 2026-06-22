import SwiftUI

enum SettingsPalette {
    static var accent: Color { Colors.accentTeal }
    static var accentBright: Color { Colors.accentBlue.opacity(0.9) }
    static var accentDark: Color { Colors.accentTeal.opacity(0.7) }
    static var cardTop: Color { Colors.cardSurface.opacity(0.94) }
    static var cardBottom: Color { Colors.bgSecondary.opacity(0.96) }
    static var accentGradient: LinearGradient {
        LinearGradient(
        colors: [accent, accentBright.opacity(0.85), accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    }
}

struct SettingsGlassBackground: View {
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
            RoundedRectangle(cornerRadius: 96, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [SettingsPalette.accentBright.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 340
                    )
                )
                .frame(width: 260, height: 320)
                .blur(radius: 24)
                .offset(x: animate ? 16 : -8, y: animate ? -112 : -126)
                .scaleEffect(animate ? 1.03 : 0.97)
        }
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [SettingsPalette.accent.opacity(0.13), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 280
                    )
                )
                .frame(width: 340, height: 160)
                .blur(radius: 18)
                .offset(x: animate ? -10 : 12, y: animate ? 86 : 74)
                .scaleEffect(animate ? 1.03 : 0.98)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .id("\(settingsStore.alarmThemeStyleRaw)-\(themeManager.paletteRevision)")
        .onAppear {
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
