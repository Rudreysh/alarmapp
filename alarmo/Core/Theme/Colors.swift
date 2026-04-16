import SwiftUI
import Foundation

enum Colors {
    private static let themeKey = "settings.alarmThemeStyleRaw"

    private struct Palette {
        let bgPrimary: Color
        let bgSecondary: Color
        let cardSurface: Color
        let cardStroke: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let accentRed: Color
        let accentGreen: Color
        let accentTeal: Color
        let shadow: Color
        let tabBarBackground: Color
        let tabBarInactive: Color
        let promoCardBackground: Color
        let pillGreen: Color
        let sheetGradientTop: Color
        let sheetGradientBottom: Color
        let saleBadgeStart: Color
        let saleBadgeEnd: Color
        let accentOrange: Color
        let accentBlue: Color
    }

    private static let defaultPalette = Palette(
        bgPrimary: Color(red: 0.05, green: 0.06, blue: 0.07),
        bgSecondary: Color(red: 0.08, green: 0.09, blue: 0.13),
        cardSurface: Color(red: 0.10, green: 0.11, blue: 0.17),
        cardStroke: Color.white.opacity(0.08),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.7),
        textTertiary: Color.white.opacity(0.4),
        accentRed: Color(red: 1.0, green: 0.23, blue: 0.36),
        accentGreen: Color(red: 0.20, green: 0.78, blue: 0.35),
        accentTeal: Color(red: 0.0, green: 0.70, blue: 0.78),
        shadow: Color.black.opacity(0.45),
        tabBarBackground: Color(red: 0.08, green: 0.09, blue: 0.12),
        tabBarInactive: Color.white.opacity(0.45),
        promoCardBackground: Color(red: 0.12, green: 0.13, blue: 0.18),
        pillGreen: Color(red: 0.20, green: 0.78, blue: 0.45),
        sheetGradientTop: Color(red: 0.13, green: 0.10, blue: 0.36),
        sheetGradientBottom: Color(red: 0.09, green: 0.08, blue: 0.22),
        saleBadgeStart: Color(red: 0.82, green: 0.65, blue: 1.0),
        saleBadgeEnd: Color(red: 0.64, green: 0.44, blue: 0.98),
        accentOrange: .orange,
        accentBlue: .blue
    )

    private static let lilacCalmPalette = Palette(
        bgPrimary: Color(red: 0.980, green: 0.984, blue: 0.984),          // #FAFBFB
        bgSecondary: Color(red: 0.953, green: 0.937, blue: 0.973),        // #F3EFF8
        cardSurface: .white,                                               // #FFFFFF
        cardStroke: Color(red: 0.063, green: 0.055, blue: 0.063).opacity(0.08), // rgba(16,14,16,0.08)
        textPrimary: Color(red: 0.063, green: 0.055, blue: 0.063),        // #100E10
        textSecondary: Color(red: 0.431, green: 0.412, blue: 0.459),      // #6E6975
        textTertiary: Color(red: 0.604, green: 0.584, blue: 0.639),       // #9A95A3
        accentRed: Color(red: 0.851, green: 0.227, blue: 0.322),          // #D93A52
        accentGreen: Color(red: 0.122, green: 0.659, blue: 0.353),        // #1FA85A
        accentTeal: Color(red: 0.498, green: 0.682, blue: 0.694),         // #7FAEB1
        shadow: Color(red: 0.129, green: 0.086, blue: 0.212).opacity(0.12), // rgba(33,22,54,0.12)
        tabBarBackground: .white,                                          // #FFFFFF
        tabBarInactive: Color(red: 0.561, green: 0.541, blue: 0.592),     // #8F8A97
        promoCardBackground: Color(red: 0.937, green: 0.914, blue: 0.969), // #EFE9F7
        pillGreen: Color(red: 0.122, green: 0.659, blue: 0.353),          // #1FA85A
        sheetGradientTop: Color(red: 0.843, green: 0.804, blue: 0.969),   // #D7CDF7
        sheetGradientBottom: Color(red: 0.757, green: 0.675, blue: 0.941), // #C1ACF0
        saleBadgeStart: Color(red: 0.843, green: 0.804, blue: 0.969),     // #D7CDF7
        saleBadgeEnd: Color(red: 0.757, green: 0.675, blue: 0.941),       // #C1ACF0
        accentOrange: Color(red: 0.788, green: 0.424, blue: 0.0),         // #C96C00
        accentBlue: Color(red: 0.573, green: 0.478, blue: 0.890)          // #927AE3
    )

    private static var activePalette: Palette {
        let raw = UserDefaults.standard.string(forKey: themeKey) ?? "default"
        return raw == "lilac_calm" ? lilacCalmPalette : defaultPalette
    }

    static var bgPrimary: Color { activePalette.bgPrimary }
    static var bgSecondary: Color { activePalette.bgSecondary }
    static var cardSurface: Color { activePalette.cardSurface }
    static var cardStroke: Color { activePalette.cardStroke }
    static var textPrimary: Color { activePalette.textPrimary }
    static var textSecondary: Color { activePalette.textSecondary }
    static var textTertiary: Color { activePalette.textTertiary }
    static var accentRed: Color { activePalette.accentRed }
    static var accentGreen: Color { activePalette.accentGreen }
    static var accentTeal: Color { activePalette.accentTeal }
    static var shadow: Color { activePalette.shadow }
    static var tabBarBackground: Color { activePalette.tabBarBackground }
    static var tabBarInactive: Color { activePalette.tabBarInactive }
    static var promoCardBackground: Color { activePalette.promoCardBackground }
    static var pillGreen: Color { activePalette.pillGreen }
    static var sheetGradientTop: Color { activePalette.sheetGradientTop }
    static var sheetGradientBottom: Color { activePalette.sheetGradientBottom }
    static var saleBadgeStart: Color { activePalette.saleBadgeStart }
    static var saleBadgeEnd: Color { activePalette.saleBadgeEnd }
    static var accentOrange: Color { activePalette.accentOrange }
    static var accentBlue: Color { activePalette.accentBlue }
}
