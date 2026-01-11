import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    @Published private(set) var state = OnboardingState()

    var selectedHour: Int {
        get { state.selectedHour }
        set { state.selectedHour = newValue }
    }

    var selectedMinute: Int {
        get { state.selectedMinute }
        set { state.selectedMinute = newValue }
    }

    var selectedTimeString: String {
        TimeFormatters.formattedTime(hour: selectedHour, minute: selectedMinute)
    }

    func nextStep() {
        guard let next = state.currentStep.next() else { return }
        state.currentStep = next
    }
}
