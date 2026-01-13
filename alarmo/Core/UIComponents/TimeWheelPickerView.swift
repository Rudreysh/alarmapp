import SwiftUI

struct TimeWheelPickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int

    private let hours12 = Array(1...12)
    private let minutes = Array(0...59)
    private let periods = ["AM", "PM"]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radii.small)
                .fill(Colors.bgSecondary)
                .frame(height: 44)
                .opacity(0.85)

            HStack(spacing: Spacing.s) {
                // Hour Picker (1-12)
                Picker("Hour", selection: Binding(
                    get: {
                        let h = hour % 12
                        return h == 0 ? 12 : h
                    },
                    set: { new12h in
                        let isPm = hour >= 12
                        if isPm {
                            hour = (new12h == 12) ? 12 : new12h + 12
                        } else {
                            hour = (new12h == 12) ? 0 : new12h
                        }
                    }
                )) {
                    ForEach(hours12, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 26, weight: .medium))
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
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
                .clipped()
                
                // AM/PM Picker
                Picker("Period", selection: Binding(
                    get: { hour >= 12 ? 1 : 0 },
                    set: { newIndex in
                        let isPm = newIndex == 1
                        let old12h = hour % 12
                        let safe12h = (old12h == 0) ? 12 : old12h
                        
                        if isPm {
                            // Swithcing to PM
                            hour = (safe12h == 12) ? 12 : safe12h + 12
                        } else {
                            // Switching to AM
                            hour = (safe12h == 12) ? 0 : safe12h
                        }
                    }
                )) {
                    ForEach(0..<2) { index in
                        Text(periods[index])
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70)
                .clipped()
            }
        }
        .frame(height: 170)
        .colorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Alarm time"))
    }
}
