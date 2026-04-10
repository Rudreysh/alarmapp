import SwiftUI
import AVFoundation

struct HouseholdItemHuntMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let referenceImageFilename: String
    var onSuccess: (() -> Void)?

    @State private var referenceImage: UIImage?
    @State private var isEvaluating = false
    @State private var feedbackMessage: String?
    @State private var feedbackColor: Color = Colors.textSecondary
    @State private var similarityPercent: Int?

    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showPermissionAlert = false
    @State private var showReferenceMissingAlert = false

    @State private var didComplete = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("Find the same household item and take a photo.")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                            .padding(.horizontal, 24)

                        referenceCard

                        if let similarityPercent {
                            Text("Similarity: \(similarityPercent)%")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }

                        if let feedbackMessage {
                            Text(feedbackMessage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(feedbackColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }

                        if isEvaluating {
                            ProgressView("Comparing images...")
                                .progressViewStyle(.circular)
                                .tint(Colors.accentTeal)
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 12) {
                            Button {
                                handleCaptureTapped()
                            } label: {
                                Text("Take Photo")
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
                            .disabled(isEvaluating || referenceImage == nil)

                            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Text("Choose from Library")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            referenceImage = HouseholdItemHuntImageStore.loadReferenceImage(filename: referenceImageFilename)
            showReferenceMissingAlert = referenceImage == nil
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                guard let image else { return }
                evaluate(candidate: image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                guard let image else { return }
                evaluate(candidate: image)
            }
            .ignoresSafeArea()
        }
        .alert("Camera permission needed", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Enable camera access to complete Household Item Hunt.")
        }
        .alert("Mission not configured", isPresented: $showReferenceMissingAlert) {
            Button("Close") {
                dismiss()
            }
        } message: {
            Text("Reference image is missing. Please edit this alarm mission and save a new item photo.")
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Household Item Hunt")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var referenceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Colors.cardSurface)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.2, contentMode: .fit)

            if let referenceImage {
                Image(uiImage: referenceImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 42))
                        .foregroundColor(Colors.textSecondary)
                    Text("Reference photo unavailable")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
                .padding(.horizontal, 20)
        )
    }

    private func handleCaptureTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showPhotoLibraryPicker = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraPicker = true
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            showPermissionAlert = true
        }
    }

    private func evaluate(candidate: UIImage) {
        guard let referenceImage else {
            showReferenceMissingAlert = true
            return
        }

        feedbackMessage = nil
        similarityPercent = nil
        isEvaluating = true

        Task {
            do {
                let result = try await HouseholdItemHuntMatcher.shared.evaluate(reference: referenceImage, candidate: candidate)
                await MainActor.run {
                    isEvaluating = false
                    similarityPercent = result.similarityPercent

                    if result.isMatch {
                        feedbackColor = .green
                        feedbackMessage = "Perfect match. Mission complete."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)

                        guard !didComplete else { return }
                        didComplete = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            onSuccess?()
                            dismiss()
                        }
                    } else {
                        feedbackColor = Colors.accentRed
                        feedbackMessage = "Not close enough. Try again with the same item in frame."
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            } catch {
                await MainActor.run {
                    isEvaluating = false
                    feedbackColor = Colors.accentRed
                    feedbackMessage = error.localizedDescription
                }
            }
        }
    }
}
