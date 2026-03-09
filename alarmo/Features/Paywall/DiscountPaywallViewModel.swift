import Foundation
import Combine

final class DiscountPaywallViewModel: ObservableObject {
    @Published var isExitDiscountDialogPresented = false
    @Published var toastMessage: String?

    private let preferences: AppPreferencesProtocol
    var onRequestDismissPaywall: (() -> Void)?
    var onRequestGetOffer: (() -> Void)?

    init(preferences: AppPreferencesProtocol) {
        self.preferences = preferences
    }

    @MainActor
    func onTapUseCoupon() {
        preferences.hasSeenDiscountExitDialog = true
        isExitDiscountDialogPresented = true
    }

    @MainActor
    func onConfirmExitDiscount() {
        isExitDiscountDialogPresented = false
        onRequestDismissPaywall?()
    }

    @MainActor
    func onConfirmGetOffer() {
        isExitDiscountDialogPresented = false
        preferences.hasTappedGetOfferFromDiscount = true
        toastMessage = nil
        onRequestGetOffer?()
    }
}
