import XCTest
@testable import alarmo

final class PaywallViewModelTests: XCTestCase {
    func test_loadProducts_returnsThree() async {
        let viewModel = PaywallViewModel(purchaseService: MockPurchaseService(), entitlementStore: InMemoryEntitlementStore())
        await viewModel.load()
        XCTAssertEqual(viewModel.products.count, 3)
        XCTAssertEqual(viewModel.selectedPlan, .yearly)
    }

    func test_selectMonthly_changesSelection() {
        let viewModel = PaywallViewModel(purchaseService: MockPurchaseService(), entitlementStore: InMemoryEntitlementStore())
        viewModel.selectPlan(.monthly)
        XCTAssertEqual(viewModel.selectedPlan, .monthly)
    }

    func test_purchaseSuccess_setsEntitlement() async {
        let store = InMemoryEntitlementStore()
        let viewModel = PaywallViewModel(purchaseService: MockPurchaseService(), entitlementStore: store)
        await viewModel.load()
        await viewModel.purchaseSelected()
        XCTAssertTrue(store.isPro)
    }

    func test_purchaseCancelled_doesNotSetEntitlement() async {
        let store = InMemoryEntitlementStore()
        let viewModel = PaywallViewModel(purchaseService: MockPurchaseService(result: .cancelled), entitlementStore: store)
        await viewModel.load()
        await viewModel.purchaseSelected()
        XCTAssertFalse(store.isPro)
    }
}

private final class InMemoryEntitlementStore: EntitlementStoreProtocol {
    var isPro: Bool = false
}

private struct MockPurchaseService: PurchaseService {
    let result: PurchaseResult

    init(result: PurchaseResult = .success) {
        self.result = result
    }

    func loadProducts() async throws -> [PaywallProduct] {
        return [
            PaywallProduct(
                id: "yearly",
                plan: .yearly,
                displayName: "Yearly",
                priceString: "₹ 39.08 /month",
                billingPeriodString: "₹ 469.00 /year",
                trialText: "7-day free trial",
                discountBadgeText: "43% OFF",
                oldPriceString: "₹ 828.00",
                isTrialAvailable: true
            ),
            PaywallProduct(
                id: "monthly",
                plan: .monthly,
                displayName: "Monthly",
                priceString: "₹ 69.00 /month",
                billingPeriodString: "₹ 828.00 /year",
                trialText: "No free trial included",
                discountBadgeText: nil,
                oldPriceString: nil,
                isTrialAvailable: false
            ),
            PaywallProduct(
                id: "lifetime",
                plan: .lifetime,
                displayName: "Lifetime",
                priceString: "₹ 1,129.00",
                billingPeriodString: "",
                trialText: "Pay once, use forever",
                discountBadgeText: nil,
                oldPriceString: nil,
                isTrialAvailable: false
            )
        ]
    }

    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        return result
    }

    func restorePurchases() async throws { }
}
