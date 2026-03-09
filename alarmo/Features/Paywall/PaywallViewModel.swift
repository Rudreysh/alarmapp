import Foundation
import Combine

final class PaywallViewModel: ObservableObject {
    @Published private(set) var products: [PaywallProduct] = []
    @Published var selectedPlan: PaywallPlan = .yearly
    @Published var alertMessage: String?

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
            alertMessage = "Unable to load products."
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
        guard let product = selectedProduct() else {
            alertMessage = "Selected plan is not available right now."
            return
        }
        do {
            let result = try await purchaseService.purchase(product)
            switch result {
            case .success:
                await SubscriptionManager.shared.refreshEntitlements()
                entitlementStore.isPro = SubscriptionManager.shared.isPro
                if !SubscriptionManager.shared.isPro {
                    alertMessage = "Purchase completed. Please use Restore Purchases if Pro is not unlocked."
                }
            case .cancelled:
                alertMessage = "Purchase cancelled."
            case .pending:
                alertMessage = "Purchase pending."
            case .failed(let message):
                alertMessage = message
            }
        } catch {
            alertMessage = "Purchase failed."
        }
    }

    @MainActor
    func restorePurchases() async {
        do {
            try await purchaseService.restorePurchases()
            await SubscriptionManager.shared.refreshEntitlements()
            entitlementStore.isPro = SubscriptionManager.shared.isPro
            if SubscriptionManager.shared.isPro {
                alertMessage = "Purchases restored."
            } else {
                alertMessage = "No active Pro purchase found to restore."
            }
        } catch {
            alertMessage = "Unable to restore purchases."
        }
    }
}
