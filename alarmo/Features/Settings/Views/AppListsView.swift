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
    @State private var listPendingDelete: AppList?

    private var blockLists: [AppList] { appLists.filter { $0.type == .block } }
    private var allowLists: [AppList] { appLists.filter { $0.type == .allow } }
    
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
                            
                            // Active list status row
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: activeName != nil ? "lock.fill" : "lock.open.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(activeName != nil ? .red : Colors.textTertiary)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Active Block List")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Colors.textPrimary)
                                    Text(activeName ?? "Tap a list below to activate")
                                        .font(.system(size: 13))
                                        .foregroundColor(activeName != nil ? Colors.accentRed : Colors.textTertiary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            
                            // ---- Engine Settings (Toggles) ----
                            if let engine {
                                EngineSettingsSection(engine: engine)
                            }
                        } header: {
                            Text("FOR FOCUS SESSIONS")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
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
            .navigationTitle(viewModel.isEditingSelection ? "Select List" : "App Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isEditingSelection ? "Done" : "Select") {
                        viewModel.toggleEditMode()
                    }
                    .foregroundColor(Colors.textPrimary)
                }
            }
            .sheet(item: $selectedDetailList) { list in
                BlockListDetailView(list: list, appListsViewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showProPaywall) {
                ProPaywallFlowView(startStep: .intro) {
                    viewModel.showProPaywall = false
                }
            }
            .alert("Delete this block list?", isPresented: Binding(
                get: { listPendingDelete != nil },
                set: { if !$0 { listPendingDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    guard let target = listPendingDelete else { return }
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
        let isSelected = viewModel.selectedListID == list.id
        let isActiveForFocus = settings.selectedBlockListId == list.id.uuidString
        let summary = listSelectionSummary(for: list)

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(list.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    if isActiveForFocus && list.type == .block {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                Text(summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()

            if viewModel.isEditingSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Colors.accentBlue : Colors.textTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(Colors.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isEditingSelection {
                viewModel.setSelectedList(list, context: modelContext)
            } else {
                selectedDetailList = list
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
    @StateObject private var viewModel: BlockListDetailViewModel
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared
    @State private var isRequestingAccess = false
    @State private var showPickerUnavailableAlert = false
    @State private var pickerUnavailableMessage = "Could not open app/category picker."
    #if canImport(FamilyControls)
    @State private var showSystemActivityPicker = false
    #endif
    #if targetEnvironment(simulator)
    @State private var showMockActivityPicker = false
    #endif

    init(list: AppList, appListsViewModel: AppListsViewModel) {
        self.list = list
        self.appListsViewModel = appListsViewModel
        self._viewModel = StateObject(wrappedValue: BlockListDetailViewModel(list: list))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                List {
                    Section {
                        TextField("List Name", text: $viewModel.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    } header: {
                        Text("List Identity")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    if !authManager.isAuthorized {
                        Section {
                            Button {
                                requestAccessAndOpenPicker()
                            } label: {
                                HStack {
                                    if isRequestingAccess {
                                        ProgressView().tint(Colors.accentTeal).padding(.trailing, 8)
                                    }
                                    Text("Enable Screen Time Access")
                                        .font(.body.bold())
                                        .foregroundColor(Colors.accentTeal)
                                }
                            }
                        } footer: {
                            if let msg = authManager.statusMessage, !msg.isEmpty {
                                Text(msg)
                            } else {
                                Text("Required to block apps and categories.")
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }

                    Section {
                        Button {
                            openPickerWithAuthorizationCheck()
                        } label: {
                            HStack {
                                Text("Restricted Apps")
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text("\(viewModel.selectedAppsCount) Apps")
                                    .foregroundColor(Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(Colors.textTertiary)
                            }
                        }
                        
                        Button {
                            openPickerWithAuthorizationCheck()
                        } label: {
                            HStack {
                                Text("Restricted Categories")
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text("\(viewModel.selectedCategoriesCount) Categories")
                                    .foregroundColor(Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(Colors.textTertiary)
                            }
                        }
                    } header: {
                        Text("Rules & Restrictions")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        Toggle("Adult Content Blocking", isOn: $viewModel.adultBlockingEnabled)
                            .tint(Colors.accentBlue)
                    } footer: {
                        Text("This acts as a safety hook for stricter browser restrictions in future updates.")
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        Button {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Text("Delete List")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(Colors.accentRed)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Block List Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.save(to: list, context: modelContext, appListsViewModel: appListsViewModel)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Colors.accentBlue)
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
    
    var body: some View {
        Group {
            Divider().background(Colors.cardStroke)
            
            Toggle(isOn: Binding(
                get: { engine.config.blockAppsEnabled },
                set: {
                    var c = engine.config
                    c.blockAppsEnabled = $0
                    engine.updateConfig(c)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block During Focus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textPrimary)
                    Text("Apps are shielded when the timer runs")
                        .font(.system(size: 13))
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .tint(Colors.accentRed)
            
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
                        Text("Apps stay shielded during short and long breaks")
                            .font(.system(size: 13))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .tint(Colors.accentBlue)
                
                // ---- Session Difficulty (Break Mode) ----
                Section {
                    ForEach(SessionBreakMode.allCases, id: \.self) { mode in
                        let isSelected = engine.config.breakMode == mode
                        HStack(spacing: 14) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18))
                                .foregroundColor(mode == .hardcore ? .red : Colors.accentBlue)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(mode.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isSelected },
                                set: { newValue in
                                    // Only allow turning ON (radio-style selection)
                                    if newValue {
                                        var c = engine.config
                                        c.breakMode = mode
                                        engine.updateConfig(c)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(mode == .hardcore ? .red : Colors.accentBlue)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("SESSION DIFFICULTY")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.top, 10)
                }
                .listRowBackground(Color.white.opacity(0.08))
                
                // ---- Unlock Challenges ----
                Section {
                    ForEach(UnblockChallenge.allCases.filter { $0 != .off }) { challenge in
                        let isEnabled = engine.config.enabledChallenges.contains(challenge)

                        HStack(spacing: 14) {
                            Image(systemName: challenge.iconForFocus)
                                .font(.system(size: 18))
                                .foregroundColor(isEnabled ? Colors.accentBlue : Colors.textTertiary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(challenge.titleForFocus)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(challenge.subtitleForFocus)
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                            }

                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isEnabled },
                                set: { newValue in
                                    var c = engine.config
                                    if newValue {
                                        if !c.enabledChallenges.contains(challenge) {
                                            c.enabledChallenges.append(challenge)
                                        }
                                    } else {
                                        c.enabledChallenges.removeAll { $0 == challenge }
                                    }
                                    engine.updateConfig(c)
                                }
                            ))
                            .labelsHidden()
                            .tint(Colors.accentBlue)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("UNLOCK CHALLENGES")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.top, 10)
                } footer: {
                    Text("Users must complete the selected challenge to stop or take a break during a locked session.")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)
                }
                .listRowBackground(Color.white.opacity(0.08))
            }
        }
    }
}
