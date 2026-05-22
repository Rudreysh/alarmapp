import Foundation

enum VisualSurfaceMode: String, Codable, CaseIterable, Equatable {
    case wallpaper
    case quotes
    case both

    var title: String {
        switch self {
        case .wallpaper: return "Wallpaper"
        case .quotes: return "Quotes"
        case .both: return "Both"
        }
    }
}

enum VisualOutputContentSource: String, Codable, CaseIterable, Equatable {
    case wallpaper
    case quotesOnly
    case wallpaperAndQuotes
}

enum VisualOutputWallpaperSource: String, Codable, CaseIterable, Equatable {
    case alarmWallpaper
    case separateWallpaper
    case none
}

enum VisualQuoteStyle: String, Codable, CaseIterable, Equatable {
    case minimal
    case bold
    case card
}

enum VisualQuotePosition: String, Codable, CaseIterable, Equatable {
    case top
    case center
    case bottom
}

enum VisualQuoteFrequency: String, Codable, CaseIterable, Equatable {
    case daily
    case everyUnlock
    case manualRefresh
}

struct VisualSurfaceAssignment: Codable, Equatable {
    var enabled: Bool = false
    var mode: VisualSurfaceMode = .wallpaper
    var isApplied: Bool = false
}

struct AlarmVisualOutputSettings: Codable, Equatable {
    var contentSource: VisualOutputContentSource = .wallpaper
    var wallpaperSource: VisualOutputWallpaperSource = .alarmWallpaper
    var separateWallpaperId: String? = nil
    var quoteStyle: VisualQuoteStyle = .minimal
    var quotePosition: VisualQuotePosition = .center
    var quoteFrequency: VisualQuoteFrequency = .daily

    var alarmScreen: VisualSurfaceAssignment = VisualSurfaceAssignment(enabled: true, mode: .wallpaper, isApplied: true)
    var lockScreen: VisualSurfaceAssignment = VisualSurfaceAssignment(enabled: false, mode: .wallpaper, isApplied: false)
    var homeScreen: VisualSurfaceAssignment = VisualSurfaceAssignment(enabled: false, mode: .wallpaper, isApplied: false)
    var standBy: VisualSurfaceAssignment = VisualSurfaceAssignment(enabled: false, mode: .quotes, isApplied: false)

    static func migratedFromLegacy(
        wallpaperId: String,
        dailyMotivationEnabled: Bool
    ) -> AlarmVisualOutputSettings {
        var settings = AlarmVisualOutputSettings()
        settings.contentSource = dailyMotivationEnabled ? .wallpaperAndQuotes : .wallpaper
        settings.wallpaperSource = wallpaperId.isEmpty ? .none : .alarmWallpaper
        settings.alarmScreen = VisualSurfaceAssignment(
            enabled: true,
            mode: dailyMotivationEnabled ? .both : .wallpaper,
            isApplied: true
        )
        return settings
    }

    func summaryText() -> String {
        let alarm = "Alarm: \(alarmScreen.enabled ? alarmScreen.mode.title : "Off")"
        let lock = "Lock: \(lockScreen.enabled ? (lockScreen.isApplied ? lockScreen.mode.title : "Ready") : "Off")"
        let home = "Home: \(homeScreen.enabled ? (homeScreen.isApplied ? homeScreen.mode.title : "Ready") : "Off")"
        let standby = "StandBy: \(standBy.enabled ? (standBy.isApplied ? standBy.mode.title : "Ready") : "Off")"
        return "\(alarm) • \(lock) • \(home) • \(standby)"
    }
}
