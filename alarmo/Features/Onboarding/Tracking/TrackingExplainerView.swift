import SwiftUI

struct TrackingExplainerView: View {
    @StateObject private var viewModel = TrackingExplainerViewModel()
    let onNext: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Text("Allow tracking on\nthe next screen for:")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xxl)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    TrackingRow(icon: "megaphone.fill", tint: Colors.accentTeal, text: "Advertisements that match\nyour interests.")
                    TrackingRow(icon: "checkmark.shield.fill", tint: Colors.accentBlue, text: "Improvements in personalized\nexperience.")
                    TrackingRow(icon: "gearshape.fill", tint: Colors.textSecondary, text: "You can change this anytime\nin Settings.")
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    Task { @MainActor in
                        _ = await viewModel.handleNext()
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}

private struct TrackingRow: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.leading)
        }
    }
}
