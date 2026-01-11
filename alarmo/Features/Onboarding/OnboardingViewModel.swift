import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    @Published var state = OnboardingState()
}
