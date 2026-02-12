import SwiftUI

struct ComparisonCardOtherAppsView: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Other Apps")
                    .cardTitle()
                    .foregroundColor(Colors.textSecondary)

                VStack(spacing: Spacing.l) {
                    timeRow("6:55", isOn: true)
                    timeRow("7:10", isOn: true)
                    timeRow("7:20", isOn: true)
                    timeRow("7:30", isOn: false, isDimmed: true)
                }
            }
            .frame(minHeight: 240)
        }
    }

    private func timeRow(_ time: String, isOn: Bool, isDimmed: Bool = false) -> some View {
        HStack {
            Text(time)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .disabled(true)
        }
        .opacity(isDimmed ? 0.35 : 1)
    }
}
