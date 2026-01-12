import SwiftUI

struct CelebrationOverlayView: View {
    let onComplete: () -> Void
    @State private var hasCompleted = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.opacity(0.75)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Colors.sheetGradientTop.opacity(0.9), Colors.sheetGradientBottom.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ConfettiView()

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Colors.saleBadgeStart, Colors.saleBadgeEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
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
