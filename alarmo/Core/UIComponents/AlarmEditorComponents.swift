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
        VStack(spacing: 0) {
            // 1. Header Row (Includes First Mission)
            HStack(alignment: .center, spacing: 0) {
                // Left: Label Section
                HStack(spacing: 10) {
                     ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Colors.accentOrange.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.accentOrange)
                    }
                    
                    Text("Missions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
                
                Spacer()
                
                // Right: First Mission (Styled as a Chip)
                if let first = missions.first {
                    AlarmMissionChip(mission: first, onRemove: {
                        onRemoveMission(0)
                    })
                    .onTapGesture { onEditMission(0) }
                } else {
                    Text("Off")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .onTapGesture(perform: onAddMission)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 10) // Slightly tighter padding for the 25pt chips
            
            // 2. Extra Missions Row (Horizontal Chips + Add Button)
            if !missions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 1. Extra Chips (Skip first one)
                        ForEach(Array(missions.dropFirst().enumerated()), id: \.offset) { index, mission in
                            let actualIndex = index + 1
                            AlarmMissionChip(mission: mission, onRemove: {
                                onRemoveMission(actualIndex)
                            })
                            .onTapGesture { onEditMission(actualIndex) }
                        }
                        
                        // 2. Inline Add Button
                        if missions.count < 5 {
                            Button(action: onAddMission) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 25) // Match Chip Height
                                .background(Colors.bgSecondary)
                                .foregroundColor(Colors.accentBlue)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                }
                .frame(height: 25) 
                .padding(.bottom, 10)
            }
            
            Divider().padding(.leading, 56)

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
                .padding(Spacing.m)
            }
        }
        .backgroundCard()
    }
}

// Compact Chip Component
struct AlarmMissionChip: View {
    let mission: AlarmMission
    let onRemove: () -> Void
    var height: CGFloat = 25
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Colors.bgPrimary.opacity(0.8))
                    .frame(width: 18, height: 18)
                
                Image(systemName: mission.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(Colors.textPrimary)
            }
            
            Text(mission.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(3)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 6)
        .frame(height: height) // Use custom height
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [Colors.accentBlue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .shadow(color: Colors.accentBlue.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}


struct AlarmSoundCard: View {
    let soundName: String
    let isBuffering: Bool
    let isPlaying: Bool
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
                            } else if isPlaying {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Colors.textPrimary)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
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
