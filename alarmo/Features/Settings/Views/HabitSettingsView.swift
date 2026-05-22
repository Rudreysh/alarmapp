import SwiftUI

struct HabitSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showMetricSystemPicker = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Habit")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, Spacing.l)

                VStack(spacing: 0) {
                    Button {
                        showMetricSystemPicker = true
                    } label: {
                        row(
                            icon: "ruler.fill",
                            title: "Measurement system",
                            trailing: store.habitDistanceUnitSystem.title
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56).opacity(0.35)

                    Toggle(isOn: $store.habitGoalCelebrationEnabled) {
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Goal Celebration")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(store.habitGoalCelebrationEnabled ? "Animation enabled" : "Animation disabled")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.vertical, 16)
                    .padding(.horizontal, Spacing.m)
                }
                .background(Colors.cardSurface)
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Colors.cardStroke, lineWidth: 1))
                .appShadow(Shadows.card)
                .padding(.horizontal, Spacing.l)

                Text("This applies to distance units across all habits.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .padding(.top, Spacing.s)
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Measurement system",
            isPresented: $showMetricSystemPicker,
            titleVisibility: .visible
        ) {
            ForEach(HabitDistanceUnitSystem.allCases) { system in
                Button(system.title) {
                    store.habitDistanceUnitSystem = system
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose between Metric and US measurement units.")
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.accentTeal)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Colors.textTertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.m)
        .contentShape(Rectangle())
    }
}
