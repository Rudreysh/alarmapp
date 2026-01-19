import SwiftUI
import Combine

enum SettingsRoute: Hashable {
    case advanced
    case theme
    case soundOutput
    case notification
    case system
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
