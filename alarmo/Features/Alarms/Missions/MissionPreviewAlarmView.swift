import SwiftUI

struct MissionPreviewAlarmView: View {
    let missionTitle: String
    let missionIcon: String
    let onStartMission: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var logged = false

    var body: some View {
        ZStack {
            wallpaperBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(currentDateText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MissionTheme.backgroundMutedText)

                Text(currentTimeText)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(MissionTheme.backgroundText)

                Text("Alarm")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(MissionTheme.backgroundText)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: onStartMission) {
                        HStack {
                            Image(systemName: missionIcon)
                            Text("Start \(missionTitle)")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [
                                    Colors.accentTeal,
                                    Colors.accentBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Colors.shadow.opacity(0.25), radius: 12, x: 0, y: 8)
                    }

                    Button(action: { dismiss() }) {
                        Text("EXIT PREVIEW")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MissionTheme.secondaryButtonText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(MissionTheme.secondaryButtonFill)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var wallpaperBackground: some View {
        LinearGradient(
            colors: [Colors.bgSecondary, Colors.bgPrimary],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var currentTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E dd. MMM"
        return formatter.string(from: Date())
    }
}
