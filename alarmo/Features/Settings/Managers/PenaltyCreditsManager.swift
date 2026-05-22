import Foundation
import Combine
import StoreKit

@MainActor
final class PenaltyCreditsManager: ObservableObject {
    static let shared = PenaltyCreditsManager()
    
    struct ChargeResult {
        let success: Bool
        let transactionReference: String?
        let failureReason: String?
    }

    struct CreditPack: Identifiable {
        let creditsEuro: Int
        let displayName: String
        let candidateProductIDs: [String]

        var id: Int { creditsEuro }
    }

    private let store = SettingsStore.shared
    private(set) var packs: [CreditPack] = [
        CreditPack(
            creditsEuro: 10,
            displayName: "€10 Credit Pack",
            candidateProductIDs: [
                "alarmo.credits.10",
                "ht.alarmo.credits.10"
            ]
        ),
        CreditPack(
            creditsEuro: 20,
            displayName: "€20 Credit Pack",
            candidateProductIDs: [
                "alarmo.credits.20",
                "ht.alarmo.credits.20"
            ]
        ),
        CreditPack(
            creditsEuro: 50,
            displayName: "€50 Credit Pack",
            candidateProductIDs: [
                "alarmo.credits.50",
                "ht.alarmo.credits.50"
            ]
        )
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var productsByPackCredits: [Int: Product] = [:]
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var isLoadingProducts: Bool = false

    private init() {}

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = Set(packs.flatMap(\.candidateProductIDs))
            let fetched = try await Product.products(for: Array(ids))
                .sorted { $0.price < $1.price }
            products = fetched
            productsByPackCredits = Dictionary(
                uniqueKeysWithValues: fetched.compactMap { product in
                    guard let credits = credits(from: product.id) else { return nil }
                    return (credits, product)
                }
            )
            loadErrorMessage = nil
        } catch {
            print("[PenaltyCreditsManager] Failed loading products: \(error)")
            products = []
            productsByPackCredits = [:]
            loadErrorMessage = error.localizedDescription
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
                    ensurePenaltyFundingMarkedAsConnected()
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
    func purchasePack(creditsEuro: Int) async -> Bool {
        if let product = productsByPackCredits[creditsEuro] {
            return await purchase(product: product)
        }

        // Attempt to load again before failing.
        await loadProducts()
        if let product = productsByPackCredits[creditsEuro] {
            return await purchase(product: product)
        }

        let ids = packs.first(where: { $0.creditsEuro == creditsEuro })?.candidateProductIDs.joined(separator: ", ") ?? "unknown"
        loadErrorMessage = "No App Store product found for \(creditsEuro) credits. Expected one of: \(ids)"
        return false
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
    
    func chargePenalty(
        amountEuro: Int,
        eventType: PenaltyEventType,
        note: String? = nil,
        sourceAlarmId: UUID? = nil,
        sourceFocusTaskId: UUID? = nil
    ) -> ChargeResult {
        if consumeCredits(
            amountEuro: amountEuro,
            eventType: eventType,
            note: note,
            sourceAlarmId: sourceAlarmId,
            sourceFocusTaskId: sourceFocusTaskId
        ) {
            return ChargeResult(
                success: true,
                transactionReference: "credits-\(UUID().uuidString.prefix(8))",
                failureReason: nil
            )
        }

        // Card-on-file fallback (simulated capture in this build).
        if store.hasValidPenaltyPaymentMethod && store.penaltyTermsAccepted {
            let normalized = min(10, max(1, amountEuro))
            store.appendPenaltyAudit(
                AccountabilityAuditEvent(
                    eventType: eventType,
                    amountEuro: normalized,
                    sourceAlarmId: sourceAlarmId,
                    sourceFocusTaskId: sourceFocusTaskId,
                    note: (note ?? "Card charge") + " [CARD_CHARGE_SIMULATED]"
                )
            )
            return ChargeResult(
                success: true,
                transactionReference: "card-\(UUID().uuidString.prefix(8))",
                failureReason: nil
            )
        }

        return ChargeResult(
            success: false,
            transactionReference: nil,
            failureReason: "no_credits_or_card_payment_unavailable"
        )
    }

    func addTestCredits(_ amountEuro: Int = 25) {
        let normalized = max(1, amountEuro)
        store.penaltyCreditsBalance += normalized
        ensurePenaltyFundingMarkedAsConnected()
    }

    @discardableResult
    func syncPurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await loadProducts()
            return true
        } catch {
            print("[PenaltyCreditsManager] Sync failed: \(error)")
            return false
        }
    }

    private func addCredits(from productId: String) {
        if let credits = credits(from: productId) {
            store.penaltyCreditsBalance += credits
        }
    }

    private func credits(from productId: String) -> Int? {
        if productId.hasSuffix(".credits.10") { return 10 }
        if productId.hasSuffix(".credits.20") { return 20 }
        if productId.hasSuffix(".credits.50") { return 50 }
        return nil
    }

    private func ensurePenaltyFundingMarkedAsConnected() {
        // Credits are funded through Apple billing, so mark payment as configured.
        store.isPenaltyPaymentConnected = true
        if store.penaltyPaymentToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.penaltyPaymentToken = "iap_penalty_credits"
        }
        if store.penaltyCardBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.penaltyCardBrand = "Apple"
        }
        if store.penaltyCardLast4.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.penaltyCardLast4 = "IAP"
        }
    }
}
