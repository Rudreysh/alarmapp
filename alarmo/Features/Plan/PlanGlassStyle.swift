import SwiftUI

enum PlanPalette {
    static let textPrimary = Color.white.opacity(0.97)
    static let textSecondary = Color.white.opacity(0.82)
    static let textMuted = Color.white.opacity(0.66)
    static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
    static let accentStrong = Color(red: 0.05, green: 0.66, blue: 0.84)
    static let accentSoft = Color(red: 0.28, green: 0.88, blue: 0.98)
}

struct PlanGlassBackground: View {
    var body: some View {
        TimerGlassBackground()
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
