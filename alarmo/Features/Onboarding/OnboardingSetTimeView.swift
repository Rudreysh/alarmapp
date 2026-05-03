import SwiftUI

struct OnboardingSetTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Set your alarm time")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)

                ProgressHeader(step: 1, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, 0)
                    .padding(.bottom, Spacing.xs)

                SunRayTimePickerView(
                    hour: Binding(
                        get: { viewModel.selectedHour },
                        set: { viewModel.selectedHour = $0 }
                    ),
                    minute: Binding(
                        get: { viewModel.selectedMinute },
                        set: { viewModel.selectedMinute = $0 }
                    ),
                    second: nil
                )
                .padding(.top, Spacing.s)
                .frame(maxHeight: 300)

                OnboardingInlineHourMinutePicker(
                    hour: Binding(
                        get: { viewModel.selectedHour },
                        set: { viewModel.selectedHour = $0 }
                    ),
                    minute: Binding(
                        get: { viewModel.selectedMinute },
                        set: { viewModel.selectedMinute = $0 }
                    )
                )
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)

                Spacer()
            }
            .padding(.top, -8)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }
}

private struct OnboardingInlineHourMinutePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                pickerColumn(
                    title: "Hour",
                    selection: $hour,
                    range: 0..<24
                )

                pickerColumn(
                    title: "Minute",
                    selection: $minute,
                    range: 0..<60
                )
            }
        }
        .padding(Spacing.m)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radii.card))
    }

    private func pickerColumn(
        title: String,
        selection: Binding<Int>,
        range: Range<Int>
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Colors.textPrimary)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipped()
        }
        .padding(.horizontal, Spacing.s)
    }
}
