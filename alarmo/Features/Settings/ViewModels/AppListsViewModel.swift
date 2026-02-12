import Foundation
import SwiftData
import Combine

@MainActor
final class AppListsViewModel: ObservableObject {
    @Published var isEditingSelection = false
    @Published var selectedListID: UUID?
    @Published var showProPaywall = false

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
        if type == .allow && !isPro {
            showProPaywall = true
            return nil
        }

        let nextName: String
        switch type {
        case .block:
            let count = listCount(of: .block, context: context)
            nextName = count == 0 ? "Block List" : "Block List \(count + 1)"
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
        }
        try? context.save()
    }

    func deleteList(_ list: AppList, context: ModelContext) {
        let deletingSelected = selectedListID == list.id
        context.delete(list)
        try? context.save()

        if deletingSelected {
            selectedListID = nil
            settings.selectedBlockListId = ""
            settings.blockedAppsSelectionData = Data()
            settings.blockedMockApps = []
            settings.blockedMockCategories = []
        }
    }

    private func listCount(of type: AppListType, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<AppList>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.type == type }.count
    }
}
