import Foundation
import Combine
import os.log

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

private let blockingLog = Logger(subsystem: "ht.alarmo", category: "Blocking")

@MainActor
final class BlockingManager: ObservableObject {
    static let shared = BlockingManager()

    private let authorizationManager = ScreenTimeAuthorizationManager.shared

    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore()
    #endif

    private init() {}

    func applyBlocking(
        selectionData: Data,
        mockAppIDs: [String],
        mockCategoryIDs: [String],
        adultBlockingEnabled: Bool,
        label: String = "Stored Block List"
    ) {
        #if !targetEnvironment(simulator)
        if !authorizationManager.isAuthorized {
            authorizationManager.refreshStatus()
        }
        guard authorizationManager.isAuthorized else {
            blockingLog.warning("⚠️ [BlockingManager] applyBlocking(snapshot:) called but NOT authorized — skipping.")
            return
        }
        #endif

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = (try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)) ?? FamilyActivitySelection()
        let hasSelectionTargets = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
        if !hasSelectionTargets && !adultBlockingEnabled {
            blockingLog.info("ℹ️ [BlockingManager] Snapshot '\(label)' has no targets — clearing shields.")
            clearBlocking()
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.webContent.blockedByFilter = adultBlockingEnabled ? .auto() : nil

        blockingLog.info(
            "🔒 [BlockingManager] APPLIED snapshot shields — label: '\(label)', apps: \(selection.applicationTokens.count), categories: \(selection.categoryTokens.count), domains: \(selection.webDomainTokens.count), adultFilter: \(adultBlockingEnabled)"
        )
        #else
        #if targetEnvironment(simulator)
        simulatorBlockedApps = mockAppIDs
        simulatorBlockedCategories = mockCategoryIDs
        isSimulatorShieldActive = !simulatorBlockedApps.isEmpty || !simulatorBlockedCategories.isEmpty || adultBlockingEnabled
        blockingLog.info("🔒 [BlockingManager][SIMULATOR] APPLIED snapshot shields — label='\(label)' apps=\(simulatorBlockedApps.count) categories=\(simulatorBlockedCategories.count) adult=\(adultBlockingEnabled)")
        #endif
        _ = selectionData
        _ = mockAppIDs
        _ = mockCategoryIDs
        _ = adultBlockingEnabled
        _ = label
        #endif
    }

    func requestAuthorizationIfNeeded() async {
        authorizationManager.refreshStatus()
        guard !authorizationManager.isAuthorized else { return }
        await authorizationManager.requestAuthorization()
    }

    func applyBlocking(blockList: AppList, allowList: AppList? = nil) {
        #if !targetEnvironment(simulator)
        if !authorizationManager.isAuthorized {
            authorizationManager.refreshStatus()
        }
        guard authorizationManager.isAuthorized else {
            blockingLog.warning("⚠️ [BlockingManager] applyBlocking called but NOT authorized — skipping.")
            return
        }
        #endif

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let blockSelection = blockList.selection
        var effectiveApps = blockSelection.applicationTokens
        var effectiveWebDomains = blockSelection.webDomainTokens

        if let allowList {
            let allowSelection = allowList.selection
            effectiveApps.subtract(allowSelection.applicationTokens)
            effectiveWebDomains.subtract(allowSelection.webDomainTokens)
        }

        let hasSelectionTargets = !effectiveApps.isEmpty || !blockSelection.categoryTokens.isEmpty || !effectiveWebDomains.isEmpty
        if !hasSelectionTargets && !blockList.adultBlockingEnabled {
            blockingLog.info("ℹ️ [BlockingManager] Block list '\(blockList.name)' is empty — clearing shields.")
            clearBlocking()
            return
        }

        store.shield.applications = effectiveApps.isEmpty ? nil : effectiveApps
        store.shield.applicationCategories = blockSelection.categoryTokens.isEmpty ? nil : .specific(blockSelection.categoryTokens)
        store.shield.webDomains = effectiveWebDomains.isEmpty ? nil : effectiveWebDomains
        store.shield.webDomainCategories = blockSelection.categoryTokens.isEmpty ? nil : .specific(blockSelection.categoryTokens)
        store.webContent.blockedByFilter = blockList.adultBlockingEnabled ? .auto() : nil

        blockingLog.info(
            "🔒 [BlockingManager] APPLIED shields — list: '\(blockList.name)', apps: \(effectiveApps.count), categories: \(blockSelection.categoryTokens.count), domains: \(effectiveWebDomains.count), adultFilter: \(blockList.adultBlockingEnabled)"
        )
        #else
        // SIMULATOR: log what WOULD happen on a real device
        #if targetEnvironment(simulator)
        let mockApps = blockList.mockAppIDs
        let mockCats = blockList.mockCategoryIDs
        blockingLog.info("🔒 [BlockingManager][SIMULATOR] WOULD shield: list='\(blockList.name)' mockApps=\(mockApps) mockCategories=\(mockCats) adultFilter=\(blockList.adultBlockingEnabled) — ManagedSettings not available in Simulator.")
        print("🔒 [Blocking][SIMULATED] List: \(blockList.name) | Apps: \(mockApps.joined(separator: ", ")) | Categories: \(mockCats.joined(separator: ", ")) | Adult: \(blockList.adultBlockingEnabled)")
        #endif
        _ = blockList
        _ = allowList
        #endif
    }

    func clearBlocking() {
        blockingLog.info("🔓 [BlockingManager] Clearing all shields.")
        print("🔓 [Blocking] clearBlocking() called — shields removed.")
        #if canImport(ManagedSettings)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        store.webContent.blockedByFilter = nil
        #endif
    }
}
