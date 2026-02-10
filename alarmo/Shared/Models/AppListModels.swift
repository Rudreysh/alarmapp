import Foundation
import SwiftData

#if canImport(FamilyControls)
import FamilyControls
#endif

enum AppListType: String, Codable, CaseIterable {
    case block
    case allow

    var title: String {
        switch self {
        case .block: return "Block List"
        case .allow: return "Allow List"
        }
    }
}

@Model
final class AppList: Identifiable {
    var id: UUID
    var typeRaw: String
    var name: String
    var selectionData: Data
    var mockAppIDsData: Data?
    var mockCategoryIDsData: Data?
    var adultBlockingEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: AppListType,
        name: String,
        selectionData: Data = Data(),
        mockAppIDsData: Data? = nil,
        mockCategoryIDsData: Data? = nil,
        adultBlockingEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.name = name
        self.selectionData = selectionData
        self.mockAppIDsData = mockAppIDsData
        self.mockCategoryIDsData = mockCategoryIDsData
        self.adultBlockingEnabled = adultBlockingEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: AppListType {
        get { AppListType(rawValue: typeRaw) ?? .block }
        set { typeRaw = newValue.rawValue }
    }

    func touch() {
        updatedAt = Date()
    }
}

extension AppList {
    var mockAppIDs: [String] {
        get {
            guard let data = mockAppIDsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            mockAppIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            touch()
        }
    }

    var mockCategoryIDs: [String] {
        get {
            guard let data = mockCategoryIDsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            mockCategoryIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            touch()
        }
    }
}

#if canImport(FamilyControls)
extension AppList {
    var selection: FamilyActivitySelection {
        get {
            (try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)) ?? FamilyActivitySelection()
        }
        set {
            selectionData = (try? JSONEncoder().encode(newValue)) ?? Data()
            touch()
        }
    }

    var selectedApplicationsCount: Int {
        selection.applicationTokens.count
    }

    var selectedCategoriesCount: Int {
        selection.categoryTokens.count
    }
}
#endif

@MainActor
enum AppListMigrationCoordinator {
    static func migrateLegacySelectionIfNeeded(context: ModelContext, settings: SettingsStore) {
        guard UserDefaults.standard.bool(forKey: "appList.legacySelectionMigrated") == false else { return }

        let descriptor = FetchDescriptor<AppList>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty, !settings.blockedAppsSelectionData.isEmpty {
            let legacy = AppList(type: .block, name: "Block List", selectionData: settings.blockedAppsSelectionData)
            context.insert(legacy)
            settings.selectedBlockListId = legacy.id.uuidString
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: "appList.legacySelectionMigrated")
    }
}
