import SwiftUI
import SwiftData
#if canImport(FamilyControls)
import FamilyControls
#if canImport(ManagedSettings)
import ManagedSettings
#endif
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

                VStack(spacing: 0) {
                    HStack {
                        Text("App Lists")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Colors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    List {
                        if !blockLists.isEmpty {
                            Section {
                                let activeId = settings.selectedBlockListId
                                let activeName = blockLists.first(where: { $0.id.uuidString == activeId })?.name
                                let isFocusArmed = activeName != nil && isBlockDuringFocusEnabled

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

                            Button {
                                if let created = viewModel.createList(type: .block, context: modelContext) {
                                    if !isFocusBlockingLocked {
                                        engine?.setActiveBlockList(created)
                                    }
                                    presentCompactBlockListEditor = true
                                    selectedDetailList = created
                                }
                            } label: {
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

                            Button {
                                if let created = viewModel.createList(type: .allow, context: modelContext) {
                                    presentCompactBlockListEditor = false
                                    selectedDetailList = created
                                }
                            } label: {
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
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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
                    engine?.setActiveBlockList(list)
                }
                presentCompactBlockListEditor = false
                selectedDetailList = list
            }
            
            if list.type == .block {
                    Button(action: {
                        if !isFocusBlockingLocked {
                            viewModel.setSelectedList(list, context: modelContext)
                            engine?.setActiveBlockList(list)
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
    @State private var listType: AppListType
    @FocusState private var isNameFieldFocused: Bool
    #if canImport(FamilyControls)
    @State private var showSystemActivityPicker = false
    @State private var selectedApplicationTokensForRemoval: Set<ApplicationToken> = []
    #endif
    #if targetEnvironment(simulator)
    @State private var showMockActivityPicker = false
    @State private var expandedSelectedCategoryIDs: Set<String> = []
    @State private var selectedCategoryIDsForRemoval: Set<String> = []
    @State private var selectedAppIDsForRemoval: Set<String> = []
    @State private var categoryEditorID: String?
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
        self._listType = State(initialValue: list.type)
    }

    var body: some View {
        ZStack {
            SettingsGlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    opalHeader
                    blockAllowSegmented
                    addAppOrWebsiteRow
                    screenTimeAccessPrompt
                    selectedOrEmpty
                    neverAllowedSection
                    Text(listType == .allow
                         ? "Only the apps and websites above stay allowed — everything else is blocked."
                         : "Selected apps and websites are blocked during your session.")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)
                        .padding(.horizontal, 4)
                    saveButton
                    deleteButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
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
            .sheet(
                isPresented: Binding(
                    get: { categoryEditorID != nil },
                    set: { if !$0 { categoryEditorID = nil } }
                )
            ) {
                if let categoryID = categoryEditorID {
                    MockCategoryEditorSheet(
                        categoryID: categoryID,
                        selectedApps: viewModel.mockSelectedAppIDs,
                        selectedCategories: viewModel.mockSelectedCategoryIDs
                    ) { apps, categories in
                        viewModel.mockSelectedAppIDs = apps
                        viewModel.mockSelectedCategoryIDs = categories
                    }
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

    private var opalHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            TextField("Block List", text: $viewModel.name)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundColor(Colors.textPrimary)
                .textInputAutocapitalization(.words)
                .focused($isNameFieldFocused)
                .disabled(isLockedActiveList)
                .frame(maxWidth: .infinity)

            Button { persistAndDismiss() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Colors.accentTeal))
            }
            .buttonStyle(.plain)
        }
    }

    private var blockAllowSegmented: some View {
        HStack(spacing: 0) {
            segmentButton("Block", .block)
            segmentButton("Allow Only", .allow)
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .opacity(isLockedActiveList ? 0.5 : 1)
    }

    private func segmentButton(_ title: String, _ type: AppListType) -> some View {
        let selected = listType == type
        return Button {
            guard !isLockedActiveList else { return }
            listType = type
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selected ? Colors.textPrimary : Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? Color.white.opacity(0.16) : .clear))
        }
        .buttonStyle(.plain)
        .disabled(isLockedActiveList)
    }

    private var addAppOrWebsiteRow: some View {
        HStack(spacing: 12) {
            Button {
                guard !isLockedActiveList else { return }
                openPickerWithAuthorizationCheck()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.accentBlue)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
                    Text("Add App or Website")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(isLockedActiveList)

            if selectedAppsCount > 0 || selectedCategoriesCount > 0 {
                Button(isEditing ? "Done" : "Edit") {
                    toggleEditingMode()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isLockedActiveList ? Colors.textTertiary : Colors.accentBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
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

    @ViewBuilder
    private var selectedOrEmpty: some View {
        if selectedAppsCount == 0 && selectedCategoriesCount == 0 {
            Text(listType == .allow ? "No apps will be allowed" : "No apps will be blocked")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 8) {
                bulkDeleteToolbar
                selectedCategoriesList
                selectedAppsList
            }
        }
    }

    @ViewBuilder
    private var bulkDeleteToolbar: some View {
        #if targetEnvironment(simulator)
        let selectedCount = selectedCategoryIDsForRemoval.count + selectedAppIDsForRemoval.count
        if isEditing && selectedCount > 0 {
            HStack(spacing: 12) {
                Text("\(selectedCount) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                Spacer()

                Button("Clear") {
                    clearRemovalSelection()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

                Button {
                    deleteSelectedMockItems()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Colors.accentRed)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        #elseif canImport(FamilyControls)
        let selectedCount = selectedApplicationTokensForRemoval.count
        if isEditing && selectedCount > 0 {
            HStack(spacing: 12) {
                Text("\(selectedCount) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                Spacer()

                Button("Clear") {
                    selectedApplicationTokensForRemoval.removeAll()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

                Button {
                    deleteSelectedApplicationTokens()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Colors.accentRed)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        #endif
    }

    private var neverAllowedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEVER ALLOWED")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: "18.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Colors.accentRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adult Websites")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Text("Always blocked while this list is active")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.adultBlockingEnabled)
                    .labelsHidden()
                    .tint(Colors.accentBlue)
                    .disabled(isLockedActiveList)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func persistAndDismiss() {
        if list.type != listType { list.type = listType }
        viewModel.save(to: list, context: modelContext, appListsViewModel: appListsViewModel)
        dismiss()
    }

    private var saveButton: some View {
        Button {
            persistAndDismiss()
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
            selectedCategoryRow(categoryID: categoryID)
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
        let apps = standaloneSelectedMockApps
        ForEach(apps, id: \.self) { appID in
            selectedMockAppRow(appID: appID, indent: 0, categoryID: nil)
        }
        #elseif canImport(FamilyControls)
        ForEach(Array(viewModel.selection.applicationTokens), id: \.self) { token in
            selectedApplicationTokenRow(token: token)
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

    #if canImport(FamilyControls)
    private func selectedApplicationTokenRow(token: ApplicationToken) -> some View {
        let isMarkedForRemoval = selectedApplicationTokensForRemoval.contains(token)

        return HStack(spacing: 12) {
            if isEditing {
                Button {
                    toggleApplicationTokenRemovalSelection(token)
                } label: {
                    Image(systemName: isMarkedForRemoval ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isMarkedForRemoval ? Colors.accentBlue : Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }

            Label(token)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            if isEditing {
                Button {
                    removeApplicationToken(token)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func toggleApplicationTokenRemovalSelection(_ token: ApplicationToken) {
        guard !isLockedActiveList else { return }
        if selectedApplicationTokensForRemoval.contains(token) {
            selectedApplicationTokensForRemoval.remove(token)
        } else {
            selectedApplicationTokensForRemoval.insert(token)
        }
    }

    private func removeApplicationToken(_ token: ApplicationToken) {
        guard !isLockedActiveList else { return }
        viewModel.selection.applicationTokens.remove(token)
        selectedApplicationTokensForRemoval.remove(token)
    }

    private func deleteSelectedApplicationTokens() {
        guard !isLockedActiveList else { return }
        for token in selectedApplicationTokensForRemoval {
            viewModel.selection.applicationTokens.remove(token)
        }
        selectedApplicationTokensForRemoval.removeAll()
    }
    #endif

    #if targetEnvironment(simulator)
    private var standaloneSelectedMockApps: [String] {
        viewModel.mockSelectedAppIDs
            .filter { appID in
                guard let app = MockActivityPickerSheet.apps.first(where: { $0.id == appID }) else { return true }
                return !viewModel.mockSelectedCategoryIDs.contains(app.categoryID)
            }
            .sorted { MockActivityPickerSheet.appDisplayName(for: $0) < MockActivityPickerSheet.appDisplayName(for: $1) }
    }

    @ViewBuilder
    private func selectedCategoryRow(categoryID: String) -> some View {
        let isExpanded = expandedSelectedCategoryIDs.contains(categoryID)
        let categoryApps = MockActivityPickerSheet.apps
            .filter { $0.categoryID == categoryID && viewModel.mockSelectedAppIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
        let isMarkedForRemoval = selectedCategoryIDsForRemoval.contains(categoryID)

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isEditing {
                    Button {
                        toggleCategoryRemovalSelection(categoryID)
                    } label: {
                        Image(systemName: isMarkedForRemoval ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isMarkedForRemoval ? Colors.accentBlue : Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLockedActiveList)
                }

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(MockActivityPickerSheet.categoryDisplayName(for: categoryID))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Text("\(categoryApps.count) selected apps")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textTertiary)
                }

                Spacer()

                Button {
                    categoryEditorID = categoryID
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)

                if !categoryApps.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if isExpanded {
                                expandedSelectedCategoryIDs.remove(categoryID)
                            } else {
                                expandedSelectedCategoryIDs.insert(categoryID)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    Button {
                        removeMockCategory(categoryID)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.accentRed)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLockedActiveList)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isExpanded && !categoryApps.isEmpty {
                VStack(spacing: 8) {
                    ForEach(categoryApps) { app in
                        selectedMockAppRow(appID: app.id, indent: 28, categoryID: categoryID)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func selectedMockAppRow(appID: String, indent: CGFloat, categoryID: String?) -> some View {
        let isMarkedForRemoval = selectedAppIDsForRemoval.contains(appID)
        HStack(spacing: 12) {
            if isEditing {
                Button {
                    toggleAppRemovalSelection(appID)
                } label: {
                    Image(systemName: isMarkedForRemoval ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isMarkedForRemoval ? Colors.accentBlue : Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }

            Text(MockActivityPickerSheet.appDisplayName(for: appID))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            if isEditing {
                Button {
                    removeMockApp(appID, from: categoryID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                }
                .buttonStyle(.plain)
                .disabled(isLockedActiveList)
            }
        }
        .padding(.leading, 16 + indent)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func removeMockCategory(_ categoryID: String) {
        guard !isLockedActiveList else { return }
        viewModel.mockSelectedCategoryIDs.removeAll { $0 == categoryID }
        let categoryAppIDs = Set(MockActivityPickerSheet.apps.filter { $0.categoryID == categoryID }.map(\.id))
        viewModel.mockSelectedAppIDs.removeAll { categoryAppIDs.contains($0) }
        expandedSelectedCategoryIDs.remove(categoryID)
        selectedCategoryIDsForRemoval.remove(categoryID)
        selectedAppIDsForRemoval.subtract(categoryAppIDs)
    }

    private func removeMockApp(_ appID: String, from categoryID: String?) {
        guard !isLockedActiveList else { return }
        viewModel.mockSelectedAppIDs.removeAll { $0 == appID }
        selectedAppIDsForRemoval.remove(appID)
        if let categoryID {
            viewModel.mockSelectedCategoryIDs.removeAll { $0 == categoryID }
            selectedCategoryIDsForRemoval.remove(categoryID)
        } else if let app = MockActivityPickerSheet.apps.first(where: { $0.id == appID }) {
            let categoryApps = MockActivityPickerSheet.apps.filter { $0.categoryID == app.categoryID }
            let allSelected = categoryApps.allSatisfy { viewModel.mockSelectedAppIDs.contains($0.id) }
            if !allSelected {
                viewModel.mockSelectedCategoryIDs.removeAll { $0 == app.categoryID }
                selectedCategoryIDsForRemoval.remove(app.categoryID)
            }
        }
    }

    private func toggleCategoryRemovalSelection(_ categoryID: String) {
        guard !isLockedActiveList else { return }
        if selectedCategoryIDsForRemoval.contains(categoryID) {
            selectedCategoryIDsForRemoval.remove(categoryID)
        } else {
            selectedCategoryIDsForRemoval.insert(categoryID)
        }
    }

    private func toggleAppRemovalSelection(_ appID: String) {
        guard !isLockedActiveList else { return }
        if selectedAppIDsForRemoval.contains(appID) {
            selectedAppIDsForRemoval.remove(appID)
        } else {
            selectedAppIDsForRemoval.insert(appID)
        }
    }

    private func clearRemovalSelection() {
        selectedCategoryIDsForRemoval.removeAll()
        selectedAppIDsForRemoval.removeAll()
    }

    private func deleteSelectedMockItems() {
        guard !isLockedActiveList else { return }
        let categories = Array(selectedCategoryIDsForRemoval)
        let apps = Array(selectedAppIDsForRemoval)

        for categoryID in categories {
            removeMockCategory(categoryID)
        }

        for appID in apps {
            removeMockApp(appID, from: mockParentCategoryID(for: appID))
        }

        clearRemovalSelection()
    }

    private func toggleEditingMode() {
        guard !isLockedActiveList else { return }
        if isEditing {
            clearRemovalSelection()
        }
        isEditing.toggle()
    }

    private func mockParentCategoryID(for appID: String) -> String? {
        guard let app = MockActivityPickerSheet.apps.first(where: { $0.id == appID }) else { return nil }
        return viewModel.mockSelectedCategoryIDs.contains(app.categoryID) ? app.categoryID : nil
    }
    #endif

    #if !targetEnvironment(simulator)
    private func toggleEditingMode() {
        guard !isLockedActiveList else { return }
        if isEditing {
            selectedApplicationTokensForRemoval.removeAll()
        }
        isEditing.toggle()
    }
    #endif

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

#if targetEnvironment(simulator)
private struct MockCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categoryID: String
    @State private var localApps: Set<String>
    @State private var localCategories: Set<String>
    @State private var selectedForRemoval: Set<String> = []
    let onSave: (_ selectedApps: [String], _ selectedCategories: [String]) -> Void

    init(
        categoryID: String,
        selectedApps: [String],
        selectedCategories: [String],
        onSave: @escaping (_ selectedApps: [String], _ selectedCategories: [String]) -> Void
    ) {
        self.categoryID = categoryID
        self._localApps = State(initialValue: Set(selectedApps))
        self._localCategories = State(initialValue: Set(selectedCategories))
        self.onSave = onSave
    }

    private var categoryTitle: String {
        MockActivityPickerSheet.categoryDisplayName(for: categoryID)
    }

    private var categoryApps: [MockActivityPickerSheet.MockApp] {
        MockActivityPickerSheet.apps
            .filter { $0.categoryID == categoryID }
            .sorted { $0.name < $1.name }
    }

    private var allSelected: Bool {
        !categoryApps.isEmpty && categoryApps.allSatisfy { localApps.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                VStack(spacing: 16) {
                    if !selectedForRemoval.isEmpty {
                        HStack(spacing: 12) {
                            Text("\(selectedForRemoval.count) selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)

                            Spacer()

                            Button("Clear") {
                                selectedForRemoval.removeAll()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                            Button {
                                deleteSelectedApps()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Delete")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Colors.accentRed)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }

                    HStack {
                        Button(allSelected ? "Remove All" : "Select All") {
                            toggleAll()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.accentBlue)

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(categoryApps) { app in
                                HStack(spacing: 12) {
                                    Button {
                                        toggleRemovalSelection(app.id)
                                    } label: {
                                        Image(systemName: selectedForRemoval.contains(app.id) ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(selectedForRemoval.contains(app.id) ? Colors.accentBlue : Colors.textSecondary)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        toggleMembership(app.id)
                                    } label: {
                                        Image(systemName: localApps.contains(app.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(localApps.contains(app.id) ? Colors.accentTeal : Colors.textSecondary)
                                    }
                                    .buttonStyle(.plain)

                                    Text(app.emoji)
                                        .font(.system(size: 20))

                                    Text(app.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Colors.textPrimary)

                                    Spacer()

                                    Button {
                                        removeSingle(app.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Colors.accentRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(categoryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        persistAndDismiss()
                    }
                }
            }
        }
    }

    private func toggleAll() {
        if allSelected {
            for app in categoryApps {
                localApps.remove(app.id)
            }
            localCategories.remove(categoryID)
        } else {
            for app in categoryApps {
                localApps.insert(app.id)
            }
            localCategories.insert(categoryID)
        }
    }

    private func toggleMembership(_ appID: String) {
        if localApps.contains(appID) {
            localApps.remove(appID)
        } else {
            localApps.insert(appID)
        }

        if categoryApps.allSatisfy({ localApps.contains($0.id) }) {
            localCategories.insert(categoryID)
        } else {
            localCategories.remove(categoryID)
        }
    }

    private func toggleRemovalSelection(_ appID: String) {
        if selectedForRemoval.contains(appID) {
            selectedForRemoval.remove(appID)
        } else {
            selectedForRemoval.insert(appID)
        }
    }

    private func removeSingle(_ appID: String) {
        localApps.remove(appID)
        selectedForRemoval.remove(appID)
        localCategories.remove(categoryID)
    }

    private func deleteSelectedApps() {
        for appID in selectedForRemoval {
            localApps.remove(appID)
        }
        selectedForRemoval.removeAll()
        if categoryApps.allSatisfy({ localApps.contains($0.id) }) {
            localCategories.insert(categoryID)
        } else {
            localCategories.remove(categoryID)
        }
    }

    private func persistAndDismiss() {
        onSave(Array(localApps).sorted(), Array(localCategories).sorted())
        dismiss()
    }
}
#endif

struct EngineSettingsSection: View {
    @ObservedObject var engine: PomodoroEngine
    let onOpenMissions: () -> Void
    private let settings = SettingsStore.shared
    @State private var showStrictModeWarning = false

    private var hasSelectedBlockList: Bool {
        !effectiveSelectedBlockListId.isEmpty
    }
    private var selectedMissionsCount: Int {
        engine.config.enabledChallenges.filter { $0 != .off }.count
    }
    private var isBlockToggleLocked: Bool {
        engine.isFocusBlockingControlsLocked
    }
    private var effectiveSelectedBlockListId: String {
        let configId = engine.config.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configId.isEmpty { return configId }
        return settings.selectedBlockListId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        // ONE List row (a single VStack) — NOT a Group. A Group here flattened the
        // dividers/toggles into separate List rows, which rendered as the empty
        // bordered boxes seen on screen. One VStack keeps internal dividers as thin
        // lines and fixes that.
        VStack(alignment: .leading, spacing: 14) {
            Divider().background(Colors.cardStroke)
            blockDuringFocusToggle

            if engine.config.blockAppsEnabled {
                Divider().background(Colors.cardStroke)
                strictModeControl
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Two modes only (Normal / Strict). Normalize any legacy "stop anytime"
            // (.easy) config to Normal=mission-gated so the UI and behavior match.
            if engine.config.blockAppsEnabled, engine.config.breakMode == .easy {
                var c = engine.config
                c.breakMode = .harder
                engine.updateConfig(c)
            }
        }
    }

    private var blockDuringFocusToggle: some View {
        Toggle(isOn: Binding(
            get: { engine.config.blockAppsEnabled },
            set: {
                if isBlockToggleLocked { return }
                var c = engine.config
                if $0 {
                    let selectedId = effectiveSelectedBlockListId
                    guard !selectedId.isEmpty else { return }
                    c.selectedBlockListId = selectedId
                    // Default newly-enabled focus blocking to mission-based unlock
                    // instead of carrying forward a previously strict setting.
                    c.breakMode = .harder
                    if c.enabledChallenges.isEmpty || c.enabledChallenges.allSatisfy({ $0 == .off }) {
                        c.enabledChallenges = [.math]
                    }
                }
                c.blockAppsEnabled = $0
                engine.updateConfig(c)
            }
        )) {
            Text("Block During Focus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textPrimary)
        }
        .tint(Colors.accentRed)
        .disabled(isBlockToggleLocked || (!hasSelectedBlockList && !engine.config.blockAppsEnabled))
    }

    private var isStrict: Bool { engine.config.breakMode == .hardcore }

    // Two modes only — Normal vs Strict. Strict = apps stay blocked until the timer
    // ends and iOS app deletion is disabled while the strict focus session is
    // actively running. Normal = unlock early by completing the chosen mission,
    // shown directly below the toggle.
    private var strictModeControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { isStrict },
                set: { on in
                    guard !isBlockToggleLocked else { return }
                    if on && !isStrict {
                        showStrictModeWarning = true
                    } else {
                        setStrictModeEnabled(false)
                    }
                }
            )) {
                Text("Strict Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
            }
            .tint(.red)
            .disabled(isBlockToggleLocked)
            .alert("Enable Strict Mode?", isPresented: $showStrictModeWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Enable") {
                    setStrictModeEnabled(true)
                }
            } message: {
                Text("While this session is active, iOS app deletion will be disabled.")
            }

            if isStrict {
                Text("While this session is active, iOS app deletion will be disabled.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }

            if !isStrict {
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
                            Text(selectedMissionsCount == 0 ? "Tap to choose" : "\(selectedMissionsCount) selected")
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

    private func setStrictModeEnabled(_ enabled: Bool) {
        var c = engine.config
        c.breakMode = enabled ? .hardcore : .harder
        engine.updateConfig(c)
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
