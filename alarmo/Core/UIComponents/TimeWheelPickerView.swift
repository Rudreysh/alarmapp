import SwiftUI

struct TimeWheelPickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int

    private let hours = Array(0...23)
    private let minutes = Array(0...59)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radii.small)
                .fill(Colors.bgSecondary)
                .frame(height: 44)
                .opacity(0.85)

            HStack(spacing: Spacing.l) {
                Picker("Hour", selection: $hour) {
                    ForEach(hours, id: \.self) { value in
                        Text(TimeFormatters.padded(value))
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
                .clipped()

                Picker("Minute", selection: $minute) {
                    ForEach(minutes, id: \.self) { value in
                        Text(TimeFormatters.padded(value))
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 90)
                .clipped()
            }
        }
        .frame(height: 170)
        .colorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Alarm time"))
    }
}
