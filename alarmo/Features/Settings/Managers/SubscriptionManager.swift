import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false // Default to false to show Free Plan Banner
    @Published var renewalDate: Date = Date()
    @Published var planName: String = "Free plan"
    
    let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    
    private var entitlementStore: EntitlementStoreProtocol
    private var updates: Task<Void, Never>? = nil

    private init(entitlementStore: EntitlementStoreProtocol? = nil) {
        self.entitlementStore = entitlementStore ?? EntitlementStore()
        updates = observeTransactionUpdates()
        Task {
            await refreshEntitlements()
        }
    }
    
    deinit {
        updates?.cancel()
    }

    func refreshEntitlements() async {
        var proFound = false
        var detectedPlan: PaywallPlan?
        var detectedRenewalDate: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let definition = ProProductCatalog.definition(for: transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            proFound = true
            if definition.plan == .lifetime {
                detectedPlan = .lifetime
                detectedRenewalDate = Date.distantFuture
                break
            }

            if detectedPlan != .yearly || definition.plan == .yearly {
                detectedPlan = definition.plan
            }
            if let expirationDate = transaction.expirationDate {
                if let current = detectedRenewalDate {
                    if expirationDate > current {
                        detectedRenewalDate = expirationDate
                    }
                } else {
                    detectedRenewalDate = expirationDate
                }
            }
        }

        isPro = proFound
        entitlementStore.isPro = proFound

        if proFound, let detectedPlan {
            switch detectedPlan {
            case .yearly:
                planName = "Yearly Plan"
            case .monthly:
                planName = "Monthly Plan"
            case .lifetime:
                planName = "Lifetime Plan"
            }
            renewalDate = detectedRenewalDate ?? Date()
        } else {
            planName = "Free plan"
            renewalDate = Date()
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }
}
