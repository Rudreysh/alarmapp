import SwiftUI
import Combine

enum SettingsRoute: Hashable {
    case points
    case pro
    case penalty
    case preventAppUninstall
    case preventPowerOff
    case alarm
    case habit
    case timer
    case advanced
    case theme
    case soundOutput
    case notification
    case alarmCapabilities
    case system
    case faq
    case optimization
    case permissions
    case notice
}

class SettingsCoordinator: ObservableObject {
    @Published var path: [SettingsRoute] = []
    
    func navigate(to route: SettingsRoute) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeAll()
    }
}
