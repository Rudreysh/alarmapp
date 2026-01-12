import SwiftUI

struct AlarmRingingView: View {
    @ObservedObject var ringCoordinator: AlarmRingCoordinator

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
                    Button(action: { ringCoordinator.snooze() }) {
                        Text("Snooze")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.m)
                            .background(Colors.bgSecondary.opacity(0.6))
                            .cornerRadius(Radii.button)
                    }

                    Button(action: { ringCoordinator.stopRinging() }) {
                        Text("Stop")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.m)
                            .background(Colors.accentRed)
                            .cornerRadius(Radii.button)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
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
        if let url = Bundle.main.url(forResource: id, withExtension: nil, subdirectory: "BundledWallpapers") {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = findWallpaperByFilename(id) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    private func findWallpaperByFilename(_ filename: String) -> URL? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("BundledWallpapers") else { return nil }
        let fm = FileManager.default
        guard let categories = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return nil }
        for category in categories {
            if let items = try? fm.contentsOfDirectory(at: category, includingPropertiesForKeys: nil) {
                if let match = items.first(where: { $0.lastPathComponent == filename }) {
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
}
