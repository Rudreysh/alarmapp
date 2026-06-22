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
                    // ---- Block Now (timed lock) ----
                    if !blockLists.isEmpty {
                        Section {
                            TimedLockSectionContent(blockLists: blockLists)
                        } header: {
                            Text("BLOCK NOW")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }

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
                            Label("New Allow List", systemImage: "plus.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Colors.accentTeal)
                        }
                    } header: {
                        Text("ALLOW LISTS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    } footer: {
                        Text("Apps in an allow list are exempt from blocking.")
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textTertiary)
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
        // ONE List row (a single VStack) — NOT a Group. A Group here flattened the
        // dividers/toggles into separate List rows, which rendered as the empty
        // bordered boxes seen on screen. One VStack keeps internal dividers as thin
        // lines and fixes that.
        VStack(alignment: .leading, spacing: 14) {
            Divider().background(Colors.cardStroke)

            blockDuringFocusToggle

            if isBlockToggleLocked {
                hint("Block During Focus is locked until the current focus session ends.", color: Colors.accentRed, bold: true)
            } else if !hasSelectedBlockList {
                hint("Select an active block list above to enable focus blocking.", color: Colors.textTertiary, bold: false)
            }

            if engine.config.blockAppsEnabled {
                Divider().background(Colors.cardStroke)
                keepBlockedDuringBreaksToggle
                Divider().background(Colors.cardStroke)
                stopEarlyControl
            }
        }
        .padding(.vertical, 4)
    }

    private var blockDuringFocusToggle: some View {
        Toggle(isOn: Binding(
            get: { engine.config.blockAppsEnabled },
            set: {
                if isBlockToggleLocked { return }
                if $0 && !hasSelectedBlockList { return }
                var c = engine.config
                c.blockAppsEnabled = $0
                engine.updateConfig(c)
            }
        )) {
            settingLabel("Block During Focus", "Apps are blocked when the timer runs")
        }
        .tint(Colors.accentRed)
        .disabled(isBlockToggleLocked || (!hasSelectedBlockList && !engine.config.blockAppsEnabled))
    }

    private var keepBlockedDuringBreaksToggle: some View {
        Toggle(isOn: Binding(
            get: { engine.config.blockDuringBreaks },
            set: {
                var c = engine.config
                c.blockDuringBreaks = $0
                engine.updateConfig(c)
            }
        )) {
            settingLabel("Keep Blocked During Breaks", "Apps stay blocked during short and long breaks")
        }
        .tint(Colors.accentBlue)
    }

    // Single "if you try to stop early" control — replaces the two overlapping
    // "Session Difficulty" + "Unlock Missions" rows. Maps onto SessionBreakMode
    // (easy/harder/hardcore) without changing the model; the mission picker only
    // appears for the mission-gated middle level.
    private var stopEarlyControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IF YOU TRY TO STOP EARLY")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

            HStack(spacing: 8) {
                ForEach(SessionBreakMode.allCases, id: \.self) { mode in
                    levelChip(mode)
                }
            }

            Text(levelDescription(engine.config.breakMode))
                .font(.system(size: 13))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if engine.config.breakMode == .harder {
                Button(action: onOpenMissions) {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.accentBlue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock Mission")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text(selectedMissionsCount == 0 ? "Tap to choose a mission" : "\(selectedMissionsCount) selected")
                                .font(.system(size: 13))
                                .foregroundColor(selectedMissionsCount == 0 ? Colors.accentRed : Colors.textSecondary)
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
            }
        }
    }

    private func levelChip(_ mode: SessionBreakMode) -> some View {
        let selected = engine.config.breakMode == mode
        let accent: Color = mode == .hardcore ? .red : Colors.accentBlue
        return Button {
            guard !isBlockToggleLocked else { return }
            var c = engine.config
            c.breakMode = mode
            engine.updateConfig(c)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: levelIcon(mode))
                    .font(.system(size: 16, weight: .semibold))
                Text(levelLabel(mode))
                    .font(.system(size: 12, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundColor(selected ? .white : Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? accent : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(isBlockToggleLocked)
    }

    private func settingLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(Colors.textSecondary)
        }
    }

    private func hint(_ text: String, color: Color, bold: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: bold ? .semibold : .medium))
            .foregroundColor(color)
    }

    // Plain-language labels mapped onto SessionBreakMode (model unchanged).
    private func levelLabel(_ mode: SessionBreakMode) -> String {
        switch mode {
        case .easy: return "Flexible"
        case .harder: return "Committed"
        case .hardcore: return "Locked"
        }
    }
    private func levelIcon(_ mode: SessionBreakMode) -> String {
        switch mode {
        case .easy: return "lock.open"
        case .harder: return "target"
        case .hardcore: return "lock.fill"
        }
    }
    private func levelDescription(_ mode: SessionBreakMode) -> String {
        switch mode {
        case .easy: return "Stop or take a break anytime."
        case .harder: return "Complete a mission to stop early or take a break."
        case .hardcore: return "No early stops — apps stay blocked until the timer ends."
        }
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
