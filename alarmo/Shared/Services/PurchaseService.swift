import Foundation
import StoreKit

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

struct ProProductDefinition {
    let id: String
    let plan: PaywallPlan
    let displayName: String
    let defaultPriceString: String
    let defaultBillingString: String
    let defaultTrialText: String?
    let discountBadgeText: String?
    let oldPriceString: String?
    let isTrialAvailable: Bool
}

enum ProProductCatalog {
    static let products: [ProProductDefinition] = [
        ProProductDefinition(
            id: "alarmo.pro.yearly",
            plan: .yearly,
            displayName: "Yearly",
            defaultPriceString: "$24.99 /year",
            defaultBillingString: "Billed yearly",
            defaultTrialText: "7-day free trial",
            discountBadgeText: "Best Value",
            oldPriceString: "$49.99 /year",
            isTrialAvailable: true
        ),
        ProProductDefinition(
            id: "alarmo.pro.monthly",
            plan: .monthly,
            displayName: "Monthly",
            defaultPriceString: "$4.99 /month",
            defaultBillingString: "Billed monthly",
            defaultTrialText: "7-day free trial",
            discountBadgeText: nil,
            oldPriceString: nil,
            isTrialAvailable: true
        ),
        ProProductDefinition(
            id: "alarmo.pro.lifetime",
            plan: .lifetime,
            displayName: "Lifetime",
            defaultPriceString: "$79.99",
            defaultBillingString: "One-time purchase",
            defaultTrialText: nil,
            discountBadgeText: nil,
            oldPriceString: nil,
            isTrialAvailable: false
        )
    ]

    static var allProductIDs: [String] {
        products.map(\.id)
    }

    static func definition(for id: String) -> ProProductDefinition? {
        products.first { $0.id == id }
    }

    static func definition(for plan: PaywallPlan) -> ProProductDefinition? {
        products.first { $0.plan == plan }
    }

    static func fallbackProducts() -> [PaywallProduct] {
        products
            .sorted { $0.plan.sortIndex < $1.plan.sortIndex }
            .map { definition in
                PaywallProduct(
                    id: definition.id,
                    plan: definition.plan,
                    displayName: definition.displayName,
                    priceString: definition.defaultPriceString,
                    billingPeriodString: definition.defaultBillingString,
                    trialText: definition.defaultTrialText,
                    discountBadgeText: definition.discountBadgeText,
                    oldPriceString: definition.oldPriceString,
                    isTrialAvailable: definition.isTrialAvailable
                )
            }
    }
}

struct MockPurchaseService: PurchaseService {
    func loadProducts() async throws -> [PaywallProduct] {
        ProProductCatalog.fallbackProducts()
    }

    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        return .success
    }

    func restorePurchases() async throws { }
}

final class StoreKitPurchaseService: PurchaseService {
    private var productsByID: [String: Product] = [:]

