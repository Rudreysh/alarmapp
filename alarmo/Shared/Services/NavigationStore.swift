import SwiftUI
import Combine

class NavigationStore: ObservableObject {
    @Published var selectedTab: MainTab = .plan
    @Published var requestedTimerMode: TimerMode? = nil
}
