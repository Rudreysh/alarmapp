import SwiftUI
import Combine

struct PermissionHeroIcon: View {
    let systemName: String
    let tint: Color
    var showBadge: Bool = false

    @State private var glow = false
    @State private var float = false
    @State private var sway = false
    @State private var badgePulse = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Colors.cardSurface)
                    .frame(width: 114, height: 114)

                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: 98, height: 98)
                    .blur(radius: 8)
                    .scaleEffect(glow ? 1.08 : 0.92)
                    .opacity(glow ? 1 : 0.55)

                Image(systemName: systemName)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(tint)
                    .offset(x: sway ? 5 : -5, y: float ? -2 : 2)
                    .scaleEffect(float ? 1.03 : 0.97)
            }

            if showBadge {
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .scaleEffect(badgePulse ? 1.0 : 0.78)
                    .opacity(badgePulse ? 1.0 : 0.7)
                    .offset(x: -6, y: 6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glow.toggle()
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                float.toggle()
            }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                sway.toggle()
            }
            withAnimation(.easeInOut(duration: 0.58).repeatForever(autoreverses: true)) {
                badgePulse.toggle()
            }
        }
    }
}

struct PermissionLoadingDots: View {
    @State private var step = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(Colors.accentTeal)
                    .frame(width: 6, height: 6)
                    .opacity(step == idx ? 1.0 : 0.28)
                    .scaleEffect(step == idx ? 1.1 : 0.9)
            }
        }
        .onReceive(timer) { _ in
            step = (step + 1) % 3
        }
    }
}

struct PermissionAnimatedLoadingCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(Colors.accentTeal)
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                PermissionLoadingDots()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Colors.cardSurface)
        .cornerRadius(14)
    }
}

struct PermissionContentEntrance: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .animation(.easeOut(duration: 0.42), value: isVisible)
    }
}

extension View {
    func permissionEntrance(_ isVisible: Bool) -> some View {
        modifier(PermissionContentEntrance(isVisible: isVisible))
    }
}
