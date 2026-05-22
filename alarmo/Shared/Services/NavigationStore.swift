import SwiftUI
import Combine

class NavigationStore: ObservableObject {
    @Published var selectedTab: MainTab {
        didSet {
            defaults.set(selectedTab.rawValue, forKey: Keys.selectedTab)
        }
    }
    @Published var requestedTimerMode: TimerMode? = nil
    @Published var shouldOpenAddMenu: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedRawValue = defaults.string(forKey: Keys.selectedTab),
           let storedTab = MainTab(rawValue: storedRawValue) {
            self.selectedTab = storedTab
        } else {
            self.selectedTab = .alarm
        }
    }

    private enum Keys {
        static let selectedTab = "alarmo.navigation.selectedTab"
    }
}
