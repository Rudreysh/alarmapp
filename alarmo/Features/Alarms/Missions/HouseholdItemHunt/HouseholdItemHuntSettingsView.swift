import SwiftUI
import AVFoundation

struct HouseholdItemHuntSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let initialMission: AlarmMission
    let onSave: (HouseholdItemHuntMissionConfig) -> Void

    @State private var selectedItemIDs: Set<String>
    @State private var customItems: [HouseholdItemHuntCatalogItem]

    @State private var showSelectedOnly = false
    @State private var showAlarmPreview = false
    @State private var showMissionPreview = false
    @State private var previewMission: AlarmMission?

    @State private var showAddCustomSheet = false
    @State private var draftCustomName = ""
    @State private var pendingCustomName = ""
    @State private var showCustomCameraPicker = false
    @State private var showCustomPhotoLibraryPicker = false

    @State private var activeAlert: ActiveAlert?

    init(initialMission: AlarmMission, onSave: @escaping (HouseholdItemHuntMissionConfig) -> Void) {
        self.initialMission = initialMission
        self.onSave = onSave
        _selectedItemIDs = State(initialValue: HouseholdItemHuntCatalogStore.selectedIDsForEditing(from: initialMission))
        _customItems = State(initialValue: HouseholdItemHuntCatalogStore.customItems(from: initialMission))
    }

    private var allItems: [HouseholdItemHuntCatalogItem] {
        HouseholdItemHuntCatalogStore.builtInItems + customItems
    }

    private var visibleItems: [HouseholdItemHuntCatalogItem] {
        showSelectedOnly ? allItems.filter { selectedItemIDs.contains($0.id) } : allItems
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                        filterRow
                        selectionSummary
                        customActionsRow
                        itemGrid
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }

            footerButtons
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddCustomSheet) {
            addCustomItemSheet
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: initialMission.title,
                missionIcon: initialMission.iconName
            ) {
                launchMissionPreviewAfterAlarmPreview()
            }
        }
        .fullScreenCover(isPresented: $showMissionPreview) {
            if let previewMission {
                HouseholdItemHuntMissionView(
                    mission: previewMission,
                    onSuccess: {
                        showMissionPreview = false
                    }
                )
            } else {
                Colors.bgPrimary
                    .ignoresSafeArea()
                    .onAppear {
                        showMissionPreview = false
                    }
            }
        }
        .fullScreenCover(isPresented: $showCustomCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                addCustomObject(from: image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCustomPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                addCustomObject(from: image)
            }
            .ignoresSafeArea()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .selectionMissing:
                return Alert(
                    title: Text("Select at least one item"),
                    message: Text("Pick one or more household items before previewing or saving this mission."),
                    dismissButton: .default(Text("OK"))
                )
            case .customError(let message):
                return Alert(
                    title: Text("Could not add custom object"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .cameraPermissionNeeded:
                return Alert(
                    title: Text("Camera permission needed"),
                    message: Text("Allow camera access to add a custom object photo."),
                    primaryButton: .default(Text("Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Colors.cardSurface)
                    .overlay(
                        Circle().stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }

            Spacer()

            Text("Household Item Hunt")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Colors.cardSurface)
                    .overlay(
                        Circle().stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Colors.bgPrimary)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select Household Items")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Text("If one item is selected, that exact item is used. If multiple are selected, one is chosen randomly each mission.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 10) {
            filterPill("All Items", active: !showSelectedOnly) {
                showSelectedOnly = false
            }
            filterPill("Selected", active: showSelectedOnly) {
                showSelectedOnly = true
            }
        }
    }

    private func filterPill(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(active ? .white : Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? Colors.accentTeal : Colors.cardSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(active ? Colors.accentTeal : Colors.cardStroke, lineWidth: 1)
                )
        }
    }

    private var selectionSummary: some View {
        HStack {
            Text("\(selectedItemIDs.count) selected")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Button("Select All") {
                selectedItemIDs = Set(allItems.map(\.id))
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Colors.accentTeal)

            Text("•")
                .foregroundColor(Colors.textSecondary)

            Button("Clear") {
                selectedItemIDs.removeAll()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Colors.accentRed)
        }
    }

    private var customActionsRow: some View {
        HStack {
            Button(action: {
                draftCustomName = ""
                showAddCustomSheet = true
            }) {
                Label("Add Custom Object", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Colors.cardSurface)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
            }

            Spacer()

            if !customItems.isEmpty {
                Text("\(customItems.count) custom")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
        }
    }

    private var itemGrid: some View {
        Group {
            if visibleItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 26))
                        .foregroundColor(Colors.textSecondary)
                    Text("No selected items yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(visibleItems) { item in
                        itemCard(item)
                    }
                }
            }
        }
    }

    private func itemCard(_ item: HouseholdItemHuntCatalogItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)
        return Button {
            if isSelected {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Colors.accentTeal.opacity(0.22) : Colors.bgSecondary)
                            .frame(width: 56, height: 56)
                        Text(item.emoji)
                            .font(.system(size: 30))
                    }
                }

                Text(item.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Custom")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Colors.bgSecondary)
                    .cornerRadius(8)
                    .opacity(item.isCustom ? 1 : 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 148, maxHeight: 148, alignment: .center)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [Colors.accentTeal.opacity(0.18), Colors.cardSurface]
                        : [Colors.cardSurface, Colors.cardSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(18)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addCustomItemSheet: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Custom Object")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text("Name your object, then add a reference image to train this mission.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    TextField("Object name (e.g. Car Keys)", text: $draftCustomName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )

                    Button(action: { startCustomAddFlow(useCamera: true) }) {
                        Label("Take Reference Photo", systemImage: "camera.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.accentTeal)
                            .cornerRadius(14)
                    }

                    Button(action: { startCustomAddFlow(useCamera: false) }) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.cardSurface)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                            )
                    }

                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showAddCustomSheet = false
                    }
                    .foregroundColor(Colors.textPrimary)
                }
            }
        }
    }

    private var footerButtons: some View {
        VStack {
            Spacer()

            HStack(spacing: 16) {
                Button(action: startPreview) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Colors.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                        .cornerRadius(32)
                }

                Button(action: saveMission) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Colors.accentTeal,
                                    Colors.accentBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Colors.shadow.opacity(0.25), radius: 12, x: 0, y: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(y: -40)
                .allowsHitTesting(false)
            )
        }
    }

    private func startPreview() {
        guard !selectedItemIDs.isEmpty else {
            activeAlert = .selectionMissing
            return
        }
        previewMission = buildMissionForCurrentSelection()
        showAlarmPreview = true
    }

    private func launchMissionPreviewAfterAlarmPreview() {
        guard previewMission != nil else { return }
        showAlarmPreview = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if previewMission != nil {
                showMissionPreview = true
            }
        }
    }

    private func saveMission() {
        guard !selectedItemIDs.isEmpty else {
            activeAlert = .selectionMissing
            return
        }
        let config = HouseholdItemHuntMissionConfig(
            selectedItemIDs: Array(selectedItemIDs).sorted(),
            referenceImageFilename: initialMission.customData[HouseholdItemHuntCatalogStore.referenceImageFilenameKey],
            customItemsJSON: HouseholdItemHuntCatalogStore.serializedCustomItems(customItems)
        )
        onSave(config)
        dismiss()
    }

    private func buildMissionForCurrentSelection() -> AlarmMission {
        var updatedMission = AlarmMission(
            type: initialMission.type,
            difficulty: initialMission.difficulty,
            rounds: initialMission.rounds,
            config: initialMission.config,
            customData: initialMission.customData
        )
        updatedMission.customData[HouseholdItemHuntCatalogStore.selectedItemIDsKey] = HouseholdItemHuntCatalogStore.serializedIDs(selectedItemIDs)

        if let serialized = HouseholdItemHuntCatalogStore.serializedCustomItems(customItems), !serialized.isEmpty {
            updatedMission.customData[HouseholdItemHuntCatalogStore.customItemsKey] = serialized
        } else {
            updatedMission.customData.removeValue(forKey: HouseholdItemHuntCatalogStore.customItemsKey)
        }
        return updatedMission
    }

    private func startCustomAddFlow(useCamera: Bool) {
        let trimmedName = draftCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            activeAlert = .customError("Enter an object name before adding a photo.")
            return
        }

        pendingCustomName = trimmedName
        showAddCustomSheet = false

        if useCamera {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showCustomPhotoLibraryPicker = true
                }
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showCustomCameraPicker = true
                }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            showCustomCameraPicker = true
                        } else {
                            activeAlert = .cameraPermissionNeeded
                        }
                    }
                }
            case .denied, .restricted:
                activeAlert = .cameraPermissionNeeded
            @unknown default:
                activeAlert = .cameraPermissionNeeded
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showCustomPhotoLibraryPicker = true
            }
        }
    }

    private func addCustomObject(from image: UIImage?) {
        guard let image else { return }
        guard !pendingCustomName.isEmpty else {
            activeAlert = .customError("Object name is missing. Please try adding it again.")
            return
        }

        do {
            let filename = try HouseholdItemHuntImageStore.saveReferenceImage(image)
            let newItem = HouseholdItemHuntCatalogStore.makeCustomItem(
                name: pendingCustomName,
                referenceImageFilename: filename,
                existingCustomItems: customItems
            )
            customItems.append(newItem)
            selectedItemIDs.insert(newItem.id)
            pendingCustomName = ""
            draftCustomName = ""
        } catch {
            activeAlert = .customError(error.localizedDescription)
        }
    }
}

private enum ActiveAlert: Identifiable {
    case selectionMissing
    case customError(String)
    case cameraPermissionNeeded

    var id: String {
        switch self {
        case .selectionMissing:
            return "selectionMissing"
        case .customError(let message):
            return "customError:\(message)"
        case .cameraPermissionNeeded:
            return "cameraPermissionNeeded"
        }
    }
}
