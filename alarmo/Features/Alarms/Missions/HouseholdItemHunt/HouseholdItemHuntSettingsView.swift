import SwiftUI
import PhotosUI

struct HouseholdItemHuntSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var referenceImage: UIImage?
    @State private var referenceFilename: String?

    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showAlarmPreview = false
    @State private var showMissionPreview = false

    @State private var showMissingReferenceAlert = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""

    let initialFilename: String?
    let onSave: (HouseholdItemHuntMissionConfig) -> Void

    init(initialFilename: String? = nil, onSave: @escaping (HouseholdItemHuntMissionConfig) -> Void) {
        self.initialFilename = initialFilename
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        instructionCard
                        referencePreviewCard
                        pickerButtons
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }

            footerButtons
        }
        .navigationBarHidden(true)
        .onAppear {
            if let initialFilename, !initialFilename.isEmpty {
                referenceFilename = initialFilename
                referenceImage = HouseholdItemHuntImageStore.loadReferenceImage(filename: initialFilename)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        persistReferenceImage(image)
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                guard let image else { return }
                persistReferenceImage(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                guard let image else { return }
                persistReferenceImage(image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "Household Item Hunt",
                missionIcon: "camera.macro"
            ) {
                showAlarmPreview = false
                showMissionPreview = true
            }
        }
        .fullScreenCover(isPresented: $showMissionPreview) {
            HouseholdItemHuntMissionView(
                referenceImageFilename: referenceFilename ?? "",
                onSuccess: {
                    showMissionPreview = false
                }
            )
        }
        .alert("Reference image needed", isPresented: $showMissingReferenceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please save a household item photo first.")
        }
        .alert("Could not save image", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("Household Item Hunt")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Colors.bgPrimary)
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text("1. Save a photo of any household item.\n2. When alarm rings, take a matching photo.\n3. Mission completes only if the image matches.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private var referencePreviewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Colors.cardSurface)
                .aspectRatio(1.25, contentMode: .fit)

            if let referenceImage {
                Image(uiImage: referenceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 44))
                        .foregroundColor(Colors.textSecondary)
                    Text("No reference photo yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private var pickerButtons: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Photos")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12))
                .cornerRadius(14)
            }

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCameraPicker = true
                } else {
                    showPhotoLibraryPicker = true
                }
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(UIImagePickerController.isSourceTypeAvailable(.camera) ? "Take reference photo" : "Choose image (camera unavailable)")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Colors.cardSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
            }
        }
    }

    private var footerButtons: some View {
        VStack {
            Spacer()

            HStack(spacing: 16) {
                Button {
                    guard referenceFilename != nil else {
                        showMissingReferenceAlert = true
                        return
                    }
                    showAlarmPreview = true
                } label: {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(32)
                }

                Button {
                    guard let referenceFilename else {
                        showMissingReferenceAlert = true
                        return
                    }
                    onSave(HouseholdItemHuntMissionConfig(referenceImageFilename: referenceFilename))
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.78, blue: 0.92),
                                    Color(red: 0.05, green: 0.66, blue: 0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3), radius: 15, x: 0, y: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func persistReferenceImage(_ image: UIImage) {
        do {
            let filename = try HouseholdItemHuntImageStore.saveReferenceImage(image, replacing: referenceFilename)
            referenceFilename = filename
            referenceImage = HouseholdItemHuntImageStore.loadReferenceImage(filename: filename) ?? image
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveErrorAlert = true
        }
    }
}
