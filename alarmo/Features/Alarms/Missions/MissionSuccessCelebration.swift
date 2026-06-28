import SwiftUI
import UIKit

/// Shared celebratory overlay shown when a wake-up mission is completed.
///
/// A confetti burst behind a spring-popped checkmark and a short message —
/// kept deliberately simple and consistent with the other missions
/// (Math/Typing/Shake) so every mission ends on the same happy beat.
struct MissionSuccessCelebration: View {
    var title: String = "Good job!"
    var subtitle: String? = "You're wide awake now!"

    @State private var pop = false

    var body: some View {
        ZStack {
            MissionTheme.successScrim.ignoresSafeArea()
            MissionEmojiConfettiBackground()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 92, weight: .bold))
                    .foregroundColor(Colors.accentGreen)
                    .scaleEffect(pop ? 1 : 0.3)
                    .opacity(pop ? 1 : 0)

                Text(title)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                    .opacity(pop ? 1 : 0)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(pop ? 1 : 0)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                pop = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
