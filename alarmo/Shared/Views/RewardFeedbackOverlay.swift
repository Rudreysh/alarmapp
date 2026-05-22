import SwiftUI

struct RewardFeedbackOverlay: View {
    @ObservedObject private var feedback = RewardFeedbackService.shared

    var body: some View {
        ZStack {
            if let toast = feedback.toast {
                VStack {
                    XPToastView(toast: toast)
                        .padding(.top, 70)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let rankUp = feedback.rankUp {
                RankUpModal(presentation: rankUp) {
                    feedback.dismissRankUp()
                }
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: feedback.toast)
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: feedback.rankUp)
    }
}

private struct XPToastView: View {
    let toast: XPToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .black))
            Text("+\(toast.amount) XP")
                .font(.system(size: 22, weight: .black, design: .rounded))
            Text(toast.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Colors.accentTeal, Colors.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Colors.accentTeal.opacity(0.35), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 24)
    }
}

private struct RankUpModal: View {
    let presentation: RankUpPresentation
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 18) {
                ConfettiView()
                    .frame(height: 80)
                    .allowsHitTesting(false)

                Image(presentation.rank.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .shadow(color: presentation.rank.tier.accentColor.opacity(0.45), radius: 20, x: 0, y: 8)

                VStack(spacing: 6) {
                    Text("RANK UP")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                    Text(presentation.rank.displayName)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text(presentation.xpToNextRank == 0 ? "Top visible rank reached" : "\(presentation.xpToNextRank) XP to next rank")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textSecondary)
                }

                Button(action: dismiss) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Colors.accentTeal))
                }
                .buttonStyle(PressedScaleButtonStyle())
            }
            .padding(24)
            .background(Colors.cardSurface)
            .cornerRadius(26)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(presentation.rank.tier.accentColor.opacity(0.8), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
    }
}
