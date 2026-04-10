import SwiftUI

struct CelebrationOverlayView: View {
    let onComplete: () -> Void
    @State private var hasCompleted = false

    var body: some View {
        ZStack {
            // Keep celebration overlay dark/blackish so it matches the app background system.
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    Colors.bgSecondary.opacity(0.36),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Colors.accentTeal.opacity(0.12), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )
            .ignoresSafeArea()

            ConfettiView()

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Colors.accentTeal.opacity(0.95),
                                    Colors.accentBlue.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )

                    VStack(spacing: 4) {
                        Text("Sale")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("50%")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onTapGesture {
            guard !hasCompleted else { return }
            hasCompleted = true
            onComplete()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard !hasCompleted else { return }
                hasCompleted = true
                onComplete()
            }
        }
        .transition(.opacity)
    }
}
