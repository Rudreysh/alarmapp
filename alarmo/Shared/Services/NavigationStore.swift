import SwiftUI
import Combine

class NavigationStore: ObservableObject {
    @Published var selectedTab: MainTab = .alarm
    @Published var requestedTimerMode: TimerMode? = nil
    @Published var shouldOpenAddMenu: Bool = false
}
