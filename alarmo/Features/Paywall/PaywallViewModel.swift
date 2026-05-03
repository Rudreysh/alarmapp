import Foundation
import Combine

final class PaywallViewModel: ObservableObject {
    @Published private(set) var products: [PaywallProduct] = []
    @Published var selectedPlan: PaywallPlan = .yearly
    /// Non-nil when an alert should be shown.
    @Published var alertMessage: String?
    /// True while a purchase or restore is in flight — use this to disable buttons.
    @Published private(set) var isLoading: Bool = false
    /// Flips to true exactly once on a successful purchase so the caller can dismiss.
    @Published private(set) var purchaseSucceeded: Bool = false

    private let purchaseService: PurchaseService
    private var entitlementStore: EntitlementStoreProtocol

    init(purchaseService: PurchaseService = StoreKitPurchaseService(),
         entitlementStore: EntitlementStoreProtocol = EntitlementStore()) {
        self.purchaseService = purchaseService
        self.entitlementStore = entitlementStore
    }

    @MainActor
    func load() async {
        do {
            let loaded = try await purchaseService.loadProducts()
            products = loaded
        } catch {
            products = ProProductCatalog.fallbackProducts()
            print("[Paywall] Failed to load StoreKit products, using fallback: \(error)")
        }
    }

    func selectPlan(_ plan: PaywallPlan) {
        selectedPlan = plan
    }

    func selectedProduct() -> PaywallProduct? {
        products.first { $0.plan == selectedPlan }
    }

    @MainActor
    func purchaseSelected() async {
        guard !isLoading else { return }

        guard let product = selectedProduct() else {
            print("[Paywall] No product found for plan \(selectedPlan). Products loaded: \(products.count)")
            alertMessage = "Selected plan is not available right now. Please try again."
            return
        }

        isLoading = true
        defer { isLoading = false }

        print("[Paywall] Starting purchase for product: \(product.id) plan: \(product.plan)")

        do {
            let result = try await purchaseService.purchase(product)
            switch result {
            case .success:
                await SubscriptionManager.shared.refreshEntitlements()
                entitlementStore.isPro = SubscriptionManager.shared.isPro

                // Force-unlock only in Simulator where no real StoreKit transactions exist.
                #if targetEnvironment(simulator)
                if !SubscriptionManager.shared.isPro {
                    print("[Paywall] (Simulator) Forcing Pro unlock for UI testing.")
                    SubscriptionManager.shared.isPro = true
                    entitlementStore.isPro = true
                }
                #endif

                if SubscriptionManager.shared.isPro {
                    print("[Paywall] Purchase succeeded — Pro unlocked")
                    purchaseSucceeded = true
                } else {
                    alertMessage = "Purchase completed but Pro is not yet active. Tap 'Restore Purchases' if it doesn't unlock shortly."
                }

            case .cancelled:
                print("[Paywall] Purchase cancelled by user")
                // No alert needed — user knowingly cancelled

            case .pending:
                print("[Paywall] Purchase pending (requires additional action)")
                alertMessage = "Your purchase is pending. Pro will unlock once payment clears."

            case .failed(let message):
                print("[Paywall] Purchase failed: \(message)")
                alertMessage = message
            }
        } catch {
            print("[Paywall] Purchase threw error: \(error)")
            alertMessage = "Purchase failed. Please try again."
        }
    }

    @MainActor
    func restorePurchases() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        print("[Paywall] Restoring purchases…")
        do {
            try await purchaseService.restorePurchases()
            await SubscriptionManager.shared.refreshEntitlements()
            entitlementStore.isPro = SubscriptionManager.shared.isPro
            if SubscriptionManager.shared.isPro {
                print("[Paywall] Restore succeeded — Pro active")
                purchaseSucceeded = true
            } else {
                alertMessage = "No active Pro purchase found. Purchase a plan to get started."
            }
        } catch {
            print("[Paywall] Restore failed: \(error)")
            alertMessage = "Could not restore purchases. Please check your internet connection and try again."
        }
    }
}
