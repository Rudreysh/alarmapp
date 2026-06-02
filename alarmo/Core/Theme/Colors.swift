import SwiftUI
import Foundation
import UIKit
import Combine

enum Colors {
    private static let themeStyleKey = "settings.alarmThemeStyleRaw"
    private static let themeModeKey = "settings.themeMode"

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

    private static let lightPalette = Palette(
        bgPrimary: Color(red: 0.975, green: 0.978, blue: 0.982),
        bgSecondary: Color(red: 0.942, green: 0.951, blue: 0.965),
        cardSurface: .white,
        cardStroke: Color.black.opacity(0.08),
        textPrimary: Color(red: 0.078, green: 0.094, blue: 0.125),
        textSecondary: Color(red: 0.288, green: 0.338, blue: 0.425),
        textTertiary: Color(red: 0.482, green: 0.537, blue: 0.631),
        accentRed: Color(red: 0.867, green: 0.216, blue: 0.333),
        accentGreen: Color(red: 0.122, green: 0.659, blue: 0.353),
        accentTeal: Color(red: 0.112, green: 0.612, blue: 0.698),
        shadow: Color.black.opacity(0.12),
        tabBarBackground: .white,
        tabBarInactive: Color(red: 0.545, green: 0.580, blue: 0.651),
        promoCardBackground: Color(red: 0.937, green: 0.953, blue: 0.976),
        pillGreen: Color(red: 0.122, green: 0.659, blue: 0.353),
        sheetGradientTop: Color(red: 0.905, green: 0.943, blue: 0.992),
        sheetGradientBottom: Color(red: 0.839, green: 0.906, blue: 0.984),
        saleBadgeStart: Color(red: 0.706, green: 0.851, blue: 0.980),
        saleBadgeEnd: Color(red: 0.522, green: 0.769, blue: 0.965),
        accentOrange: Color(red: 0.788, green: 0.424, blue: 0.0),
        accentBlue: Color(red: 0.279, green: 0.489, blue: 0.906)
    )

    private static let tiimoPalette = Palette(
        bgPrimary: Color(hex: "#F9F8F6"),
        bgSecondary: Color(hex: "#F0EFFE"),
        cardSurface: Color(hex: "#FFFFFF"),
        cardStroke: Color(hex: "#F0EFFE"),
        textPrimary: Color(hex: "#1A1A1A"),
        textSecondary: Color(hex: "#6B6B6B"),
        textTertiary: Color(hex: "#9490A6"),
        accentRed: Color(red: 1.0, green: 0.23, blue: 0.36),
        accentGreen: Color(red: 0.20, green: 0.78, blue: 0.35),
        accentTeal: Color(hex: "#7F77DD"),
        shadow: Color.black.opacity(0.02),
        tabBarBackground: Color(hex: "#FFFFFF"),
        tabBarInactive: Color(hex: "#B0AABF"),
        promoCardBackground: Color(hex: "#F0EFFE"),
        pillGreen: Color(hex: "#E8E4F5"),
        sheetGradientTop: Color(hex: "#F1EEF8"),
        sheetGradientBottom: Color(hex: "#E8E4F5"),
        saleBadgeStart: Color(hex: "#C4BCFF"),
        saleBadgeEnd: Color(hex: "#7F77DD"),
        accentOrange: Color(hex: "#7F77DD"),
        accentBlue: Color(hex: "#7F77DD")
    )

    private static let meadowCreamPalette = Palette(
        bgPrimary: Color(hex: "#FFF5E6"),
        bgSecondary: Color(hex: "#FFF9F1"),
        cardSurface: Color(hex: "#FFFFFF"),
        cardStroke: Color(hex: "#D4F5E9"),
        textPrimary: Color(hex: "#6B4C3B"),
        textSecondary: Color(hex: "#9F8A7A"),
        textTertiary: Color(hex: "#C4B5A8"),
        accentRed: Color(hex: "#D45E4A"),
        accentGreen: Color(hex: "#7DC395"),
        accentTeal: Color(hex: "#7DC395"),
        shadow: Color(hex: "#6B4C3B").opacity(0.10),
        tabBarBackground: Color(hex: "#FFFFFF"),
        tabBarInactive: Color(hex: "#B39E8D"),
        promoCardBackground: Color(hex: "#F6FFFA"),
        pillGreen: Color(hex: "#A8E6CF"),
        sheetGradientTop: Color(hex: "#FFF5E6"),
        sheetGradientBottom: Color(hex: "#FFFDF8"),
        saleBadgeStart: Color(hex: "#A8E6CF"),
        saleBadgeEnd: Color(hex: "#7DC395"),
        accentOrange: Color(hex: "#FCB13A"),
        accentBlue: Color(hex: "#7DC395")
    )

