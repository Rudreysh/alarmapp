import SwiftUI

struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum Shadows {
    static let card = AppShadow(color: Colors.shadow, radius: 18, x: 0, y: 10)
    static let button = AppShadow(color: Colors.shadow, radius: 14, x: 0, y: 8)
}

extension View {
    func appShadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
