import Foundation
import Combine
import StoreKit

@MainActor
final class PenaltyCreditsManager: ObservableObject {
    static let shared = PenaltyCreditsManager()

    struct CreditProduct: Identifiable {
        let id: String
        let creditsEuro: Int
        let displayName: String
    }

    private let store = SettingsStore.shared
    private(set) var productIDs = [
        "alarmo.credits.10",
        "alarmo.credits.20",
        "alarmo.credits.50"
    ]

    @Published private(set) var products: [Product] = []

    private init() {}

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("[PenaltyCreditsManager] Failed loading products: \(error)")
            products = []
        }
    }

    var balanceEuro: Int {
        store.penaltyCreditsBalance
    }

    @discardableResult
    func purchase(product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    addCredits(from: product.id)
                    return true
                case .unverified:
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[PenaltyCreditsManager] Purchase failed: \(error)")
            return false
        }
    }

    @discardableResult
    func consumeCredits(amountEuro: Int, eventType: PenaltyEventType, note: String? = nil, sourceAlarmId: UUID? = nil, sourceFocusTaskId: UUID? = nil) -> Bool {
        let normalized = min(10, max(1, amountEuro))
        guard store.penaltyCreditsBalance >= normalized else {
#if targetEnvironment(simulator)
            // Simulator fallback for QA/testing without real purchases.
            // This keeps production behavior unchanged on physical devices.
            print("[PenaltyCreditsManager] Simulator fallback: simulating penalty charge \(normalized) for event=\(eventType.rawValue) with zero balance.")
            store.appendPenaltyAudit(
                AccountabilityAuditEvent(
                    eventType: eventType,
                    amountEuro: normalized,
                    sourceAlarmId: sourceAlarmId,
                    sourceFocusTaskId: sourceFocusTaskId,
                    note: (note ?? "Simulator test charge") + " [SIMULATED_NO_CREDITS]"
                )
            )
            return true
#else
            print("[PenaltyCreditsManager] Insufficient credits. Required=\(normalized), Balance=\(store.penaltyCreditsBalance), Event=\(eventType.rawValue)")
            return false
#endif
        }

        store.penaltyCreditsBalance -= normalized
        print("[PenaltyCreditsManager] Consumed \(normalized) credits. New balance=\(store.penaltyCreditsBalance), Event=\(eventType.rawValue)")
        store.appendPenaltyAudit(
            AccountabilityAuditEvent(
                eventType: eventType,
                amountEuro: normalized,
                sourceAlarmId: sourceAlarmId,
                sourceFocusTaskId: sourceFocusTaskId,
                note: note
            )
        )
        return true
    }

    func addTestCredits(_ amountEuro: Int = 25) {
        let normalized = max(1, amountEuro)
        store.penaltyCreditsBalance += normalized
    }

    private func addCredits(from productId: String) {
        switch productId {
        case "alarmo.credits.10":
            store.penaltyCreditsBalance += 10
        case "alarmo.credits.20":
            store.penaltyCreditsBalance += 20
        case "alarmo.credits.50":
            store.penaltyCreditsBalance += 50
        default:
            break
        }
    }
}
