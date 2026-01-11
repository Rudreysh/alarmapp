import SwiftUI

struct ComparisonCardAppView: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text(AppConstants.appName)
                    .cardTitle()
                    .foregroundColor(Colors.accentRed)

                HStack {
                    Text("7:00")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Colors.accentRed))
                        .disabled(true)
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 240)
        }
    }
}
