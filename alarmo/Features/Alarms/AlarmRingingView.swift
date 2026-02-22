import SwiftUI
import Combine

struct AlarmRingingView: View {
    @ObservedObject var ringCoordinator: AlarmRingCoordinator
    @State private var lastLoggedAlarmId: UUID?
    @State private var currentMission: AlarmMission?
    @State private var quoteIndex = 0
    private let quoteTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            wallpaperBackground
                .ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                Spacer()

                Text(currentDateText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                Text(currentTimeText)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Colors.textPrimary)

                if let name = ringCoordinator.activeAlarm?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }

                if ringCoordinator.activeAlarm?.dailyMotivationEnabled == true {
                    let quotes = MotivationQuotes.dailyQuotes()
                    if !quotes.isEmpty {
                        let quote = quotes[quoteIndex % quotes.count]
                        VStack(spacing: 8) {
                            Text("\"\(quote.text)\"")
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .italic()
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("text-\(quote.id)")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            
                            Text("- \(quote.author)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                .id("author-\(quote.id)")
                                .transition(.opacity)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        .onReceive(quoteTimer) { _ in
                            withAnimation(.easeInOut(duration: 1.0)) {
                                quoteIndex += 1
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: Spacing.m) {
                    if ringCoordinator.isPreviewMode {
                        Button(action: { ringCoordinator.stopRinging() }) {
                            Text("Dismiss and start \(ringCoordinator.activeAlarm?.name ?? "alarm")")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.m)
                                .background(Colors.accentRed)
                                .cornerRadius(Radii.button)
                        }
                    } else {
                        Button(action: { ringCoordinator.snooze() }) {
                            Text("Snooze")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.m)
                                .background(Color.yellow.opacity(0.9))
                                .cornerRadius(Radii.button)
                        }

                        Button(action: {
                            if let mission = ringCoordinator.activeAlarm?.missions.first(where: { $0.type != .off }) {
                                currentMission = mission
                            } else {
                                ringCoordinator.dismissTapped()
                            }
                        }) {
                            Text("Stop")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.m)
                                .background(Colors.accentRed)
                                .cornerRadius(Radii.button)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, ringCoordinator.isPreviewMode ? 0 : Spacing.xl)
                
                if ringCoordinator.isPreviewMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { ringCoordinator.stopRinging() }) {
                                Text("EXIT PREVIEW")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.5))
                    }
                    .frame(height: 70)
                }
            }
        }
        .fullScreenCover(item: $currentMission) { mission in
            Group {
                if mission.type == .qrBarcode {
                    QRBarcodeMissionView(
                        targetCode: mission.customData["barcodeVal"] ?? "",
                        onSuccess: {
                            ringCoordinator.completeMission(success: true)
                            currentMission = nil
                        }
                    )
                } else if mission.type == .math {
                    // Fallback using placeholder logic or actual connection if ViewModel allows
                     MathMissionPlayView(
                        viewModel: MathMissionViewModel(
                             config: MathMissionConfig(difficulty: MathDifficulty(rawValue: mission.difficulty) ?? .easy, repeatCount: mission.rounds),
                             isPreviewMode: false,
                             onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                             }
                        )
                     )
                } else {
                    // Generic fallback
                    VStack {
                        Text(mission.title)
                        Button("Complete (Debug)") {
                            ringCoordinator.completeMission(success: true)
                            currentMission = nil
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Colors.bgPrimary.ignoresSafeArea())
                }
            }
            .interactiveDismissDisabled(true)
        }
        .overlay(alignment: .top) {
            if let toast = ringCoordinator.penaltyToastMessage {
                Text(toast)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.top, 40)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if ringCoordinator.penaltyToastMessage == toast {
                                ringCoordinator.penaltyToastMessage = nil
                            }
                        }
                    }
            }
        }
        .onChange(of: ringCoordinator.missionTimeoutTriggered) { _, timedOut in
            if timedOut {
                currentMission = nil
                ringCoordinator.missionTimeoutTriggered = false
            }
        }
        .onChange(of: currentMission?.id) { _, newId in
            if newId != nil {
                ringCoordinator.beginMissionMonitoring()
            }
        }
        .onAppear {
            logActiveAlarmIfNeeded()
        }
        .onChange(of: ringCoordinator.activeAlarm?.id) { _, _ in
            logActiveAlarmIfNeeded()
        }
    }

    private var wallpaperBackground: some View {
        if let image = wallpaperImage() {
            return AnyView(Image(uiImage: image).resizable().scaledToFill())
        }
        return AnyView(LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom))
    }

    private func wallpaperImage() -> UIImage? {
        guard let alarm = ringCoordinator.activeAlarm else { return nil }
        if let image = WallpaperImageResolver.resolveImage(for: alarm.wallpaperId) {
            return image
        }
        print("[AlarmRingingView] wallpaper not found for id=\(alarm.wallpaperId)")
        return nil
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

    private func logActiveAlarmIfNeeded() {
        guard let alarm = ringCoordinator.activeAlarm else { return }
        guard lastLoggedAlarmId != alarm.id else { return }
        lastLoggedAlarmId = alarm.id
        print("[AlarmRingingView] alarmId=\(alarm.id.uuidString) wallpaperId=\(alarm.wallpaperId)")
    }
}
