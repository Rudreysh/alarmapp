import Foundation
import Combine
import SwiftUI

final class OnboardingMissionViewModel: ObservableObject {
    @Published private(set) var options: [MissionOption]
    @Published private(set) var selected: WakeUpMissionType

    private let onboardingViewModel: OnboardingViewModel

    init(onboardingViewModel: OnboardingViewModel) {
        self.onboardingViewModel = onboardingViewModel
        self.options = [
            MissionOption(id: .math, title: "Math", icon: "plus.slash.minus", iconBackground: Colors.accentTeal.opacity(0.35)),
            MissionOption(id: .typing, title: "Typing", icon: "keyboard", iconBackground: Colors.accentTeal.opacity(0.35)),
            MissionOption(id: .findColorTiles, title: "Find Color Tiles", icon: "square.grid.2x2", iconBackground: Colors.accentTeal.opacity(0.35)),
            MissionOption(id: .shake, title: "Shake", icon: "iphone.gen3", iconBackground: Colors.accentTeal.opacity(0.2))
        ] + [
            MissionOption(id: .off, title: "Off", icon: nil, iconBackground: nil)
        ]
        self.selected = onboardingViewModel.state.missionType
    }

    func select(_ option: MissionOption) {
        selected = option.id
        onboardingViewModel.setMission(option.id)
    }
}
