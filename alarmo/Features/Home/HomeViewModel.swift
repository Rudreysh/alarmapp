import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var showCelebration = false
    @Published var showDiscountPaywall = false

    let preferences: AppPreferencesProtocol
    private var didHandleAppear = false
    private var pendingPaywallAfterCelebration = false

    init(preferences: AppPreferencesProtocol) {
        self.preferences = preferences
    }

    func onAppear() {
        guard !didHandleAppear else { return }
        didHandleAppear = true

        // Show first-run discount flow only once (first time Alarm screen appears).
        if !preferences.hasShownFirstHomeDiscountFlow {
            preferences.hasShownFirstHomeDiscountFlow = true
            pendingPaywallAfterCelebration = true
            showCelebration = true
        }
    }

    func tapProBanner() {
        presentPaywall()
    }

    func tapRemoveAds() {
        if preferences.devAlwaysShowUpsell {
            pendingPaywallAfterCelebration = true
            showCelebration = true
            return
        }
        if !preferences.hasTappedRemoveAdsBefore {
            preferences.hasTappedRemoveAdsBefore = true
            pendingPaywallAfterCelebration = true
            showCelebration = true
        } else {
            presentPaywall()
        }
    }

    func celebrationDidFinish() {
        showCelebration = false
        if pendingPaywallAfterCelebration {
            pendingPaywallAfterCelebration = false
            presentPaywall()
        }
    }

    func dismissPaywall() {
        showDiscountPaywall = false
    }

    private func presentPaywall() {
        preferences.hasSeenPaywallAtLeastOnce = true
        showDiscountPaywall = true
    }

}
