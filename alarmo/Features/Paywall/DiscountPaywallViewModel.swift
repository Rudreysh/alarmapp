import Foundation
import Combine

final class DiscountPaywallViewModel: ObservableObject {
    @Published var isExitDiscountDialogPresented = false
    @Published var toastMessage: String?
    @Published var offerPlanName: String = "YEARLY"
    @Published var offerPriceText: String = "Price at checkout"
    @Published var offerBillingText: String = "Localized price shown at checkout"
    @Published var offerTrialText: String?
    @Published var offerOldPriceText: String?
    @Published var offerBadgeText: String = "Offer"
    @Published var showDiscountBadge: Bool = false
    @Published private(set) var isLoading: Bool = false

    private let preferences: AppPreferencesProtocol
    private let purchaseService: PurchaseService
    private var didLoadPricing = false
    private var selectedProduct: PaywallProduct?
    var onRequestDismissPaywall: (() -> Void)?
    var onRequestGetOffer: (() -> Void)?
    var onPurchaseSucceeded: (() -> Void)?

    init(preferences: AppPreferencesProtocol, purchaseService: PurchaseService = StoreKitPurchaseService()) {
        self.preferences = preferences
        self.purchaseService = purchaseService
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

    @MainActor
    func loadPricingIfNeeded() async {
        guard !didLoadPricing else { return }
        didLoadPricing = true

        do {
            let products = try await purchaseService.loadProducts()
            if let target = pickOfferProduct(from: products) {
                applyPricing(from: target)
                return
            }
        } catch {
            // Fallback below.
        }

        if let fallback = pickOfferProduct(from: ProProductCatalog.fallbackProducts()) {
            applyPricing(from: fallback)
        }
    }

    private func pickOfferProduct(from products: [PaywallProduct]) -> PaywallProduct? {
        products.first(where: { $0.plan == .yearly }) ?? products.first
    }

    @MainActor
    private func applyPricing(from product: PaywallProduct) {
        offerPlanName = product.displayName.uppercased()
        offerPriceText = product.priceString
        offerBillingText = product.billingPeriodString.isEmpty ? "Localized price shown at checkout" : product.billingPeriodString
        offerTrialText = product.trialText
        offerOldPriceText = product.oldPriceString
        offerBadgeText = product.discountBadgeText ?? "Offer"
        showDiscountBadge = product.oldPriceString != nil
        selectedProduct = product
    }

    @MainActor
    func purchaseOffer() async {
        guard let product = selectedProduct else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await purchaseService.purchase(product)
            switch result {
            case .success:
                await SubscriptionManager.shared.refreshEntitlements()
                #if DEBUG
                if !SubscriptionManager.shared.isPro {
                    SubscriptionManager.shared.isPro = true
                }
                #endif
                if SubscriptionManager.shared.isPro {
                    onPurchaseSucceeded?()
                } else {
                    toastMessage = "Purchase completed but Pro is not yet active."
                }
            case .cancelled:
                break
            case .pending:
                toastMessage = "Your purchase is pending."
            case .failed(let message):
                toastMessage = message
            }
        } catch {
            toastMessage = "Purchase failed. Please try again."
        }
    }
}
