import Foundation
import Combine

final class PaywallViewModel: ObservableObject {
    @Published private(set) var products: [PaywallProduct] = []
    @Published var selectedPlan: PaywallPlan = .yearly
    @Published var alertMessage: String?

    private let purchaseService: PurchaseService
    private var entitlementStore: EntitlementStoreProtocol

    init(purchaseService: PurchaseService = MockPurchaseService(),
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
        guard let product = selectedProduct() else { return }
        do {
            let result = try await purchaseService.purchase(product)
            switch result {
            case .success:
                entitlementStore.isPro = true
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
}
