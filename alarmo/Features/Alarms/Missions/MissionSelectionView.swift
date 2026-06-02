import SwiftUI

struct MissionSelectionView: View {
    private struct MissionCategory: Identifiable, Hashable {
        let id: String
        let title: String
    }

    private struct MissionItem: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let icon: String
        let iconBg: Color
        let type: WakeUpMissionType
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settingsStore = SettingsStore.shared
    @State private var showUpsell = false
    @State private var selectedCategoryId: String = "all"
    @State private var activeAllSectionCategoryId: String = "brain"
    @State private var suppressAutoSectionSync = false
    @State private var lockAllTabHighlight = false
    let onSelect: (AlarmMission) -> Void

    private var isTiimo: Bool {
        settingsStore.alarmThemeStyle.usesTiimoLayoutBranch
    }

    private var brainMissionIconBg: Color {
        isTiimo ? Color(red: 0.1, green: 0.5, blue: 0.95).opacity(0.5) : Color.cyan.opacity(0.3)
    }

    private var bodyMissionIconBg: Color {
        isTiimo ? Color(red: 0.2, green: 0.7, blue: 0.2).opacity(0.5) : Color.green.opacity(0.3)
    }

    private var religionMissionIconBg: Color {
        isTiimo ? Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.5) : Color.orange.opacity(0.25)
    }

    private var categories: [MissionCategory] {
        [
            .init(id: "brain", title: "Wake your brain"),
            .init(id: "body", title: "Wake your body"),
            .init(id: "religion", title: "Religion")
        ]
    }

    private var categoryPills: [(id: String, title: String)] {
        [("all", "All")] + categories.map { ($0.id, $0.title) }
    }

    private var missionsByCategory: [(id: String, title: String, items: [MissionItem])] {
        [
            (
                id: "brain",
                title: "Wake your brain",
                items: [
                    .init(id: "findColorTiles", title: "Find Color Tiles", subtitle: nil, icon: "square.grid.2x2.fill", iconBg: brainMissionIconBg, type: .findColorTiles),
                    .init(id: "memoryMatch", title: "Memory Match", subtitle: nil, icon: "brain.head.profile", iconBg: brainMissionIconBg, type: .memoryMatch),
                    .init(id: "ticTacToe", title: "Tic Tac Toe", subtitle: nil, icon: "xmark.square.fill", iconBg: brainMissionIconBg, type: .ticTacToe),
                    .init(id: "typing", title: "Typing", subtitle: nil, icon: "keyboard.fill", iconBg: brainMissionIconBg, type: .typing),
                    .init(id: "math", title: "Math", subtitle: nil, icon: "plus.forwardslash.minus", iconBg: brainMissionIconBg, type: .math)
                ]
            ),
            (
                id: "body",
                title: "Wake your body",
                items: [
                    .init(id: "householdItemHunt", title: "Household Item Hunt", subtitle: "AI", icon: "magnifyingglass", iconBg: bodyMissionIconBg, type: .householdItemHunt),
                    .init(id: "step", title: "Step", subtitle: nil, icon: "figure.walk", iconBg: bodyMissionIconBg, type: .step),
                    .init(id: "qrBarcode", title: "QR/Barcode", subtitle: nil, icon: "barcode.viewfinder", iconBg: bodyMissionIconBg, type: .qrBarcode),
                    .init(id: "shake", title: "Shake", subtitle: nil, icon: "iphone.radiowaves.left.and.right", iconBg: bodyMissionIconBg, type: .shake),
                    .init(id: "squat", title: "Squat", subtitle: nil, icon: "figure.strengthtraining.traditional", iconBg: bodyMissionIconBg, type: .squat),
                    .init(id: "pushups", title: "Push-ups", subtitle: nil, icon: "figure.strengthtraining.functional", iconBg: bodyMissionIconBg, type: .pushups)
                ]
            ),
            (
                id: "religion",
                title: "Religion",
                items: [
                    .init(id: "bibleVerse", title: "Bible Verse", subtitle: nil, icon: "book.closed", iconBg: religionMissionIconBg, type: .bibleVerse),
                    .init(id: "quranVerse", title: "Quran Verse", subtitle: nil, icon: "moon.stars", iconBg: religionMissionIconBg, type: .quranVerse),
                    .init(id: "bhagavadGitaVerse", title: "Bhagavad Gita Verse", subtitle: nil, icon: "book.pages", iconBg: religionMissionIconBg, type: .bhagavadGitaVerse),
                    .init(id: "affirmation", title: "Affirmation", subtitle: nil, icon: "quote.bubble", iconBg: religionMissionIconBg, type: .affirmation)
                ]
            )
        ]
    }

    private func isCategorySelected(_ categoryID: String) -> Bool {
        if selectedCategoryId == "all" {
            if lockAllTabHighlight {
                return categoryID == "all"
            }
            return categoryID == activeAllSectionCategoryId
        }
        return selectedCategoryId == categoryID
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Mission")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                ScrollViewReader { sectionProxy in
                    ScrollViewReader { tabsProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categoryPills, id: \.id) { pill in
                                    missionCategoryPill(
                                        title: pill.title,
                                        isSelected: isCategorySelected(pill.id)
                                    ) {
                                        if selectedCategoryId == "all", pill.id != "all" {
                                            lockAllTabHighlight = false
                                            scrollToMissionSection(pill.id, proxy: sectionProxy)
                                        } else {
                                            selectedCategoryId = pill.id
                                            if pill.id == "all" {
                                                lockAllTabHighlight = true
                                                activeAllSectionCategoryId = missionsByCategory.first?.id ?? "brain"
                                            } else {
                                                lockAllTabHighlight = false
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            tabsProxy.scrollTo(pill.id, anchor: .center)
                                        }
                                    }
                                    .id(pill.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .onChange(of: activeAllSectionCategoryId) { _, newValue in
                                guard selectedCategoryId == "all" else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabsProxy.scrollTo(newValue, anchor: .center)
                                }
                            }
                        }
                        .scrollIndicators(.hidden, axes: .horizontal)
                        .padding(.bottom, 12)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 30) {
                                if selectedCategoryId == "all" {
                                    ForEach(missionsByCategory, id: \.id) { section in
                                        missionSection(title: section.title) {
                                            ForEach(section.items, id: \.id) { item in
                                                missionRow(
                                                    title: item.title,
                                                    subtitle: item.subtitle,
                                                    icon: item.icon,
                                                    iconBg: item.iconBg,
                                                    type: item.type
                                                )
                                            }
                                        }
                                        .id("mission-section-\(section.id)")
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: MissionSectionOffsetPreferenceKey.self,
                                                    value: ["mission-section-\(section.id)": geo.frame(in: .named("missionScroll")).minY]
                                                )
                                            }
                                        )
                                    }
                                } else if let selectedSection = missionsByCategory.first(where: { $0.id == selectedCategoryId }) {
                                    missionSection(title: selectedSection.title) {
                                        ForEach(selectedSection.items, id: \.id) { item in
                                            missionRow(
                                                title: item.title,
                                                subtitle: item.subtitle,
                                                icon: item.icon,
                                                iconBg: item.iconBg,
                                                type: item.type
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                        }
                        .coordinateSpace(name: "missionScroll")
                        .onPreferenceChange(MissionSectionOffsetPreferenceKey.self) { offsets in
                            guard selectedCategoryId == "all", !suppressAutoSectionSync else { return }
                            guard let next = currentlyVisibleMissionSection(offsets: offsets) else { return }
                            lockAllTabHighlight = false
                            if next != activeAllSectionCategoryId {
                                activeAllSectionCategoryId = next
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden, axes: .horizontal)
            }
        }
        .onAppear {
            activeAllSectionCategoryId = missionsByCategory.first?.id ?? "brain"
        }
        .fullScreenCover(isPresented: $showUpsell) {
            ProUpsellFlowView()
        }
    }

    private func missionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .padding(.horizontal, 20)

            VStack(spacing: 20) {
                content()
            }
        }
    }

    private func missionRow(title: String, subtitle: String? = nil, icon: String, iconBg: Color, type: WakeUpMissionType) -> some View {
        Button(action: {
            if type != .off {
                onSelect(AlarmMission(type: type))
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(title == "Household Item Hunt" ? .white : iconBg.opacity(1))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subtitle == "AI" ? Color.orange.opacity(0.3) : (subtitle == "Coming Soon" ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)))
                        .foregroundColor(subtitle == "AI" ? .orange : (subtitle == "Coming Soon" ? .blue : .orange))
                        .cornerRadius(4)
                } else if type.isProFeature {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Colors.accentTeal.opacity(0.3))
                        .foregroundColor(Colors.accentTeal)
                        .cornerRadius(4)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func scrollToMissionSection(_ categoryID: String, proxy: ScrollViewProxy) {
        suppressAutoSectionSync = true
        activeAllSectionCategoryId = categoryID
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo("mission-section-\(categoryID)", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            suppressAutoSectionSync = false
        }
    }

    private func currentlyVisibleMissionSection(offsets: [String: CGFloat]) -> String? {
        let sectionIDs = missionsByCategory.map { "mission-section-\($0.id)" }
        let candidates = sectionIDs.compactMap { id -> (id: String, y: CGFloat)? in
            guard let y = offsets[id] else { return nil }
            return (id, y)
        }
        guard !candidates.isEmpty else { return nil }

        if let topVisible = candidates.filter({ $0.y >= 0 }).min(by: { $0.y < $1.y }) {
            return topVisible.id.replacingOccurrences(of: "mission-section-", with: "")
        }
        return candidates
            .filter { $0.y < 0 }
            .max(by: { $0.y < $1.y })?
            .id
            .replacingOccurrences(of: "mission-section-", with: "")
    }

    private func missionCategoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Colors.accentTeal : Colors.cardSurface.opacity(0.45))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MissionSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String : CGFloat], nextValue: () -> [String : CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
