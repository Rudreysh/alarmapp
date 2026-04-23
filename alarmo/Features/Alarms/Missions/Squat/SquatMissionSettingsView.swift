import SwiftUI

struct SquatMissionSettingsView: View {
    let initialMission: AlarmMission
    let onSave: (AlarmMission) -> Void

    init(initialMission: AlarmMission = AlarmMission(type: .squat), onSave: @escaping (AlarmMission) -> Void) {
        self.initialMission = initialMission
        self.onSave = onSave
    }

    var body: some View {
        ExerciseMissionSettingsView(
            kind: .squats,
            initialMission: initialMission,
            onSave: onSave
        )
    }
}
