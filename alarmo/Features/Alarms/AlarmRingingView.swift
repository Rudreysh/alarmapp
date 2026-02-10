import SwiftUI

struct AlarmRingingView: View {
    @ObservedObject var ringCoordinator: AlarmRingCoordinator
    @State private var lastLoggedAlarmId: UUID?
    @State private var currentMission: AlarmMission?

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
        let id = alarm.wallpaperId
        if let image = loadFromCatalog(id: id) {
            return image
        }
        if let image = fallbackImage() {
            return image
        }
        if let url = Bundle.main.url(forResource: id, withExtension: nil, subdirectory: "BundledWallpapers") {
            return UIImage(contentsOfFile: url.path)
        }
        if let parsed = parsedWallpaper(id) {
            if let url = Bundle.main.url(forResource: parsed.filename, withExtension: nil, subdirectory: "BundledWallpapers/\(parsed.category)") {
                return UIImage(contentsOfFile: url.path)
            }
        }
        if let url = Bundle.main.url(forResource: id, withExtension: nil) {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = findWallpaperByFilename(id) {
            return UIImage(contentsOfFile: url.path)
        }
        print("[AlarmRingingView] wallpaper not found for id=\(id)")
        return nil
    }

    private func loadFromCatalog(id: String) -> UIImage? {
        let loader = BundleWallpaperCatalogLoader(debugLogging: false)
        guard let categories = try? loader.loadCategories() else { return nil }
        if id == "default" {
            if let first = categories.first?.items.first {
                return UIImage(contentsOfFile: first.url.path)
            }
        }
        for category in categories {
            if let item = category.items.first(where: { $0.id == id }) {
                return UIImage(contentsOfFile: item.url.path)
            }
        }
        return nil
    }

    private func fallbackImage() -> UIImage? {
        guard let firstCategory = WallpaperConfig.categories.first,
              let firstFilename = firstCategory.imageNames.first else { return nil }
        if let url = Bundle.main.url(forResource: firstFilename, withExtension: nil, subdirectory: "BundledWallpapers/\(firstCategory.id)") {
            return UIImage(contentsOfFile: url.path)
        }
        let nameWithoutExt = (firstFilename as NSString).deletingPathExtension
        let ext = (firstFilename as NSString).pathExtension
        if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    private func parsedWallpaper(_ id: String) -> (category: String, filename: String)? {
        let parts = id.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        return (category: String(parts[0]), filename: String(parts[1]))
    }

    private func findWallpaperByFilename(_ filename: String) -> URL? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("BundledWallpapers") else { return nil }
        let fm = FileManager.default
        let target = filename.components(separatedBy: "-").last ?? filename
        guard let categories = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return nil }
        for category in categories {
            if let items = try? fm.contentsOfDirectory(at: category, includingPropertiesForKeys: nil) {
                if let match = items.first(where: { $0.lastPathComponent == target }) {
                    return match
                }
            }
        }
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
