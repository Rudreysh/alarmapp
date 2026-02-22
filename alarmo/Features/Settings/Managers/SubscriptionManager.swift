import Foundation
import StoreKit
import Combine

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false // Default to false to show Free Plan Banner
    @Published var renewalDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @Published var planName: String = "Yearly plan"
    
    let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    
    private var updates: Task<Void, Never>? = nil

    private init() {
        updates = observeTransactionUpdates()
        Task {
            await refreshEntitlements()
        }
    }
    
    deinit {
        updates?.cancel()
    }

    func refreshEntitlements() async {
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await _ in Transaction.updates {
                await self.refreshEntitlements()
            }
        }
    }
}
