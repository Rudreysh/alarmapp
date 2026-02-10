import SwiftUI
import SwiftData
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AppListsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = AppListsViewModel()

    @Query(sort: \AppList.updatedAt, order: .reverse)
    private var appLists: [AppList]

    @State private var selectedDetailList: AppList?

    private var blockLists: [AppList] { appLists.filter { $0.type == .block } }
    private var allowLists: [AppList] { appLists.filter { $0.type == .allow } }

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("BLOCK LISTS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)

                        ForEach(blockLists) { list in
                            listCard(list: list)
                        }

                        dashedNewCard(title: "New Block List") {
                            if let created = viewModel.createList(type: .block, context: modelContext) {
                                selectedDetailList = created
                            }
                        }

                        Text("ALLOW LISTS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.top, 4)

                        ForEach(allowLists) { list in
                            listCard(list: list)
                        }

                        dashedNewCard(title: "New Allow List", pro: true) {
                            if let created = viewModel.createList(type: .allow, context: modelContext) {
                                selectedDetailList = created
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("App Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isEditingSelection ? "Done" : "Edit") {
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
        }
    }

    @ViewBuilder
    private func listCard(list: AppList) -> some View {
        let isSelected = viewModel.selectedListID == list.id
        let summary = listSelectionSummary(for: list)

        HStack(spacing: 14) {
            Image(systemName: list.type == .block ? "stop.fill" : "checkmark.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(list.type == .block ? Colors.accentRed : Colors.accentGreen)
                .frame(width: 44, height: 44)
                .background(Colors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(.system(size: 32/2, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text("\(list.type == .block ? "Blocking" : "Allowing") • \(summary)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }

            Spacer()

            if viewModel.isEditingSelection {
                Button {
                    viewModel.setSelectedList(list, context: modelContext)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(isSelected ? Colors.accentBlue : Colors.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Edit") {
                    selectedDetailList = list
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Colors.bgSecondary)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    @ViewBuilder
    private func dashedNewCard(title: String, pro: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 36/2, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    if pro {
                        Text("PRO")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Colors.pillGreen)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Colors.cardSurface.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundColor(Colors.cardStroke)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

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
                Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleSection
                        permissionSection
                        categoriesSection
                        appsSection
                        adultBlockingSection

                        Button {
                            viewModel.save(to: list, context: modelContext, appListsViewModel: appListsViewModel)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [Color(red: 0.67, green: 0.80, blue: 1.0), Color(red: 0.67, green: 0.55, blue: 0.95)], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(Capsule())
                        }
                        .padding(.top, 12)

                        Button {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Text("Delete Block List")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Colors.accentRed)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Block List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Block List", text: $viewModel.name)
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Text("Block List: only these apps will be blocked during your session")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !authManager.isAuthorized {
                Button {
                    requestAccessAndOpenPicker()
                } label: {
                    HStack {
                        if isRequestingAccess {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "app.badge")
                        }
                        Text("Enable Screen Time Access")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Colors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingAccess)
            }

            if let statusMessage = authManager.statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categories")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text("\(viewModel.selectedCategoriesCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
                Button("Add / Remove") {
                    openPickerWithAuthorizationCheck()
                }
                .foregroundColor(Colors.accentBlue)
            }

            selectionCard(title: viewModel.selectedCategoriesCount == 0 ? "No categories selected" : "\(viewModel.selectedCategoriesCount) selected category")
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text(viewModel.selectedAppsSummary)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                Spacer()
                Button("Add / Remove") {
                    openPickerWithAuthorizationCheck()
                }
                .foregroundColor(Colors.accentBlue)
            }

            selectionCard(title: viewModel.selectedAppsCount == 0 ? "No apps selected" : "\(viewModel.selectedAppsCount) selected app")
        }
    }

    private var adultBlockingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Adult Blocking")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $viewModel.adultBlockingEnabled)
                    .labelsHidden()
            }

            Text("Please note: this setting is a safety hook for stricter browser restrictions in future updates.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.yellow)
        }
        .padding(16)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func selectionCard(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
