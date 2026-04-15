import SwiftUI

struct MockActivityPickerSheet: View {
    struct MockCategory: Identifiable, Hashable {
        let id: String
        let title: String
        let emoji: String
    }

    struct MockApp: Identifiable, Hashable {
        let id: String
        let name: String
        let categoryID: String
        let emoji: String
    }

    static let categories: [MockCategory] = [
        .init(id: "all", title: "All Apps & Categories", emoji: "📱"),
        .init(id: "social", title: "Social", emoji: "💬"),
        .init(id: "games", title: "Games", emoji: "🎮"),
        .init(id: "entertainment", title: "Entertainment", emoji: "🍿"),
        .init(id: "creativity", title: "Creativity", emoji: "🎨"),
        .init(id: "productivity", title: "Productivity", emoji: "📈"),
        .init(id: "education", title: "Education", emoji: "📚"),
        .init(id: "information", title: "Information & Reading", emoji: "📰"),
        .init(id: "business", title: "Business", emoji: "💼"),
        .init(id: "shopping", title: "Shopping", emoji: "🛍️"),
        .init(id: "finance", title: "Finance", emoji: "💳"),
        .init(id: "travel", title: "Travel", emoji: "✈️"),
        .init(id: "food", title: "Food & Delivery", emoji: "🍔"),
        .init(id: "music", title: "Music", emoji: "🎵"),
        .init(id: "utilities", title: "Utilities", emoji: "🛠️"),
        .init(id: "health", title: "Health & Fitness", emoji: "❤️")
    ]

    static let apps: [MockApp] = [
        .init(id: "com.apple.mobilesafari", name: "Safari", categoryID: "utilities", emoji: "🧭"),
        .init(id: "com.apple.MobileSMS", name: "Messages", categoryID: "social", emoji: "💬"),
        .init(id: "com.apple.MobileMail", name: "Mail", categoryID: "productivity", emoji: "✉️"),
        .init(id: "com.apple.Music", name: "Apple Music", categoryID: "music", emoji: "🎵"),
        .init(id: "com.apple.calculator", name: "Calculator", categoryID: "utilities", emoji: "🔢"),
        .init(id: "com.apple.reminders", name: "Reminders", categoryID: "productivity", emoji: "📝"),
        .init(id: "com.alarmo.habit", name: "Habit", categoryID: "health", emoji: "✅"),
        .init(id: "com.apple.Health", name: "Health", categoryID: "health", emoji: "❤️"),
        .init(id: "com.apple.AppStore", name: "App Store", categoryID: "utilities", emoji: "🏪"),
        .init(id: "com.apple.Bridge", name: "Bridge", categoryID: "education", emoji: "⌚️"),
        .init(id: "com.instagram", name: "Instagram", categoryID: "social", emoji: "📸"),
        .init(id: "com.tiktok", name: "TikTok", categoryID: "social", emoji: "🎵"),
        .init(id: "com.x.twitter", name: "X", categoryID: "social", emoji: "🐦"),
        .init(id: "com.whatsapp", name: "WhatsApp", categoryID: "social", emoji: "💬"),
        .init(id: "com.spotify", name: "Spotify", categoryID: "music", emoji: "🎧"),
        .init(id: "com.youtube", name: "YouTube", categoryID: "entertainment", emoji: "📺"),
        .init(id: "com.netflix", name: "Netflix", categoryID: "entertainment", emoji: "🎬"),
        .init(id: "com.roblox", name: "Roblox", categoryID: "games", emoji: "🎮"),
        .init(id: "com.candycrush", name: "Candy Crush", categoryID: "games", emoji: "🍬"),
        .init(id: "com.notion", name: "Notion", categoryID: "productivity", emoji: "📒"),
        .init(id: "com.slack", name: "Slack", categoryID: "business", emoji: "💬"),
        .init(id: "com.reuters", name: "Reuters", categoryID: "information", emoji: "📰"),
        .init(id: "com.apple.news", name: "News", categoryID: "information", emoji: "🗞️"),
        .init(id: "com.linkedin", name: "LinkedIn", categoryID: "business", emoji: "💼"),
        .init(id: "com.amazon.mobile", name: "Amazon", categoryID: "shopping", emoji: "🛒"),
        .init(id: "com.ebay.mobile", name: "eBay", categoryID: "shopping", emoji: "📦"),
        .init(id: "com.paypal", name: "PayPal", categoryID: "finance", emoji: "💳"),
        .init(id: "com.revolut", name: "Revolut", categoryID: "finance", emoji: "💶"),
        .init(id: "com.booking", name: "Booking.com", categoryID: "travel", emoji: "🏨"),
        .init(id: "com.uber", name: "Uber", categoryID: "travel", emoji: "🚕"),
        .init(id: "com.uber.eats", name: "Uber Eats", categoryID: "food", emoji: "🍔"),
        .init(id: "com.doordash", name: "DoorDash", categoryID: "food", emoji: "🥡"),
        .init(id: "com.canva", name: "Canva", categoryID: "creativity", emoji: "🎨"),
        .init(id: "com.capcut", name: "CapCut", categoryID: "creativity", emoji: "✂️")
    ]

    static func appDisplayName(for id: String) -> String {
        apps.first(where: { $0.id == id })?.name ?? id
    }

