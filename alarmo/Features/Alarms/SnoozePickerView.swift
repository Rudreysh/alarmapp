import SwiftUI

struct SnoozePickerView: View {
    @Binding var minutes: Int
    @Binding var count: Int

    private let minuteOptions = [0, 3, 5, 10, 15, 20, 25, 30, 45, 60]
    private let countOptions = Array(1...10)

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                HStack {
                    Spacer()
                    Text("Snooze")
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

                Picker("Interval", selection: $minutes) {
                    ForEach(minuteOptions, id: \.self) { value in
                        Text(value == 0 ? "Off" : "\(value) min")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Max snoozes", selection: $count) {
                    ForEach(countOptions, id: \.self) { value in
                        Text("\(value) times")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(Spacing.l)
        }
    }
}
