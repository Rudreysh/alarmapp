import SwiftUI

enum Typography {
    static let heroTitle = Font.system(.largeTitle, design: .default).weight(.black)
    static let screenTitle = Font.system(.title, design: .default).weight(.bold)
    static let cardTitle = Font.system(.headline, design: .default).weight(.semibold)
    static let bodyText = Font.system(.body, design: .default)
    static let captionText = Font.system(.caption, design: .default)
    
    // Additional helpers for large numbers
    static let hugeNumber = Font.system(size: 80, weight: .bold, design: .rounded)
}

extension View {
    func heroTitle() -> some View { font(Typography.heroTitle) }
    func screenTitle() -> some View { font(Typography.screenTitle) }
    func cardTitle() -> some View { font(Typography.cardTitle) }
    func bodyText() -> some View { font(Typography.bodyText) }
    func captionText() -> some View { font(Typography.captionText) }
}
