import SwiftUI

struct GentleWakeUpPickerView: View {
    @Binding var selectedSeconds: Int

    private let options = [0, 10, 30, 60, 120]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Text("Gentle wake-up")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                Picker("Gentle wake-up", selection: $selectedSeconds) {
                    ForEach(options, id: \.self) { value in
                        Text(value == 0 ? "Off" : "\(value) seconds")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(Spacing.l)
        }
    }
}
