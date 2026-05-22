import SwiftUI
import SwiftData
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AppListsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = AppListsViewModel()

    /// Optional engine — passed in from PomoTimerView to enable the blocking toggles.
    /// When nil (e.g. from Settings), the session toggles are hidden.
    var engine: PomodoroEngine? = nil

    @Query(sort: \AppList.updatedAt, order: .reverse)
    private var appLists: [AppList]

    @State private var selectedDetailList: AppList?
    @State private var presentCompactBlockListEditor = false
    @State private var listPendingDelete: AppList?
    @State private var showDifficultyMenu = false
    @State private var showMissionsMenu = false

    private var blockLists: [AppList] { appLists.filter { $0.type == .block } }
    private var allowLists: [AppList] { appLists.filter { $0.type == .allow } }
    private var isFocusBlockingLocked: Bool { engine?.isFocusBlockingControlsLocked ?? false }
    private var isBlockDuringFocusEnabled: Bool { engine?.config.blockAppsEnabled ?? false }
    
    // Access to the currently selected list ID to show active state
    private let settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                List {
                    // ---- Focus Session Blocking ----
                    if !blockLists.isEmpty {
                        Section {
                            let activeId = settings.selectedBlockListId
                            let activeName = blockLists.first(where: { $0.id.uuidString == activeId })?.name
                            let isFocusArmed = activeName != nil && isBlockDuringFocusEnabled
                            
                            // Active list status row
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: isFocusArmed ? "lock.fill" : "lock.open.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(isFocusArmed ? .red : Colors.textTertiary)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Active Block List")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Colors.textPrimary)
                                    Text(activeName ?? "Tap a list below to activate")
                                        .font(.system(size: 13))
                                        .foregroundColor(isFocusArmed ? Colors.accentRed : Colors.textTertiary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)

                            if isFocusBlockingLocked {
                                Text("Blocking is locked for this active focus session.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.accentRed)
                            }
                            
                            // ---- Engine Settings (Toggles) ----
                            if let engine {
                                EngineSettingsSection(
                                    engine: engine,
                                    onOpenDifficulty: { showDifficultyMenu = true },
                                    onOpenMissions: { showMissionsMenu = true }
                                )
                            }
                        } header: {
                            Text("FOR FOCUS SESSIONS")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }

                    Section {
                        ForEach(blockLists) { list in
                            listRow(list: list)
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                listPendingDelete = blockLists[index]
                            }
                        }

                        Button(action: { 
                            if let created = viewModel.createList(type: .block, context: modelContext) {
                                presentCompactBlockListEditor = true
                                selectedDetailList = created
                            }
                        }) {
                            Label("New Block List", systemImage: "plus.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Colors.accentBlue)
                        }
                    } header: {
                        Text("BLOCK LISTS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        ForEach(allowLists) { list in
                            listRow(list: list)
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                listPendingDelete = allowLists[index]
                            }
                        }

                        Button(action: { 
                            if let created = viewModel.createList(type: .allow, context: modelContext) {
                                presentCompactBlockListEditor = false
                                selectedDetailList = created
                            }
                        }) {
                            HStack {
                                Label("New Allow List", systemImage: "plus.circle.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(Colors.accentTeal)
                                Spacer()
                                Text("PRO")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Colors.pillGreen)
                                    .clipShape(Capsule())
                            }
                        }
                    } header: {
                        Text("ALLOW LISTS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
            .navigationTitle("App Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
            }
            .sheet(item: $selectedDetailList, onDismiss: {
                presentCompactBlockListEditor = false
            }) { list in
                BlockListDetailView(
                    list: list,
                    appListsViewModel: viewModel,
                    startsCompact: list.type == .block && presentCompactBlockListEditor,
                    isFocusBlockingLocked: isFocusBlockingLocked,
                    activeLockedListID: settings.selectedBlockListId
                )
            }
            .sheet(isPresented: $viewModel.showProPaywall) {
                ProPaywallFlowView(startStep: .intro) {
                    viewModel.showProPaywall = false
                }
            }
            .sheet(isPresented: $showDifficultyMenu) {
                if let engine {
                    NavigationStack {
                        SessionDifficultyPickerView(engine: engine)
                    }
                }
            }
            .sheet(isPresented: $showMissionsMenu) {
                if let engine {
                    NavigationStack {
                        MissionsPickerView(engine: engine)
                    }
                }
            }
            .alert("Delete this block list?", isPresented: Binding(
                get: { listPendingDelete != nil },
                set: { if !$0 { listPendingDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    guard let target = listPendingDelete else { return }
                    if isFocusBlockingLocked && target.id.uuidString == settings.selectedBlockListId {
                        listPendingDelete = nil
                        return
                    }
                    if let detailList = selectedDetailList, detailList.id == target.id {
                        selectedDetailList = nil
                    }
                    viewModel.deleteList(target, context: modelContext)
                    listPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    listPendingDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }

    @ViewBuilder
    private func listRow(list: AppList) -> some View {
        let isActiveForFocus = settings.selectedBlockListId == list.id.uuidString
        let isArmedForFocus = list.type == .block && isActiveForFocus && isBlockDuringFocusEnabled
        let summary = listSelectionSummary(for: list)

        HStack {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Text(summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                Spacer()
                if list.type == .block && isActiveForFocus {
                    Image(systemName: isArmedForFocus ? "lock.fill" : "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isArmedForFocus ? .red : Colors.accentBlue)
                        .padding(.trailing, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if list.type == .block && !isFocusBlockingLocked {
                    viewModel.setSelectedList(list, context: modelContext)
                }
                presentCompactBlockListEditor = false
                selectedDetailList = list
            }
            
            if list.type == .block {
                    Button(action: {
                        if !isFocusBlockingLocked {
                            viewModel.setSelectedList(list, context: modelContext)
                        }
                        presentCompactBlockListEditor = false
                        selectedDetailList = list
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 22))
                        .foregroundColor(Colors.accentBlue)
                        .padding(.leading, 8)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(Colors.textTertiary)
                    .padding(.leading, 8)
                    .onTapGesture {
                        selectedDetailList = list
                    }
            }
        }
    }

    private func listSelectionSummary(for list: AppList) -> String {
        #if targetEnvironment(simulator)
        let appCount = list.mockAppIDs.count
        let categoryCount = list.mockCategoryIDs.count
        #elseif canImport(FamilyControls)
        let appCount = list.selectedApplicationsCount
        let categoryCount = list.selectedCategoriesCount
        #else
        let appCount = 0
        let categoryCount = 0
        #endif

        let appText = appCount == 1 ? "1 app" : "\(appCount) apps"
        let categoryText = categoryCount == 1 ? "1 category" : "\(categoryCount) categories"
        return "\(appText), \(categoryText)"
    }
}

// MARK: - App Detail View

struct BlockListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let list: AppList
    @ObservedObject var appListsViewModel: AppListsViewModel
    let isFocusBlockingLocked: Bool
    let activeLockedListID: String
    @StateObject private var viewModel: BlockListDetailViewModel
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared
    @State private var isRequestingAccess = false
    @State private var showPickerUnavailableAlert = false
    @State private var pickerUnavailableMessage = "Could not open app/category picker."
    @State private var isEditing = false
    @State private var showDetailedEditor: Bool
    @FocusState private var isNameFieldFocused: Bool
    #if canImport(FamilyControls)
    @State private var showSystemActivityPicker = false
    #endif
    #if targetEnvironment(simulator)
    @State private var showMockActivityPicker = false
    #endif

    init(
        list: AppList,
        appListsViewModel: AppListsViewModel,
        startsCompact: Bool = false,
        isFocusBlockingLocked: Bool = false,
        activeLockedListID: String = ""
    ) {
        self.list = list
        self.appListsViewModel = appListsViewModel
        self.isFocusBlockingLocked = isFocusBlockingLocked
        self.activeLockedListID = activeLockedListID
        self._viewModel = StateObject(wrappedValue: BlockListDetailViewModel(list: list))
        self._showDetailedEditor = State(initialValue: !startsCompact)
    }

    var body: some View {
        ZStack {
            SettingsGlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader
                    blockListDescription
                    screenTimeAccessPrompt
                    if showDetailedEditor {
                        categoriesSection
                        appsSection
                    } else {
                        compactSelectAppsSection
                    }
                    adultBlockingSection
                    saveButton
                    if showDetailedEditor {
                        deleteButton
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
            #if canImport(FamilyControls)
            .familyActivityPicker(
                isPresented: $showSystemActivityPicker,
                selection: $viewModel.selection
            )
            #endif
            #if targetEnvironment(simulator)
            .sheet(isPresented: $showMockActivityPicker) {
                MockActivityPickerSheet(
                    selectedApps: viewModel.mockSelectedAppIDs,
                    selectedCategories: viewModel.mockSelectedCategoryIDs
                ) { apps, categories in
                    viewModel.mockSelectedAppIDs = apps
                    viewModel.mockSelectedCategoryIDs = categories
                }
            }
            #endif
            .alert("Delete this block list?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.delete(list: list, context: modelContext, appListsViewModel: appListsViewModel)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Unable to Open App Picker", isPresented: $showPickerUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pickerUnavailableMessage)
            }
            .onAppear {
                authManager.refreshStatus()
            }
    }

    private var isLockedActiveList: Bool {
        isFocusBlockingLocked &&
        list.type == .block &&
        activeLockedListID == list.id.uuidString
    }

    private var detailHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if isEditing {
                TextField("🛑 App Block List", text: $viewModel.name)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(Colors.textPrimary)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFieldFocused)
            } else {
                Text(viewModel.name)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(Colors.textPrimary)
            }

            Spacer(minLength: 8)

            Button(showDetailedEditor ? (isEditing ? "Done" : "Edit") : "Edit") {
                if isLockedActiveList {
                    return
                }
                if showDetailedEditor {
                    isEditing.toggle()
                    isNameFieldFocused = isEditing
                } else {
                    showDetailedEditor = true
                    isEditing = true
                    isNameFieldFocused = true
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isLockedActiveList ? Colors.textTertiary : Colors.accentBlue)
            .disabled(isLockedActiveList)
        }
    }

    private var blockListDescription: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🛡️ Block List: only selected apps and categories will be blocked during your session.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(3)
            if isLockedActiveList {
                Text("Editing is locked while this focus session is active.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Colors.accentRed)
            }
        }
    }

    @ViewBuilder
    private var screenTimeAccessPrompt: some View {
        if !authManager.isAuthorized {
            Button {
                requestAccessAndOpenPicker()
            } label: {
                HStack(spacing: 10) {
                    if isRequestingAccess {
                        ProgressView()
                            .tint(Colors.accentTeal)
                    }
                    Text("Enable Screen Time Access")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)

            if let msg = authManager.statusMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
            }
        }
    }

    private var compactSelectAppsSection: some View {
        Button {
            guard !isLockedActiveList else { return }
            openPickerWithAuthorizationCheck()
        } label: {
            HStack(spacing: 10) {
                Text("Select Apps")
                    .font(.system(size: 18, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLockedActiveList)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                Text("Categories")
                    .font(.system(size: 20, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(Colors.textPrimary)
                Text("\(selectedCategoriesCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
                Button("Add / Remove") {
                    openPickerWithAuthorizationCheck()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor((isEditing && !isLockedActiveList) ? Colors.accentBlue : Colors.textTertiary)
                .disabled(!isEditing || isLockedActiveList)
            }

            if selectedCategoriesCount == 0 {
                Text("No categories selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.top, 2)
            } else {
                selectedCategoriesList
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                Text("Apps")
                    .font(.system(size: 20, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Button("Add / Remove") {
                    openPickerWithAuthorizationCheck()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor((isEditing && !isLockedActiveList) ? Colors.accentBlue : Colors.textTertiary)
                .disabled(!isEditing || isLockedActiveList)
            }

            Text("\(selectedAppsCount) apps selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

            if selectedAppsCount == 0 {
                Text("No apps selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.top, 2)
            } else {
                selectedAppsList
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var adultBlockingSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "18.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Colors.textSecondary)
            Text("Adult Content Blocking")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Toggle("", isOn: $viewModel.adultBlockingEnabled)
                .labelsHidden()
                .tint(Colors.accentBlue)
                .disabled(isLockedActiveList)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            viewModel.save(to: list, context: modelContext, appListsViewModel: appListsViewModel)
            dismiss()
        } label: {
            Text("Save")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.62, green: 0.76, blue: 1.0), Color(red: 0.63, green: 0.9, blue: 0.93)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            viewModel.showDeleteConfirmation = true
        } label: {
            Text("Delete Block List")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Colors.accentRed)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .buttonStyle(.plain)
    }

    private var selectedAppsCount: Int {
        #if targetEnvironment(simulator)
        return viewModel.mockSelectedAppIDs.count
        #elseif canImport(FamilyControls)
        return viewModel.selection.applicationTokens.count
        #else
        return 0
        #endif
    }

    private var selectedCategoriesCount: Int {
        #if targetEnvironment(simulator)
        return viewModel.mockSelectedCategoryIDs.count
        #elseif canImport(FamilyControls)
        return viewModel.selection.categoryTokens.count
        #else
        return 0
        #endif
    }

    @ViewBuilder
    private var selectedCategoriesList: some View {
        #if targetEnvironment(simulator)
        let categories = viewModel.mockSelectedCategoryIDs.sorted()
        ForEach(categories, id: \.self) { categoryID in
            selectionBadgeRow(
                title: MockActivityPickerSheet.categoryDisplayName(for: categoryID),
                symbol: "square.grid.2x2"
            )
        }
        #elseif canImport(FamilyControls)
        ForEach(Array(viewModel.selection.categoryTokens), id: \.self) { token in
            tokenBadgeRow(symbol: "square.grid.2x2") {
                Label(token)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var selectedAppsList: some View {
        #if targetEnvironment(simulator)
        let apps = viewModel.mockSelectedAppIDs.sorted()
        ForEach(apps, id: \.self) { appID in
            selectionBadgeRow(
                title: MockActivityPickerSheet.appDisplayName(for: appID),
                symbol: "app.fill"
            )
        }
        #elseif canImport(FamilyControls)
        ForEach(Array(viewModel.selection.applicationTokens), id: \.self) { token in
            tokenBadgeRow(symbol: "app.fill") {
                Label(token)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        #else
        EmptyView()
        #endif
    }

    private func selectionBadgeRow(title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tokenBadgeRow<Content: View>(
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            content()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func openPickerWithAuthorizationCheck() {
        if authManager.isAuthorized {
            presentSystemPicker()
            return
        }
        requestAccessAndOpenPicker()
    }

    private func requestAccessAndOpenPicker() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task {
            await authManager.requestAuthorization()
            await MainActor.run {
                isRequestingAccess = false
                if authManager.isAuthorized {
                    presentSystemPicker()
                } else {
                    pickerUnavailableMessage = authManager.statusMessage ?? "Screen Time access was not granted."
                    showPickerUnavailableAlert = true
                }
            }
        }
    }

    private func presentSystemPicker() {
        #if targetEnvironment(simulator)
        showMockActivityPicker = true
        #elseif canImport(FamilyControls)
        showSystemActivityPicker = true
        #else
        pickerUnavailableMessage = "Family Controls is not available in this build."
        showPickerUnavailableAlert = true
        #endif
    }
}

struct EngineSettingsSection: View {
    @ObservedObject var engine: PomodoroEngine
    let onOpenDifficulty: () -> Void
    let onOpenMissions: () -> Void
    
    private var hasSelectedBlockList: Bool {
        !engine.config.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedMissionsCount: Int {
        engine.config.enabledChallenges.filter { $0 != .off }.count
    }

    private var isBlockToggleLocked: Bool {
        engine.isFocusBlockingControlsLocked
    }
    
    var body: some View {
        Group {
            Divider().background(Colors.cardStroke)
            
            Toggle(isOn: Binding(
                get: { engine.config.blockAppsEnabled },
                set: {
                    if isBlockToggleLocked {
                        return
                    }
                    if $0 && !hasSelectedBlockList {
                        return
                    }
                    var c = engine.config
                    c.blockAppsEnabled = $0
                    engine.updateConfig(c)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block During Focus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textPrimary)
                    Text("Apps are blocked when the timer runs")
                        .font(.system(size: 13))
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .tint(Colors.accentRed)
            .disabled(isBlockToggleLocked || (!hasSelectedBlockList && !engine.config.blockAppsEnabled))
            
            if isBlockToggleLocked {
                Text("Block During Focus is locked until the current focus session ends.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.accentRed)
                    .padding(.top, 6)
            } else if !hasSelectedBlockList {
                Text("Select an active block list above to enable focus blocking.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.top, 6)
            }
            
            if engine.config.blockAppsEnabled {
                Divider().background(Colors.cardStroke)
                
                Toggle(isOn: Binding(
                    get: { engine.config.blockDuringBreaks },
                    set: {
                        var c = engine.config
                        c.blockDuringBreaks = $0
                        engine.updateConfig(c)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep Blocked During Breaks")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                        Text("Apps stay blocked during short and long breaks")
                            .font(.system(size: 13))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .tint(Colors.accentBlue)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("SESSION RULES")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.top, 10)

                    Button(action: onOpenDifficulty) {
                        HStack(spacing: 12) {
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.accentBlue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Session Difficulty")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(engine.config.breakMode.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(engine.config.breakMode.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(engine.config.breakMode == .hardcore ? .red : Colors.accentBlue)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenMissions) {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.accentBlue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unlock Missions")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(selectedMissionsCount == 0 ? "No mission selected" : "\(selectedMissionsCount) selected")
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("Users must complete selected missions to stop or take a break during locked sessions.")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

private struct SessionDifficultyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: PomodoroEngine

    var body: some View {
        List {
            ForEach(SessionBreakMode.allCases, id: \.self) { mode in
                Button {
                    var config = engine.config
                    config.breakMode = mode
                    engine.updateConfig(config)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(mode == .hardcore ? .red : Colors.accentBlue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text(mode.subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(Colors.textSecondary)
                        }
                        Spacer()
                        if engine.config.breakMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Colors.accentBlue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Session Difficulty")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SettingsGlassBackground())
    }
}

private struct MissionsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: PomodoroEngine

    var body: some View {
        List {
            ForEach(UnblockChallenge.allCases.filter { $0 != .off }) { challenge in
                let isEnabled = engine.config.enabledChallenges.contains(challenge)
                Toggle(isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        var config = engine.config
                        if newValue {
                            if !config.enabledChallenges.contains(challenge) {
                                config.enabledChallenges.append(challenge)
                            }
                        } else {
                            config.enabledChallenges.removeAll { $0 == challenge }
                        }
                        engine.updateConfig(config)
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: challenge.iconForFocus)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isEnabled ? Colors.accentBlue : Colors.textTertiary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.titleForFocus)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text(challenge.subtitleForFocus)
                                .font(.system(size: 13))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                }
                .tint(Colors.accentBlue)
            }
        }
        .navigationTitle("Unlock Missions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SettingsGlassBackground())
    }
}