    func loadProducts() async throws -> [PaywallProduct] {
        let ids = ProProductCatalog.allProductIDs
        print("[StoreKit] Requesting \(ids.count) product(s): \(ids)")

        let storeProducts = try await Product.products(for: ids)

        if storeProducts.isEmpty {
            print("""
[StoreKit] ⚠️ Product.products() returned 0 results.
           Root cause — one of the following must be fixed:
           A) App Store Connect: products '\(ids.joined(separator: ", "))' have NOT been
              created for the app with bundle ID 'ht.alarmo'. Create them at
              appstoreconnect.apple.com then test with a Sandbox Apple ID.
           B) Local testing: the 'alarmo' scheme does NOT have StoreKit Configuration
              set to Storekit.storekit, OR the app was launched by tapping the
              icon instead of pressing ▶ Run in Xcode.
           Falling back to hardcoded display prices — purchase will not work until
           one of the above is resolved.
""")
        } else {
            print("[StoreKit] ✅ Loaded \(storeProducts.count) product(s) from StoreKit:")
            storeProducts.forEach { p in
                print("[StoreKit]   • \(p.id) | \(p.displayName) | \(p.displayPrice)")
            }
        }

        productsByID = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })

        let mapped = storeProducts.compactMap { product -> PaywallProduct? in
            guard let definition = ProProductCatalog.definition(for: product.id) else { return nil }
            return PaywallProduct(
                id: product.id,
                plan: definition.plan,
                displayName: definition.displayName,
                priceString: localizedPriceLine(for: product, plan: definition.plan),
                billingPeriodString: billingLine(for: product, plan: definition.plan),
                trialText: trialLine(for: product, fallback: definition.defaultTrialText),
                discountBadgeText: definition.discountBadgeText,
                oldPriceString: definition.oldPriceString,
                isTrialAvailable: product.subscription?.introductoryOffer?.paymentMode == .freeTrial || definition.isTrialAvailable
            )
        }
        .sorted { $0.plan.sortIndex < $1.plan.sortIndex }

        if mapped.isEmpty {
            return ProProductCatalog.fallbackProducts()
        }
        return mapped
    }

    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        print("[StoreKit] Attempting to purchase product: \(product.id)")
        let storeProduct = try await productForPurchase(id: product.id)
        
        // NOTE: bypass is Simulator-only. On a physical device the real StoreKit sheet must appear.
        #if targetEnvironment(simulator)
        if storeProduct == nil {
            print("[StoreKit] ⚠️ (Simulator) Product \(product.id) not in local StoreKit config — bypassing for UI testing.")
            try? await Task.sleep(nanoseconds: 500_000_000)
            return .success
        }
        #endif

        guard let storeProduct else {
            print("[StoreKit] ❌ Product '\(product.id)' not found — see diagnostic output above.")
            return .failed("Unable to load this plan from the App Store. Please check your internet connection and try again.")
        }

        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed("Purchase could not be verified.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    private func productForPurchase(id: String) async throws -> Product? {
        if let cached = productsByID[id] { return cached }

        print("[StoreKit] Fresh fetch for product id: '\(id)'")
        let results = try await Product.products(for: [id])
        print("[StoreKit] Product.products returned \(results.count) result(s) for '\(id)'")

        if results.isEmpty {
            print("""
[StoreKit] ⚠️  Product '\(id)' was NOT returned by StoreKit.
           This means ONE of the following is true:
           1. You are running the app by TAPPING its icon — local StoreKit config is
              only injected when you launch via Xcode's ▶ Run button.
           2. The 'alarmo' scheme does not have Storekit.storekit set as its
              StoreKit Configuration (Product → Scheme → Edit Scheme → Run → Options).
           3. The product has NOT been created in App Store Connect Sandbox yet.
           Fix for device testing: quit Xcode, reopen, select the 'alarmo' scheme,
           and press ▶ Run (do not tap the app icon on the home screen).
""")
        } else {
            let p = results[0]
            print("[StoreKit] ✅ Found: \(p.displayName) | \(p.displayPrice) | id=\(p.id)")
        }

        let fetched = results.first
        if let fetched { productsByID[id] = fetched }
        return fetched
    }

    private func localizedPriceLine(for product: Product, plan: PaywallPlan) -> String {
        switch plan {
        case .monthly:
            return "\(product.displayPrice) /month"
        case .yearly:
            return "\(product.displayPrice) /year"
        case .lifetime:
            return product.displayPrice
        }
    }

    private func billingLine(for product: Product, plan: PaywallPlan) -> String {
        switch plan {
        case .lifetime:
            return ""
        case .monthly, .yearly:
            if let period = product.subscription?.subscriptionPeriod {
                return "Renews every \(period.localizedText)"
            }
            return ""
        }
    }

    private func trialLine(for product: Product, fallback: String?) -> String? {
        if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "\(offer.period.localizedText) free trial"
        }
        return fallback
    }
}

private extension Product.SubscriptionPeriod {
    var localizedText: String {
        let unitText: String
        switch unit {
        case .day: unitText = value == 1 ? "day" : "days"
        case .week: unitText = value == 1 ? "week" : "weeks"
        case .month: unitText = value == 1 ? "month" : "months"
        case .year: unitText = value == 1 ? "year" : "years"
        @unknown default: unitText = "period"
        }
        return "\(value) \(unitText)"
    }
}

private extension PaywallPlan {
    var sortIndex: Int {
        switch self {
        case .yearly: return 0
        case .monthly: return 1
        case .lifetime: return 2
        }
    }
}
