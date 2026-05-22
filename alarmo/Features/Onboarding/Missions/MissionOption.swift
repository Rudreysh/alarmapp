import SwiftUI

struct MissionOption: Identifiable, Equatable {
    let id: WakeUpMissionType
    let title: String
    let icon: String?
    let iconBackground: Color?
}
