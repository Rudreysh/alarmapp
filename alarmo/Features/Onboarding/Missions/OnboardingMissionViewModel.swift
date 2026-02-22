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
            MissionOption(id: .math, title: "Math", icon: "x.squareroot", iconBackground: Colors.accentTeal.opacity(0.2)),
            MissionOption(id: .typing, title: "Typing", icon: "character.textbox", iconBackground: Colors.accentTeal.opacity(0.2)),
            MissionOption(id: .findColorTiles, title: "Memory", icon: "square.grid.3x3.fill", iconBackground: Colors.accentTeal.opacity(0.2)),
            MissionOption(id: .shake, title: "Shake", icon: "iphone.radiowaves.left.and.right", iconBackground: Colors.accentTeal.opacity(0.2))
        ] + [
            MissionOption(id: .off, title: "No Mission", icon: "moon.zzz.fill", iconBackground: Colors.cardSurface)
        ]
        self.selected = onboardingViewModel.state.missionType
    }

    func select(_ option: MissionOption) {
        selected = option.id
        onboardingViewModel.setMission(option.id)
    }
}
