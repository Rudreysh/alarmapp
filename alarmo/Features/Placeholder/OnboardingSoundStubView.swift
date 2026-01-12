import SwiftUI

struct OnboardingSoundStubView: View {
    var body: some View {
        VStack(spacing: Spacing.m) {
            Text("Step 3 complete")
                .screenTitle()
            Text("Placeholder for wake-up mission")
                .bodyText()
                .foregroundColor(Colors.textSecondary)
        }
        .foregroundColor(Colors.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.bgPrimary)
    }
}
