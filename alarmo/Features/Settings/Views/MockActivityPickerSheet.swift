import SwiftUI

struct MockActivityPickerSheet: View {
    struct MockCategory: Identifiable, Hashable {
        let id: String
        let title: String
    }

    struct MockApp: Identifiable, Hashable {
        let id: String
        let name: String
        let categoryID: String
    }

    private static let categories: [MockCategory] = [
        .init(id: "all", title: "All Apps & Categories"),
        .init(id: "social", title: "Social"),
        .init(id: "games", title: "Games"),
        .init(id: "entertainment", title: "Entertainment"),
        .init(id: "productivity", title: "Productivity"),
        .init(id: "education", title: "Education"),
        .init(id: "utilities", title: "Utilities"),
        .init(id: "health", title: "Health & Fitness")
    ]

    private static let apps: [MockApp] = [
        .init(id: "com.apple.mobilesafari", name: "Safari", categoryID: "utilities"),
        .init(id: "com.apple.MobileSMS", name: "Messages", categoryID: "social"),
        .init(id: "com.apple.MobileMail", name: "Mail", categoryID: "productivity"),
        .init(id: "com.apple.Music", name: "Music", categoryID: "entertainment"),
        .init(id: "com.apple.calculator", name: "Calculator", categoryID: "utilities"),
        .init(id: "com.apple.reminders", name: "Reminders", categoryID: "productivity"),
        .init(id: "com.alarmo.habit", name: "Habit", categoryID: "health"),
        .init(id: "com.apple.Health", name: "Health", categoryID: "health"),
        .init(id: "com.apple.AppStore", name: "App Store", categoryID: "entertainment"),
        .init(id: "com.apple.Bridge", name: "Bridge", categoryID: "education")
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var localApps: Set<String>
    @State private var localCategories: Set<String>

    let onSave: (_ selectedApps: [String], _ selectedCategories: [String]) -> Void

    init(selectedApps: [String], selectedCategories: [String], onSave: @escaping (_ selectedApps: [String], _ selectedCategories: [String]) -> Void) {
        self._localApps = State(initialValue: Set(selectedApps))
        self._localCategories = State(initialValue: Set(selectedCategories))
        self.onSave = onSave
    }

    private var filteredApps: [MockApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.apps }
        return Self.apps.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

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
                    .background(Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                    Text("SELECT APPS/WEBSITES, TAP \">\" TO EXPAND")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 16)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Self.categories) { category in
                                row(
                                    title: category.title,
                                    isSelected: localCategories.contains(category.id),
                                    action: { toggleCategory(category.id) }
                                )
                            }
                        }
                        .background(Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredApps) { app in
                                row(
                                    title: app.name,
                                    subtitle: categoryTitle(for: app.categoryID),
                                    isSelected: localApps.contains(app.id),
                                    action: { toggleApp(app.id) }
                                )
                            }
                        }
                        .background(Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    Text("\(localApps.count) APP & \(localCategories.count) CATEGORY SELECTED")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    VStack(spacing: 10) {
                        Button {
                            onSave(Array(localApps).sorted(), Array(localCategories).sorted())
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
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
                }
            }
        }
    }

    @ViewBuilder
    private func row(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? Colors.accentBlue : Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 48)
    }

    private func categoryTitle(for id: String) -> String {
        Self.categories.first(where: { $0.id == id })?.title ?? "Other"
    }

    private func toggleCategory(_ id: String) {
        if localCategories.contains(id) {
            localCategories.remove(id)
        } else {
            localCategories.insert(id)
        }
    }

    private func toggleApp(_ id: String) {
        if localApps.contains(id) {
            localApps.remove(id)
        } else {
            localApps.insert(id)
        }
    }
}
