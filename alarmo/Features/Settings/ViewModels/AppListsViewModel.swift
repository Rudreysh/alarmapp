import Foundation
import SwiftData
import Combine

@MainActor
final class AppListsViewModel: ObservableObject {
    @Published var isEditingSelection = false
    @Published var selectedListID: UUID?
    @Published var showProPaywall = false

    private static let blockListNamePresets = [
        "Focus Fortress",
        "Zen Vault",
        "No-Distract Mode",
        "Deep Work Dome",
        "Signal Cutoff",
        "Locked In",
        "Clarity Guard",
        "Monk Mode",
        "Zero Noise",
        "Attention Shield"
    ]
    private static let lastBlockListPresetKey = "appLists.lastBlockListPreset"

    private let settings = SettingsStore.shared
    private let entitlementStore: EntitlementStoreProtocol

    init(entitlementStore: EntitlementStoreProtocol = EntitlementStore()) {
        self.entitlementStore = entitlementStore
        if let id = UUID(uuidString: settings.selectedBlockListId) {
            self.selectedListID = id
        }
    }

    var isPro: Bool {
        entitlementStore.isPro
    }

    func toggleEditMode() {
        isEditingSelection.toggle()
    }

    @discardableResult
    func createList(type: AppListType, context: ModelContext) -> AppList? {
        let nextName: String
        switch type {
        case .block:
            nextName = nextBlockListName(context: context)
        case .allow:
            let count = listCount(of: .allow, context: context)
            nextName = count == 0 ? "Allow List" : "Allow List \(count + 1)"
        }

        let list = AppList(type: type, name: nextName)
        context.insert(list)

        if type == .block {
            setSelectedList(list, context: context)
        }

        try? context.save()
        return list
    }

    func setSelectedList(_ list: AppList, context: ModelContext) {
        selectedListID = list.id
        settings.selectedBlockListId = list.id.uuidString
        if list.type == .block {
            settings.blockedAppsSelectionData = list.selectionData
            settings.blockedMockApps = list.mockAppIDs
            settings.blockedMockCategories = list.mockCategoryIDs
            settings.blockedAdultContentEnabled = list.adultBlockingEnabled
        }
        try? context.save()
    }

    func deleteList(_ list: AppList, context: ModelContext) {
        let deletingSelected = selectedListID == list.id || settings.selectedBlockListId == list.id.uuidString
        context.delete(list)
        try? context.save()

        if deletingSelected {
            selectedListID = nil
            settings.selectedBlockListId = ""
            settings.blockedAppsSelectionData = Data()
            settings.blockedMockApps = []
            settings.blockedMockCategories = []
            settings.blockedAdultContentEnabled = false
        }
    }

    private func listCount(of type: AppListType, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<AppList>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.type == type }.count
    }

    private func nextBlockListName(context: ModelContext) -> String {
        let lastPreset = UserDefaults.standard.string(forKey: Self.lastBlockListPresetKey)
        let candidates = Self.blockListNamePresets.filter { $0 != lastPreset }
        let preset = (candidates.isEmpty ? Self.blockListNamePresets : candidates).randomElement() ?? "Focus Fortress"
        UserDefaults.standard.set(preset, forKey: Self.lastBlockListPresetKey)
        return makeNameUnique(preset, context: context)
    }

    private func makeNameUnique(_ baseName: String, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<AppList>()
        let existingNames = Set(((try? context.fetch(descriptor)) ?? []).map { $0.name.lowercased() })

        guard !existingNames.contains(baseName.lowercased()) else {
            var suffix = 2
            while existingNames.contains("\(baseName) \(suffix)".lowercased()) {
                suffix += 1
            }
            return "\(baseName) \(suffix)"
        }

        return baseName
    }
}
