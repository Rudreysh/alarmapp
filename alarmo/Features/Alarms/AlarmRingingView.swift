import SwiftUI
import Combine
import UIKit

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
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Colors.textSecondary)

                Text(currentTimeText)
                    .font(.system(size: 64, weight: .heavy, design: .monospaced))
                    .foregroundColor(Colors.textPrimary)

                if let name = ringCoordinator.activeAlarm?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }

                if shouldShowMotivationQuote {
                    let quotes = MotivationQuotes.dailyQuotes()
                    if !quotes.isEmpty {
                        let quote = quotes[quoteIndex % quotes.count]
                        VStack(spacing: 8) {
                            AdaptiveQuoteText(
                                quote: quote.text,
                                maxWidth: max(UIScreen.main.bounds.width - 56, 220),
                                maxLines: 5,
                                maxFontSize: 24,
                                minFontSize: 11,
                                weight: .medium
                            )
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                                .id("text-\(quote.id)")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            
                            Text("- \(quote.author)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
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
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.08, green: 0.78, blue: 0.92),
                                            Color(red: 0.05, green: 0.66, blue: 0.84)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(Radii.button)
                                .shadow(color: Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3), radius: 15, x: 0, y: 10)
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
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.08, green: 0.78, blue: 0.92),
                                            Color(red: 0.05, green: 0.66, blue: 0.84)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(Radii.button)
                                .shadow(color: Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3), radius: 15, x: 0, y: 10)
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
                switch mission.type {
                case .qrBarcode:
                    if let target = resolvedBarcodeTarget(for: mission) {
                        QRBarcodeMissionView(
                            targetCode: target.code,
                            targetSymbology: target.symbology,
                            onSuccess: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    } else {
                        VStack(spacing: 16) {
                            Text("QR/Barcode")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Mission is not configured. Edit this alarm and select a barcode target.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            Button("Complete (Debug)") {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Colors.accentTeal)
                            .cornerRadius(14)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Colors.bgPrimary.ignoresSafeArea())
                    }
                case .math:
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
                case .typing:
                    let settings = typingSettings(for: mission)
                    TypingMissionGameplayView(
                        viewModel: TypingGameplayViewModel(
                            settings: settings,
                            phrases: typingPhrases(settings: settings),
                            isPreviewMode: false,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                case .findColorTiles:
                    FindColorTilesMissionView(
                        viewModel: FindColorTilesViewModel(
                            settings: FindColorTilesSettings(
                                difficulty: MissionDifficulty(rawValue: mission.difficulty) ?? .normal,
                                rounds: mission.rounds,
                                soundEnabled: true
                            ),
                            isPreviewMode: false,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                case .memoryMatch:
                    MemoryMatchGameView(
                        viewModel: MemoryMatchViewModel(
                            difficulty: memoryDifficulty(from: mission.difficulty),
                            rounds: max(1, mission.rounds),
                            isPreviewMode: false,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                case .ticTacToe:
                    let size = TTTBoardSize(rawValue: mission.config["size"] ?? 3) ?? .threeByThree
                    let difficulty = TTTDifficulty(rawValue: mission.difficulty) ?? .medium
                    TicTacToeGameView(
                        viewModel: makeTicTacToeViewModel(
                            size: size,
                            difficulty: difficulty,
                            rounds: mission.rounds
                        )
                    )
                case .shake:
                    ShakeMissionView(
                        viewModel: ShakeMissionViewModel(
                            targetShakes: mission.config["shakeCount"] ?? 30,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                case .step:
                    StepsMissionView(
                        viewModel: StepsMissionViewModel(
                            targetSteps: mission.config["stepCount"] ?? 20,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                case .householdItemHunt:
                    if let filename = mission.customData["referenceImageFilename"], !filename.isEmpty {
                        HouseholdItemHuntMissionView(
                            referenceImageFilename: filename,
                            onSuccess: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    } else {
                        VStack(spacing: 16) {
                            Text("Household Item Hunt")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Mission is not configured. Edit this alarm and set a reference image.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            Button("Complete (Debug)") {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Colors.accentTeal)
                            .cornerRadius(14)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Colors.bgPrimary.ignoresSafeArea())
                    }
                case .squat:
                    SquatMissionView(
                        viewModel: SquatMissionViewModel(
                            targetSquats: mission.config["squatCount"] ?? 10,
                            onComplete: {
                                ringCoordinator.completeMission(success: true)
                                currentMission = nil
                            }
                        )
                    )
                default:
                    // Generic fallback for ticTacToe, memoryMatch, typing, etc.
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

    private var shouldShowMotivationQuote: Bool {
        guard let alarm = ringCoordinator.activeAlarm else { return false }
        if alarm.dailyMotivationEnabled { return true }
        return alarm.visualOutputSettings.alarmScreen.enabled &&
            (alarm.visualOutputSettings.alarmScreen.mode == .quotes ||
             alarm.visualOutputSettings.alarmScreen.mode == .both)
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

    private func resolvedBarcodeTarget(for mission: AlarmMission) -> (code: String, symbology: String?)? {
        let rawFromCustomData = mission.customData["barcodeVal"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbologyFromCustomData = mission.customData["barcodeSym"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let rawFromCustomData, !rawFromCustomData.isEmpty {
            return (code: rawFromCustomData, symbology: symbologyFromCustomData)
        }

        guard let barcodeIdString = mission.customData["barcodeId"],
              let barcodeId = UUID(uuidString: barcodeIdString),
              let raw = QRBarcodeMissionViewModel.rawValue(for: barcodeId)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        let symbology = symbologyFromCustomData ?? QRBarcodeMissionViewModel.symbology(for: barcodeId)
        return (code: raw, symbology: symbology)
    }

    private func typingSettings(for mission: AlarmMission) -> TypingSettings {
        var settings = TypingMissionStore.shared.loadSettings(for: "default")
        settings.repeatCount = max(1, mission.rounds)
        return settings
    }

    private func typingPhrases(settings: TypingSettings) -> [Phrase] {
        let selected = TypingMissionStore.shared.allPhrases
            .filter { settings.selectedPhraseIDs.contains($0.id) }
        return selected.isEmpty ? TypingSettings.defaultPhrases : selected
    }

    private func memoryDifficulty(from storedRows: Int) -> MemoryDifficulty {
        switch storedRows {
        case 3: return .threeByThree
        case 5: return .fiveByFive
        case 6: return .sixBySix
        default: return .fourByFour
        }
    }

    private func makeTicTacToeViewModel(
        size: TTTBoardSize,
        difficulty: TTTDifficulty,
        rounds: Int
    ) -> TicTacToeViewModel {
        let viewModel = TicTacToeViewModel(
            rounds: max(1, rounds),
            isPreviewMode: false
        ) {
            ringCoordinator.completeMission(success: true)
            currentMission = nil
        }
        viewModel.newGame(size: size, difficulty: difficulty)
        return viewModel
    }
}
