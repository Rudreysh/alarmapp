import Foundation
import Combine

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

@MainActor
final class BlockingManager: ObservableObject {
    static let shared = BlockingManager()

    private let authorizationManager = ScreenTimeAuthorizationManager.shared

    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore()
    #endif

    private init() {}

    func requestAuthorizationIfNeeded() async {
        authorizationManager.refreshStatus()
        guard !authorizationManager.isAuthorized else { return }
        await authorizationManager.requestAuthorization()
    }

    func applyBlocking(blockList: AppList, allowList: AppList? = nil) {
        guard authorizationManager.isAuthorized else { return }

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let blockSelection = blockList.selection
        var effectiveApps = blockSelection.applicationTokens

        if let allowList {
            let allowSelection = allowList.selection
            effectiveApps.subtract(allowSelection.applicationTokens)
        }

        if effectiveApps.isEmpty && blockSelection.categoryTokens.isEmpty {
            clearBlocking()
            return
        }

        store.shield.applications = effectiveApps.isEmpty ? nil : effectiveApps
        store.shield.applicationCategories = blockSelection.categoryTokens.isEmpty ? nil : .specific(blockSelection.categoryTokens)
        #else
        _ = blockList
        _ = allowList
        #endif
    }

    func clearBlocking() {
        #if canImport(ManagedSettings)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        #endif
    }
}
