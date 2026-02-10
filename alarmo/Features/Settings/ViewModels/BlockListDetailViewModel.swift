import Foundation
import SwiftData
import Combine

#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class BlockListDetailViewModel: ObservableObject {
    @Published var name: String
    @Published var adultBlockingEnabled: Bool

    #if canImport(FamilyControls)
    @Published var selection: FamilyActivitySelection
    #endif
    @Published var mockSelectedAppIDs: [String]
    @Published var mockSelectedCategoryIDs: [String]

    @Published var showPicker = false
    @Published var showDeleteConfirmation = false

    let listID: UUID

    init(list: AppList) {
        self.listID = list.id
        self.name = list.name
        self.adultBlockingEnabled = list.adultBlockingEnabled
        self.mockSelectedAppIDs = list.mockAppIDs
        self.mockSelectedCategoryIDs = list.mockCategoryIDs
        #if canImport(FamilyControls)
        self.selection = list.selection
        #endif
    }

    var selectedAppsCount: Int {
        #if targetEnvironment(simulator)
        return mockSelectedAppIDs.count
        #elseif canImport(FamilyControls)
        return selection.applicationTokens.count
        #else
        return 0
        #endif
    }

    var selectedCategoriesCount: Int {
        #if targetEnvironment(simulator)
        return mockSelectedCategoryIDs.count
        #elseif canImport(FamilyControls)
        return selection.categoryTokens.count
        #else
        return 0
        #endif
    }

    var selectedAppsSummary: String {
        let count = selectedAppsCount
        return count == 1 ? "1 app" : "\(count) apps"
    }

    func save(to list: AppList, context: ModelContext, appListsViewModel: AppListsViewModel) {
        list.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? list.name : name
        list.adultBlockingEnabled = adultBlockingEnabled
        #if canImport(FamilyControls)
        list.selection = selection
        #endif
        list.mockAppIDs = mockSelectedAppIDs
        list.mockCategoryIDs = mockSelectedCategoryIDs
        list.touch()

        // Keep runtime settings synced with the currently selected block list.
        if appListsViewModel.selectedListID == list.id {
            SettingsStore.shared.blockedAppsSelectionData = list.selectionData
            SettingsStore.shared.blockedMockApps = list.mockAppIDs
            SettingsStore.shared.blockedMockCategories = list.mockCategoryIDs
        }

        try? context.save()
    }

    func delete(list: AppList, context: ModelContext, appListsViewModel: AppListsViewModel) {
        let wasSelected = appListsViewModel.selectedListID == list.id
        context.delete(list)
        try? context.save()

        if wasSelected {
            appListsViewModel.selectedListID = nil
            SettingsStore.shared.selectedBlockListId = ""
            SettingsStore.shared.blockedAppsSelectionData = Data()
            SettingsStore.shared.blockedMockApps = []
            SettingsStore.shared.blockedMockCategories = []
        }
    }
}
