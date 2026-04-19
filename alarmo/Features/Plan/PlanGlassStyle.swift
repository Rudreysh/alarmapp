import SwiftUI

enum PlanPalette {
    static var textPrimary: Color { Colors.textPrimary }
    static var textSecondary: Color { Colors.textSecondary }
    static var textMuted: Color { Colors.textTertiary }
    static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
    static let accentStrong = Color(red: 0.05, green: 0.66, blue: 0.84)
    static let accentSoft = Color(red: 0.28, green: 0.88, blue: 0.98)
}

struct PlanGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared

    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }

    var body: some View {
        ZStack {
            // 1. Deep Black Base
            (isLightMode ? Colors.bgPrimary : Color.black)
                .ignoresSafeArea()
            
            // 2. Warm Orange Glow (Bottom Left)
            // Positioned to spill over from the bottom left corner
            GeometryReader { proxy in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.78, green: 0.49, blue: 0.26).opacity(isLightMode ? 0.20 : 0.5), // #C87D43
                                Color(red: 0.78, green: 0.49, blue: 0.26).opacity(isLightMode ? 0.05 : 0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.8 // Large spill
                        )
                    )
                    .frame(width: proxy.size.width * 1.5, height: proxy.size.width * 1.5)
                    .position(x: 0, y: proxy.size.height) // Bottom Left corner
                    .blur(radius: 60)
            }
            .ignoresSafeArea()
            
            // 3. Teal/Blue-Grey Glow (Middle/Bottom Right)
            GeometryReader { proxy in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.37, green: 0.49, blue: 0.54).opacity(isLightMode ? 0.18 : 0.4), // #5F7D8B
                                Color(red: 0.82, green: 0.82, blue: 0.82).opacity(isLightMode ? 0.12 : 0.2), // #D0D0D0 (Light Grey mix)
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: proxy.size.width * 0.7
                        )
                    )
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.height * 0.8)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.6) // Middle-Bottom Right
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
            
            // 4. Subtle Noise/Grain Overlay
            // Using a high-opacity color mix or material to simulate texture if possible,
            // otherwise just the gradient is the main "pattern".
            Rectangle()
                .fill((isLightMode ? Color.black : Color.white).opacity(0.02))
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
                    .fill(Color.white.opacity(fillOpacity))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }

    func planGlassCircle(size: CGFloat = 56, fillOpacity: Double = 0.10) -> some View {
        self
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.white.opacity(fillOpacity))
                    .background(.ultraThinMaterial, in: Circle())
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
    }

    func planPrimaryCTA(cornerRadius: CGFloat = 24) -> some View {
        self
            .foregroundColor(Color.white.opacity(0.95))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PlanPalette.accentSoft.opacity(0.68),
                                PlanPalette.accentStrong.opacity(0.72),
                                PlanPalette.accent.opacity(0.70)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.44), Color.white.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: PlanPalette.accent.opacity(0.20), radius: 14, x: 0, y: 8)
    }
}
