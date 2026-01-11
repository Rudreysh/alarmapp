import SwiftUI

enum Typography {
    static let heroTitle = Font.system(size: 40, weight: .black)
    static let screenTitle = Font.system(size: 34, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let bodyText = Font.system(size: 17, weight: .regular)
    static let captionText = Font.system(size: 13, weight: .regular)
}

extension View {
    func heroTitle() -> some View { font(Typography.heroTitle) }
    func screenTitle() -> some View { font(Typography.screenTitle) }
    func cardTitle() -> some View { font(Typography.cardTitle) }
    func bodyText() -> some View { font(Typography.bodyText) }
    func captionText() -> some View { font(Typography.captionText) }
}
