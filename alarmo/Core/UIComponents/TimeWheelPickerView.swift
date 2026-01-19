import SwiftUI

struct TimeWheelPickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int

    private let hours24 = Array(0...23)
    private let minutes = Array(0...59)

    var body: some View {
        VStack(spacing: 12) {
            // Header Labels
            HStack(spacing: Spacing.xl) {
                Text("H")
                    .frame(width: 80)
                Text("M")
                    .frame(width: 80)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Colors.textTertiary)

            ZStack {
                // Selection Bar
                RoundedRectangle(cornerRadius: Radii.small)
                    .fill(Colors.bgSecondary)
                    .frame(height: 48)
                    .opacity(0.85)

                HStack(spacing: Spacing.xl) {
                    // Hour Picker
                    Picker("Hour", selection: $hour) {
                        ForEach(hours24, id: \.self) { value in
                            Text(TimeFormatters.padded(value))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    // Minute Picker
                    Picker("Minute", selection: $minute) {
                        ForEach(minutes, id: \.self) { value in
                            Text(TimeFormatters.padded(value))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                }
            }
            .frame(height: 180)
        }
        .colorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Alarm time"))
    }
}