    private static let greenPalette = Palette(
        bgPrimary: Color(hex: "#0D1A14"),
        bgSecondary: Color(hex: "#12231B"),
        cardSurface: Color(hex: "#173126"),
        cardStroke: Color(hex: "#2C5947"),
        textPrimary: Color(hex: "#E9FFF4"),
        textSecondary: Color(hex: "#B9E3CF"),
        textTertiary: Color(hex: "#7FB49B"),
        accentRed: Color(red: 1.0, green: 0.23, blue: 0.36),
        accentGreen: Color(hex: "#57D28C"),
        accentTeal: Color(hex: "#35B86F"),
        shadow: Color.black.opacity(0.42),
        tabBarBackground: Color(hex: "#12261D"),
        tabBarInactive: Color(hex: "#8BC2A8"),
        promoCardBackground: Color(hex: "#1A382C"),
        pillGreen: Color(hex: "#57D28C"),
        sheetGradientTop: Color(hex: "#1D3E30"),
        sheetGradientBottom: Color(hex: "#143126"),
        saleBadgeStart: Color(hex: "#7AE8AA"),
        saleBadgeEnd: Color(hex: "#35B86F"),
        accentOrange: Color(hex: "#7AE8AA"),
        accentBlue: Color(hex: "#57D28C")
    )

