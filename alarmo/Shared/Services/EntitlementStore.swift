import Foundation

protocol EntitlementStoreProtocol {
    var isPro: Bool { get set }
}

final class EntitlementStore: EntitlementStoreProtocol {
    private let defaults: UserDefaults
    private let key = "alarmo.entitlement.pro"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isPro: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
