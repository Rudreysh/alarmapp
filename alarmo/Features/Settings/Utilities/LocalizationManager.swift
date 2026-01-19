import Foundation
import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    private let store = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var currentLocale: Locale {
        if store.selectedLanguage == "system" {
            return .current
        }
        return Locale(identifier: store.selectedLanguage)
    }
}

// Extension to help with localizing strings based on the selected language
extension String {
    func localized() -> String {
        let store = SettingsStore.shared
        if store.selectedLanguage == "system" {
            return NSLocalizedString(self, comment: "")
        }
        
        guard let path = Bundle.main.path(forResource: store.selectedLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
}
