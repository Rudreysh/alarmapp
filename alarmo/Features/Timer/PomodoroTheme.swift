import SwiftUI

enum PomodoroThemeKind {
    case focus, `break`
}

struct PomodoroTheme {
    let kind: PomodoroThemeKind
    
    var background: Color {
        kind == .focus ? Color(hex: "4D1A1A") : Color(hex: "1A2B4D") // Approximate Focus Keeper colors
    }
    
    var primaryText: Color { .white }
    
    var secondaryText: Color { .white.opacity(0.8) }
    
    var dimmedText: Color { .white.opacity(0.4) }
    
    var pillBg: Color { .white.opacity(0.15) }
    
    var buttonBg: Color { .white.opacity(0.1) }
    
    var dialTick: Color { .white.opacity(0.6) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
