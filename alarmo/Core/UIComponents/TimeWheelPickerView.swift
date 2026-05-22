import SwiftUI

struct TimeWheelPickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int

    private let hours24 = Array(0...23)
    private let minutes = Array(0...59)
    private let seconds = Array(0...59)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Selection Bar
                RoundedRectangle(cornerRadius: Radii.small)
                    .fill(Colors.bgSecondary)
                    .frame(height: 44)
                    .opacity(0.85)

                HStack(spacing: Spacing.l) {
                    // Hour Picker
                    Picker("Hour", selection: $hour) {
                        ForEach(hours24, id: \.self) { value in
                            Text(TimeFormatters.padded(value))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    // Minute Picker
                    Picker("Minute", selection: $minute) {
                        ForEach(minutes, id: \.self) { value in
                            Text(TimeFormatters.padded(value))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()

                    // Second Picker
                    Picker("Second", selection: $second) {
                        ForEach(seconds, id: \.self) { value in
                            Text(TimeFormatters.padded(value))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)
                    .clipped()
                }
            }
            .frame(height: 160)
        }
        .colorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Alarm time"))
    }
}
