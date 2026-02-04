import SwiftUI

struct WakeUpCheckView: View {
    @Binding var isEnabled: Bool

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                HStack {
                    Spacer()
                    Text("Wake Up Check")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                Toggle("Enabled", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                    .foregroundColor(Colors.textPrimary)
                    .padding()

                Text("TODO: Configure wake-up check options")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(Spacing.l)
        }
    }
}