    private static var activePalette: Palette {
        let styleRaw = UserDefaults.standard.string(forKey: themeStyleKey) ?? "default"
        if styleRaw == "lilac_calm" {
            return lilacCalmPalette
        }
        if styleRaw == "tiimo" {
            return tiimoPalette
        }
        if styleRaw == "meadow_cream" {
            return meadowCreamPalette
        }
        if styleRaw == "green" {
            return greenPalette
        }

        let modeRaw = UserDefaults.standard.string(forKey: themeModeKey) ?? "Dark"
        switch modeRaw {
        case "Light":
            return lightPalette
        case "Follow system setting":
            let isSystemLight = UIScreen.main.traitCollection.userInterfaceStyle == .light
            return isSystemLight ? lightPalette : defaultPalette
        default:
            return defaultPalette
        }
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

protocol AppTheme {
    var backgroundPrimary: Color { get }
    var backgroundSurface: Color { get }
    var backgroundCard: Color { get }
    var accentPrimary: Color { get }
    var accentSecondary: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textCaption: Color { get }
    var buttonPrimaryBg: Color { get }
    var buttonPrimaryLabel: Color { get }
    var selectionFill: Color { get }
    var selectionBorder: Color { get }
    var progressTrack: Color { get }
    var progressFill: Color { get }
    var cornerRadiusCard: CGFloat { get }
    var cornerRadiusButton: CGFloat { get }
    var cornerRadiusPill: CGFloat { get }
    var switchTintOn: Color { get }
}

struct DefaultDarkTheme: AppTheme {
    let backgroundPrimary = Color(red: 0.05, green: 0.06, blue: 0.07)
    let backgroundSurface = Color(red: 0.08, green: 0.09, blue: 0.13)
    let backgroundCard = Color(red: 0.10, green: 0.11, blue: 0.17)
    let accentPrimary = Color(red: 0.0, green: 0.70, blue: 0.78)
    let accentSecondary = Color.white.opacity(0.08)
    let textPrimary = Color.white
    let textSecondary = Color.white.opacity(0.7)
    let textCaption = Color.white.opacity(0.4)
    let buttonPrimaryBg = Color(red: 0.0, green: 0.70, blue: 0.78)
    let buttonPrimaryLabel = Color.white
    let selectionFill = Color(red: 0.0, green: 0.70, blue: 0.78)
    let selectionBorder = Color.white.opacity(0.08)
    let progressTrack = Color.white.opacity(0.08)
    let progressFill = Color(red: 0.0, green: 0.70, blue: 0.78)
    let cornerRadiusCard: CGFloat = 16
    let cornerRadiusButton: CGFloat = 16
    let cornerRadiusPill: CGFloat = 8
    let switchTintOn = Color(red: 0.0, green: 0.70, blue: 0.78)
}

struct DefaultLightTheme: AppTheme {
    let backgroundPrimary = Color(red: 0.975, green: 0.978, blue: 0.982)
    let backgroundSurface = Color(red: 0.942, green: 0.951, blue: 0.965)
    let backgroundCard = Color.white
    let accentPrimary = Color(red: 0.112, green: 0.612, blue: 0.698)
    let accentSecondary = Color.black.opacity(0.08)
    let textPrimary = Color(red: 0.078, green: 0.094, blue: 0.125)
    let textSecondary = Color(red: 0.288, green: 0.338, blue: 0.425)
    let textCaption = Color(red: 0.482, green: 0.537, blue: 0.631)
    let buttonPrimaryBg = Color(red: 0.112, green: 0.612, blue: 0.698)
    let buttonPrimaryLabel = Color.white
    let selectionFill = Color(red: 0.112, green: 0.612, blue: 0.698)
    let selectionBorder = Color.black.opacity(0.08)
    let progressTrack = Color.black.opacity(0.08)
    let progressFill = Color(red: 0.112, green: 0.612, blue: 0.698)
    let cornerRadiusCard: CGFloat = 16
    let cornerRadiusButton: CGFloat = 16
    let cornerRadiusPill: CGFloat = 8
    let switchTintOn = Color(red: 0.112, green: 0.612, blue: 0.698)
}

struct LilacCalmTheme: AppTheme {
    let backgroundPrimary = Color(red: 0.980, green: 0.984, blue: 0.984)
    let backgroundSurface = Color(red: 0.953, green: 0.937, blue: 0.973)
    let backgroundCard = Color.white
    let accentPrimary = Color(red: 0.498, green: 0.682, blue: 0.694)
    let accentSecondary = Color(red: 0.063, green: 0.055, blue: 0.063).opacity(0.08)
    let textPrimary = Color(red: 0.063, green: 0.055, blue: 0.063)
    let textSecondary = Color(red: 0.431, green: 0.412, blue: 0.459)
    let textCaption = Color(red: 0.604, green: 0.584, blue: 0.639)
    let buttonPrimaryBg = Color(red: 0.498, green: 0.682, blue: 0.694)
    let buttonPrimaryLabel = Color.white
    let selectionFill = Color(red: 0.498, green: 0.682, blue: 0.694)
    let selectionBorder = Color(red: 0.063, green: 0.055, blue: 0.063).opacity(0.08)
    let progressTrack = Color(red: 0.063, green: 0.055, blue: 0.063).opacity(0.08)
    let progressFill = Color(red: 0.498, green: 0.682, blue: 0.694)
    let cornerRadiusCard: CGFloat = 16
    let cornerRadiusButton: CGFloat = 16
    let cornerRadiusPill: CGFloat = 8
    let switchTintOn = Color(red: 0.498, green: 0.682, blue: 0.694)
}

struct TiimoLightTheme: AppTheme {
    let backgroundPrimary = Color(hex: "#F9F8F6")
    let backgroundSurface = Color(hex: "#FFFFFF")
    let backgroundCard = Color(hex: "#FFFFFF")
    let accentPrimary = Color(hex: "#7F77DD")
    let accentSecondary = Color(hex: "#F0EFFE")
    let textPrimary = Color(hex: "#1A1A1A")
    let textSecondary = Color(hex: "#6B6B6B")
    let textCaption = Color(hex: "#9490A6")
    let buttonPrimaryBg = Color(hex: "#111111")
    let buttonPrimaryLabel = Color.white
    let selectionFill = Color(hex: "#F0EFFE")
    let selectionBorder = Color(hex: "#7F77DD")
    let progressTrack = Color(hex: "#E8E4F5")
    let progressFill = Color(hex: "#7F77DD")
    let cornerRadiusCard: CGFloat = 20
    let cornerRadiusButton: CGFloat = 100
    let cornerRadiusPill: CGFloat = 48
    let switchTintOn = Color(hex: "#7F77DD")
}

struct MeadowCreamTheme: AppTheme {
    let backgroundPrimary = Color(hex: "#FFF5E6")
    let backgroundSurface = Color(hex: "#FFF9F1")
    let backgroundCard = Color(hex: "#FFFFFF")
    let accentPrimary = Color(hex: "#7DC395")
    let accentSecondary = Color(hex: "#D4F5E9")
    let textPrimary = Color(hex: "#6B4C3B")
    let textSecondary = Color(hex: "#9F8A7A")
    let textCaption = Color(hex: "#C4B5A8")
    let buttonPrimaryBg = Color(hex: "#7DC395")
    let buttonPrimaryLabel = Color(hex: "#6B4C3B")
    let selectionFill = Color(hex: "#D4F5E9")
    let selectionBorder = Color(hex: "#A8E6CF")
    let progressTrack = Color(hex: "#EDE1D3")
    let progressFill = Color(hex: "#7DC395")
    let cornerRadiusCard: CGFloat = 20
    let cornerRadiusButton: CGFloat = 100
    let cornerRadiusPill: CGFloat = 48
    let switchTintOn = Color(hex: "#7DC395")
}

struct GreenTheme: AppTheme {
    let backgroundPrimary = Color(hex: "#0D1A14")
    let backgroundSurface = Color(hex: "#12231B")
    let backgroundCard = Color(hex: "#173126")
    let accentPrimary = Color(hex: "#35B86F")
    let accentSecondary = Color(hex: "#224638")
    let textPrimary = Color(hex: "#E9FFF4")
    let textSecondary = Color(hex: "#B9E3CF")
    let textCaption = Color(hex: "#7FB49B")
    let buttonPrimaryBg = Color(hex: "#35B86F")
    let buttonPrimaryLabel = Color(hex: "#0D1A14")
    let selectionFill = Color(hex: "#224638")
    let selectionBorder = Color(hex: "#57D28C")
    let progressTrack = Color(hex: "#224638")
    let progressFill = Color(hex: "#57D28C")
    let cornerRadiusCard: CGFloat = 16
    let cornerRadiusButton: CGFloat = 16
    let cornerRadiusPill: CGFloat = 8
    let switchTintOn = Color(hex: "#57D28C")
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var activeTheme: AppTheme = TiimoLightTheme()
    
    private init() {
        updateTheme()
    }
    
    func updateTheme() {
        let themeStyleKey = "settings.alarmThemeStyleRaw"
        let themeModeKey = "settings.themeMode"
        
        let styleRaw = UserDefaults.standard.string(forKey: themeStyleKey) ?? "default"
        
        if styleRaw == "lilac_calm" {
            activeTheme = LilacCalmTheme()
            return
        }
        if styleRaw == "tiimo" {
            activeTheme = TiimoLightTheme()
            return
        }
        if styleRaw == "meadow_cream" {
            activeTheme = MeadowCreamTheme()
            return
        }
        if styleRaw == "green" {
            activeTheme = GreenTheme()
            return
        }
        
        let modeRaw = UserDefaults.standard.string(forKey: themeModeKey) ?? "Dark"
        switch modeRaw {
        case "Light":
            activeTheme = DefaultLightTheme()
        case "Follow system setting":
            let isSystemLight = UIScreen.main.traitCollection.userInterfaceStyle == .light
            activeTheme = isSystemLight ? DefaultLightTheme() : DefaultDarkTheme()
        default:
            activeTheme = DefaultDarkTheme()
        }
    }
}
