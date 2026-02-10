import Foundation
import Combine

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

@MainActor
final class AppShieldManager: ObservableObject {
    static let shared = AppShieldManager()
    @Published private(set) var isSimulatorShieldActive = false
    @Published private(set) var simulatorBlockedApps: [String] = []
    @Published private(set) var simulatorBlockedCategories: [String] = []

    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore()
    #endif

    private init() {}

    func applyShield(selectionData: Data) {
        #if targetEnvironment(simulator)
        let settings = SettingsStore.shared
        simulatorBlockedApps = settings.blockedMockApps
        simulatorBlockedCategories = settings.blockedMockCategories
        isSimulatorShieldActive = !simulatorBlockedApps.isEmpty || !simulatorBlockedCategories.isEmpty
        return
        #endif

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard let selection = decodeSelection(from: selectionData) else {
            clearShield()
            return
        }

        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            clearShield()
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomainCategories = nil
        #else
        _ = selectionData
        #endif
    }

    func clearShield() {
        #if targetEnvironment(simulator)
        isSimulatorShieldActive = false
        simulatorBlockedApps = []
        simulatorBlockedCategories = []
        return
        #endif
        #if canImport(ManagedSettings)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        #endif
    }

    func ensureShieldRestoredOnAppLaunch(isEnforcementActive: Bool, selectionData: Data) {
        guard isEnforcementActive else {
            clearShield()
            return
        }
        applyShield(selectionData: selectionData)
    }

    #if canImport(FamilyControls)
    func encodeSelection(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    func decodeSelection(from data: Data) -> FamilyActivitySelection? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func selectedAppCount(from data: Data) -> Int {
        decodeSelection(from: data)?.applicationTokens.count ?? 0
    }
    #else
    func selectedAppCount(from data: Data) -> Int {
        _ = data
        return 0
    }
    #endif
}