    static func categoryDisplayName(for id: String) -> String {
        categories.first(where: { $0.id == id })?.title ?? id
    }

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var localApps: Set<String>
    @State private var localCategories: Set<String>
    @State private var expandedCategories: Set<String> = []

    let onSave: (_ selectedApps: [String], _ selectedCategories: [String]) -> Void

    init(selectedApps: [String], selectedCategories: [String], onSave: @escaping (_ selectedApps: [String], _ selectedCategories: [String]) -> Void) {
        self._localApps = State(initialValue: Set(selectedApps))
        self._localCategories = State(initialValue: Set(selectedCategories))
        self.onSave = onSave
    }

    private var filteredCategories: [MockCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.categories }
        return Self.categories.filter { category in
            category.title.localizedCaseInsensitiveContains(trimmed) ||
            Self.apps.contains { $0.categoryID == category.id && $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    private func apps(for categoryID: String) -> [MockApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryApps = Self.apps.filter { $0.categoryID == categoryID }
        guard !trimmed.isEmpty else { return categoryApps }
        return categoryApps.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.03, green: 0.06, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose Activities")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Colors.textSecondary)
                        TextField("Search", text: $query)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                    Text("SELECT APPS/WEBSITES, TAP \">\" TO EXPAND")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 16)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredCategories) { category in
                                categorySection(category: category)
                            }
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 12) {
                        let totalApps = localApps.count
                        let totalCats = localCategories.count
                        let selectionText = (totalCats > 0 ? "\(totalCats) \(totalCats == 1 ? "CATEGORY" : "CATEGORIES")" : "") + 
                                           (totalCats > 0 && totalApps > 0 ? " & " : "") +
                                           (totalApps > 0 ? "\(totalApps) \(totalApps == 1 ? "APP" : "APPS")" : "")
                        
                        Text(selectionText.isEmpty ? "0 SELECTED" : "\(selectionText) SELECTED")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)

                        Button {
                            onSave(Array(localApps).sorted(), Array(localCategories).sorted())
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func categorySection(category: MockCategory) -> some View {
        let isExpanded = expandedCategories.contains(category.id) || !query.isEmpty
        let categoryApps = apps(for: category.id)
        let hasApps = !categoryApps.isEmpty
        let selectedAppCount = categoryApps.filter { localApps.contains($0.id) }.count
        
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Selection Trigger
                Button {
                    toggleCategory(category.id)
                } label: {
                    Image(systemName: localCategories.contains(category.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(localCategories.contains(category.id) ? SettingsPalette.accent : Colors.textSecondary)
                        .padding(.leading, 12)
                }
                .buttonStyle(.plain)

                // Expansion Trigger
                Button {
                    if hasApps {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if expandedCategories.contains(category.id) {
                                expandedCategories.remove(category.id)
                            } else {
                                expandedCategories.insert(category.id)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(category.emoji)
                            .font(.system(size: 24))

                        Text(category.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if hasApps {
                            if selectedAppCount > 0 && !localCategories.contains(category.id) {
                                Text("\(selectedAppCount)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .padding(.trailing, 12)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.leading, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isExpanded && hasApps {
                ForEach(categoryApps) { app in
                    appRow(app: app)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private func appRow(app: MockApp) -> some View {
        Button {
            toggleApp(app.id)
        } label: {
            HStack(spacing: 12) {
                Spacer().frame(width: 44) // Indentation for the circle
                
                Image(systemName: localApps.contains(app.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(localApps.contains(app.id) ? SettingsPalette.accent : Colors.textSecondary)

                Text(app.emoji)
                    .font(.system(size: 24))

                Text(app.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleCategory(_ id: String) {
        if id == "all" {
            if localCategories.contains("all") {
                localCategories.removeAll()
                localApps.removeAll()
            } else {
                localCategories = Set(Self.categories.map { $0.id })
                localApps = Set(Self.apps.map { $0.id })
            }
            return
        }

        if localCategories.contains(id) {
            localCategories.remove(id)
            localCategories.remove("all")
            let categoryApps = Self.apps.filter { $0.categoryID == id }
            for app in categoryApps {
                localApps.remove(app.id)
            }
        } else {
            localCategories.insert(id)
            let categoryApps = Self.apps.filter { $0.categoryID == id }
            for app in categoryApps {
                localApps.insert(app.id)
            }
            
            let allCategoriesExceptAll = Self.categories.filter { $0.id != "all" }
            if allCategoriesExceptAll.allSatisfy({ localCategories.contains($0.id) }) {
                localCategories.insert("all")
            }
        }
    }

    private func toggleApp(_ id: String) {
        if localApps.contains(id) {
            localApps.remove(id)
            localCategories.remove("all")
            if let app = Self.apps.first(where: { $0.id == id }) {
                localCategories.remove(app.categoryID)
            }
        } else {
            localApps.insert(id)
            if let app = Self.apps.first(where: { $0.id == id }) {
                let categoryApps = Self.apps.filter { $0.categoryID == app.categoryID }
                let allSelected = categoryApps.allSatisfy { localApps.contains($0.id) }
                if allSelected {
                    localCategories.insert(app.categoryID)
                }
                
                let allCategoriesExceptAll = Self.categories.filter { $0.id != "all" }
                if allCategoriesExceptAll.allSatisfy({ localCategories.contains($0.id) }) {
                    localCategories.insert("all")
                }
            }
        }
    }
}
