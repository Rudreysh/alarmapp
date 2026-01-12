import Foundation

enum PaywallPlan: String, CaseIterable, Equatable {
    case yearly
    case monthly
    case lifetime
}

struct PaywallProduct: Identifiable, Equatable {
    let id: String
    let plan: PaywallPlan
    let displayName: String
    let priceString: String
    let billingPeriodString: String
    let trialText: String?
    let discountBadgeText: String?
    let oldPriceString: String?
    let isTrialAvailable: Bool
}

enum PurchaseResult: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

protocol PurchaseService {
    func loadProducts() async throws -> [PaywallProduct]
    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult
    func restorePurchases() async throws
}

struct MockPurchaseService: PurchaseService {
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
        return .success
    }

    func restorePurchases() async throws { }
}

struct StoreKitPurchaseService: PurchaseService {
    func loadProducts() async throws -> [PaywallProduct] {
        return []
    }

    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        return .failed("StoreKit not wired")
    }

    func restorePurchases() async throws { }
}
