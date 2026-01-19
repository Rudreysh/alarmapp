import SwiftUI

struct BackgroundCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.l)
            .background(Colors.cardSurface)
            .cornerRadius(22)
    }
}

extension View {
    func backgroundCard() -> some View {
        modifier(BackgroundCard())
    }
}

struct MissionSectionView: View {
    let missions: [AlarmMission]
    let onAddMission: () -> Void
    let onEditMission: (Int) -> Void
    let onRemoveMission: (Int) -> Void
    let wakeUpCheckText: String
    let onWakeUpCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Mission")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text("\(missions.count)/5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        if index < missions.count {
                            missionIcon(missions[index].iconName)
                                .onTapGesture { onEditMission(index) }
                                .contextMenu {
                                    Button(role: .destructive) { onRemoveMission(index) } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        } else {
                            Button(action: onAddMission) {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .foregroundColor(Colors.textSecondary)
                                    )
                            }
                        }
                    }
                }
            }

            Button(action: onWakeUpCheck) {
                HStack {
                    Text("Wake up check")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text(wakeUpCheckText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .backgroundCard()
    }
    
    private func missionIcon(_ name: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Colors.bgSecondary)
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 24))
                    .foregroundColor(Colors.textPrimary)
            )
    }
}

struct AlarmSoundCard: View {
    let soundName: String
    let isBuffering: Bool
    let onTap: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                Circle()
                    .fill(Colors.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Group {
                            if isBuffering {
                                ProgressView()
                                    .tint(Colors.textPrimary)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "play.fill")
                                    .foregroundColor(Colors.textPrimary)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(soundName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                
                if isBuffering {
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(Colors.accentTeal)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Colors.textSecondary)
        }
        .padding(Spacing.m)
        .background(Colors.cardSurface)
        .cornerRadius(22)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .foregroundColor(Colors.textSecondary)
            }
            .backgroundCard()
        }
    }
}

struct ReminderTogglesCard: View {
    @Binding var timeReminder: Bool
    @Binding var weatherReminder: Bool
    @Binding var labelReminder: Bool
    @Binding var extraLoud: Bool

    var body: some View {
        VStack(spacing: Spacing.m) {
            ReminderRow(title: "Time reminder", isOn: $timeReminder)
            ReminderRow(title: "Weather reminder", isOn: $weatherReminder)
            ReminderRow(title: "Label reminder", isOn: $labelReminder)
            ReminderRow(title: "Extra loud effect", isOn: $extraLoud)
        }
        .backgroundCard()
    }
}

struct ReminderRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Sample")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Colors.bgSecondary)
                .cornerRadius(12)
                .foregroundColor(Colors.textSecondary)
            }
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct CustomSettingsCard: View {
    let snoozeText: String
    let onSnooze: () -> Void
    let wallpaperId: String
    let onWallpaper: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            Button(action: onSnooze) {
                HStack {
                    Text("Snooze")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text(snoozeText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                }
            }
            Divider().background(Colors.cardStroke)
            Button(action: onWallpaper) {
                HStack {
                    Text("Alarm wallpaper")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    WallpaperThumbnail(id: wallpaperId)
                }
            }
        }
        .backgroundCard()
    }
}

struct WallpaperThumbnail: View {
    let id: String

    var body: some View {
        let image = loadImage(id) ?? fallbackImage()
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: 44, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadImage(_ id: String) -> UIImage? {
        if let image = loadFromCatalog(id: id) {
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
        if let url = findWallpaperByFilename(id) {
            return UIImage(contentsOfFile: url.path)
        }
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
}
