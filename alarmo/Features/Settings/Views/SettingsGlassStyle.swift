import SwiftUI

enum SettingsPalette {
    static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
    static let accentBright = Color(red: 0.28, green: 0.88, blue: 0.98)
    static let accentDark = Color(red: 0.05, green: 0.34, blue: 0.52)
    static let cardTop = Color(red: 0.06, green: 0.10, blue: 0.15).opacity(0.94)
    static let cardBottom = Color(red: 0.04, green: 0.07, blue: 0.10).opacity(0.96)
    static let accentGradient = LinearGradient(
        colors: [accent, accentBright.opacity(0.85), accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct SettingsGlassBackground: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.02, green: 0.04, blue: 0.08),
                Color(red: 0.03, green: 0.06, blue: 0.11),
                Color(red: 0.02, green: 0.04, blue: 0.08),
                Color.black
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
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
