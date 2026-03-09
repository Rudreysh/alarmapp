import SwiftUI

struct SystemConfigurationView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var downloadsSize: Int64 = 0
    @State private var showClearConfirm = false
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            VStack(spacing: 24) {
                SettingsCard {
                    SettingsNavigationRow(
                        title: "App Language",
                        trailingText: currentLanguageName,
                        isLast: true,
                        destination: AppLanguageView()
                    )
                }
                
                SettingsCard {
                    SettingsCardToggleRow(
                        title: "Battery saving mode",
                        subtitle: "No sound in silent mode, ringtone set to default",
                        isOn: $store.batterySavingMode,
                        isLast: false
                    )
                    
                    SettingsNavigationRow(
                        title: "Permissions",
                        isLast: false,
                        destination: PermissionsView()
                    )
                    
                    SettingsActionRow(
                        title: "Clear Downloaded Assets",
                        subtitle: downloadsSize > 0 ? "Frees up \(AssetManager.shared.formatBytes(downloadsSize))" : "No downloads to clear",
                        trailingText: nil,
                        isLast: true
                    ) {
                        if downloadsSize > 0 {
                            showClearConfirm = true
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("System configuration")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadsSize = AssetManager.shared.getDownloadsSize()
        }
        .alert("Clear Downloads?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                AssetManager.shared.clearAllDownloads()
                downloadsSize = AssetManager.shared.getDownloadsSize()
            }
        } message: {
            Text("This will free up \(AssetManager.shared.formatBytes(downloadsSize)) of space. You will need internet to download these assets again when playing them.")
        }
    }
    
    private var currentLanguageName: String {
        if store.selectedLanguage == "system" {
            return "Follow system..."
        }
        return AppLanguageView.languages.first(where: { $0.id == store.selectedLanguage })?.displayName ?? store.selectedLanguage
    }
}

struct AppLanguageView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    static let languages: [LanguageOption] = [
        LanguageOption(id: "system", name: "Follow system setting", displayName: "Follow system setting"),
        LanguageOption(id: "ar", name: "Arabic", displayName: "العربية (Arabic)"),
        LanguageOption(id: "ar_EG", name: "Arabic (Egypt)", displayName: "مصري (Arabic(Egypt))"),
        LanguageOption(id: "ar_MA", name: "Arabic (Morocco)", displayName: "الدارجة (Arabic(Morocco))"),
        LanguageOption(id: "zh_Hant", name: "Chinese Traditional", displayName: "繁体中文 (Chinese Traditional)"),
        LanguageOption(id: "zh_Hans", name: "Chinese Simplified", displayName: "简体中文 (Chinese Simplified)"),
        LanguageOption(id: "hr", name: "Croatian", displayName: "Hrvatski (Croatian)"),
        LanguageOption(id: "cs", name: "Czech", displayName: "Čeština / Český Jazyk (Czech)"),
        LanguageOption(id: "da", name: "Danish", displayName: "Dansk (Danish)"),
        LanguageOption(id: "nl", name: "Dutch", displayName: "Nederlands (Dutch)"),
        LanguageOption(id: "en", name: "English", displayName: "English (English)"),
        LanguageOption(id: "fil", name: "Filipino", displayName: "Filipino (Filipino)"),
        LanguageOption(id: "fi", name: "Finnish", displayName: "Suomi (Finnish)"),
        LanguageOption(id: "fr", name: "French", displayName: "Français (French)"),
        LanguageOption(id: "de", name: "German", displayName: "Deutsch (German)"),
        LanguageOption(id: "el", name: "Greek", displayName: "Ελληνικά (Greek)"),
        LanguageOption(id: "he", name: "Hebrew", displayName: "עברית (Hebrew)"),
        LanguageOption(id: "hi", name: "Hindi", displayName: "हिन्दी (Hindi)"),
        LanguageOption(id: "hu", name: "Hungarian", displayName: "Magyar (Hungarian)"),
        LanguageOption(id: "id", name: "Indonesian", displayName: "Indonesia (Indonesian)"),
        LanguageOption(id: "it", name: "Italian", displayName: "Italiano (Italian)"),
        LanguageOption(id: "ja", name: "Japanese", displayName: "日本語 (Japanese)"),
        LanguageOption(id: "ko", name: "Korean", displayName: "한국어 (Korean)"),
        LanguageOption(id: "no", name: "Norwegian", displayName: "Norsk bokmål (Norwegian)"),
        LanguageOption(id: "fa", name: "Persian", displayName: "فارسی (Persian)"),
        LanguageOption(id: "pl", name: "Polish", displayName: "Polski (Polish)"),
        LanguageOption(id: "pt", name: "Portuguese", displayName: "Português (Portuguese)"),
        LanguageOption(id: "ro", name: "Romanian", displayName: "Română (Romanian)"),
        LanguageOption(id: "ru", name: "Russian", displayName: "Русский (Russian)")
    ]
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Self.languages) { lang in
                        SettingsRadioRow(
                            title: lang.displayName,
                            isSelected: store.selectedLanguage == lang.id,
                            isLast: lang.id == Self.languages.last?.id
                        ) {
                            store.selectedLanguage = lang.id
                            dismiss()
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("App Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}
