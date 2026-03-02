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

    func requestAuthorizationIfNeeded() async {
        authorizationManager.refreshStatus()
        guard !authorizationManager.isAuthorized else { return }
        await authorizationManager.requestAuthorization()
    }

    func applyBlocking(blockList: AppList, allowList: AppList? = nil) {
        #if !targetEnvironment(simulator)
        guard authorizationManager.isAuthorized else {
            blockingLog.warning("⚠️ [BlockingManager] applyBlocking called but NOT authorized — skipping.")
            return
        }
        #endif

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let blockSelection = blockList.selection
        var effectiveApps = blockSelection.applicationTokens

        if let allowList {
            let allowSelection = allowList.selection
            effectiveApps.subtract(allowSelection.applicationTokens)
        }

        if effectiveApps.isEmpty && blockSelection.categoryTokens.isEmpty {
            blockingLog.info("ℹ️ [BlockingManager] Block list '\(blockList.name)' is empty — clearing shields.")
            clearBlocking()
            return
        }

        store.shield.applications = effectiveApps.isEmpty ? nil : effectiveApps
        store.shield.applicationCategories = blockSelection.categoryTokens.isEmpty ? nil : .specific(blockSelection.categoryTokens)
        blockingLog.info("🔒 [BlockingManager] APPLIED shields — list: '\(blockList.name)', apps: \(effectiveApps.count), categories: \(blockSelection.categoryTokens.count)")
        #else
        // SIMULATOR: log what WOULD happen on a real device
        #if targetEnvironment(simulator)
        let mockApps = blockList.mockAppIDs
        let mockCats = blockList.mockCategoryIDs
        blockingLog.info("🔒 [BlockingManager][SIMULATOR] WOULD shield: list='\(blockList.name)' mockApps=\(mockApps) mockCategories=\(mockCats) — ManagedSettings not available in Simulator.")
        print("🔒 [Blocking][SIMULATED] List: \(blockList.name) | Apps: \(mockApps.joined(separator: ", ")) | Categories: \(mockCats.joined(separator: ", "))")
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
        store.shield.webDomainCategories = nil
        #endif
    }
}

