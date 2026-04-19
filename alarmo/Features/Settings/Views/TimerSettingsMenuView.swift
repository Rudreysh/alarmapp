import SwiftUI

struct TimerSettingsMenuView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Timer")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.s)

                    VStack(spacing: 0) {
                        NavigationLink(destination: PomoSettingsView(preferences: preferences)) {
                            timerRow(title: "Pomodoro Settings", icon: "timer")
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(Colors.cardStroke)
                            .padding(.leading, 58)

                        NavigationLink(destination: StopwatchSettingsView(preferences: preferences)) {
                            timerRow(title: "Stopwatch Settings", icon: "stopwatch")
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Colors.cardSurface)
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.l)
                }
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func timerRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
