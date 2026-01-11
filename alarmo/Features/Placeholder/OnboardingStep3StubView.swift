import SwiftUI

struct OnboardingStep3StubView: View {
    var body: some View {
        VStack(spacing: Spacing.m) {
            Text("Step 2 complete")
                .screenTitle()
            Text("Placeholder for permissions screen")
                .bodyText()
                .foregroundColor(Colors.textSecondary)
        }
        .foregroundColor(Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.bgPrimary)
    }
}
