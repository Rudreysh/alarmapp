import SwiftUI

enum PlanPalette {
    static var textPrimary: Color { Colors.textPrimary }
    static var textSecondary: Color { Colors.textSecondary }
    static var textMuted: Color { Colors.textTertiary }
    static var accent: Color { Colors.accentTeal }
    static var accentStrong: Color { Colors.accentBlue }
    static var accentSoft: Color { Colors.accentTeal.opacity(0.85) }
}

struct PlanGlassBackground: View {
    @ObservedObject private var settingsStore = SettingsStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var animate = false

    private var isLightAppearance: Bool {
        settingsStore.isLightAppearance
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Colors.bgPrimary,
                    Colors.bgSecondary,
                    Colors.bgPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isLightAppearance {
                lightThemeGlow
            } else {
                darkThemeGlow
            }
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

    private var lightThemeGlow: some View {
        ZStack {
            GeometryReader { proxy in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Colors.accentBlue.opacity(0.14),
                                Colors.accentTeal.opacity(0.06),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.75
                        )
                    )
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.width * 1.2)
                    .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.2)
                    .blur(radius: 48)
            }
            .ignoresSafeArea()

            GeometryReader { proxy in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Colors.sheetGradientTop.opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: proxy.size.width * 0.55
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height * 0.5)
                    .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.75)
                    .blur(radius: 40)
            }
            .ignoresSafeArea()
        }
    }

    private var darkThemeGlow: some View {
        ZStack {
            GeometryReader { proxy in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.78, green: 0.49, blue: 0.26).opacity(0.5),
                                Color(red: 0.78, green: 0.49, blue: 0.26).opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.8
                        )
                    )
                    .frame(width: proxy.size.width * 1.5, height: proxy.size.width * 1.5)
                    .position(x: 0, y: proxy.size.height)
                    .blur(radius: 60)
                    .offset(x: animate ? 4 : -4)
            }
            .ignoresSafeArea()

            GeometryReader { proxy in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.37, green: 0.49, blue: 0.54).opacity(0.4),
                                Color(red: 0.82, green: 0.82, blue: 0.82).opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: proxy.size.width * 0.7
                        )
                    )
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.height * 0.8)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.6)
                    .blur(radius: 50)
                    .offset(x: animate ? -6 : 6)
            }
            .ignoresSafeArea()

            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }
}

extension View {
    func planGlassPanel(cornerRadius: CGFloat = 16, fillOpacity: Double = 0.10) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Colors.cardSurface.opacity(max(fillOpacity, 0.72)))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .shadow(color: Colors.shadow.opacity(0.22), radius: 10, x: 0, y: 5)
    }

    func planGlassCircle(size: CGFloat = 56, fillOpacity: Double = 0.10) -> some View {
        self
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Colors.cardSurface.opacity(max(fillOpacity, 0.72)))
                    .background(.ultraThinMaterial, in: Circle())
            )
            .overlay(
                Circle()
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .shadow(color: Colors.shadow.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    func planPrimaryCTA(cornerRadius: CGFloat = 24) -> some View {
        self
            .foregroundColor(SettingsStore.shared.isLightAppearance ? Colors.textPrimary : Color.white.opacity(0.95))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PlanPalette.accentSoft.opacity(0.78),
                                PlanPalette.accentStrong.opacity(0.82),
                                PlanPalette.accent.opacity(0.80)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Colors.cardStroke.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: PlanPalette.accent.opacity(0.20), radius: 14, x: 0, y: 8)
    }
}
