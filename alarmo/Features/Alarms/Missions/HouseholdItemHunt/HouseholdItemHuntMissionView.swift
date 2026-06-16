import SwiftUI
import AVFoundation

struct HouseholdItemHuntMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let mission: AlarmMission
    var onSuccess: (() -> Void)?

    @State private var targetItem: HouseholdItemHuntCatalogItem?
    @State private var legacyReferenceImage: UIImage?
    @State private var capturedImage: UIImage?
    @State private var selectionPool: [HouseholdItemHuntCatalogItem] = []
    @State private var spinDisplayItem: HouseholdItemHuntCatalogItem?
    @State private var spinIndex: Int = 0
    @State private var isChoosingTarget = false
    @State private var spinTask: Task<Void, Never>?
    @State private var spinAngle: Double = 0

    @State private var isEvaluating = false
    @State private var feedbackMessage: String?
    @State private var feedbackColor: Color = Colors.textSecondary
    @State private var similarityPercent: Int?

    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showPermissionAlert = false
    @State private var showConfigurationAlert = false

    @State private var showSuccessCelebration = false
    @State private var didComplete = false

    private var isLegacyReferenceMode: Bool {
        targetItem == nil && legacyReferenceImage != nil
    }

    private var targetName: String {
        targetItem?.name ?? "Saved Item"
    }

    private var canCapture: Bool {
        !isEvaluating && !isChoosingTarget && (isLegacyReferenceMode || targetItem != nil)
    }

    private var canRerunTarget: Bool {
        selectionPool.count > 1 &&
        !isLegacyReferenceMode &&
        !isChoosingTarget &&
        !isEvaluating &&
        !didComplete
    }

    private var rouletteItems: [HouseholdItemHuntCatalogItem] {
        guard !selectionPool.isEmpty else { return [] }
        let count = selectionPool.count
        let center = ((spinIndex % count) + count) % count
        return [-1, 0, 1].map { offset in
            selectionPool[(center + offset + count) % count]
        }
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text(isLegacyReferenceMode ? "Find the saved reference item and capture it." : (isChoosingTarget ? "Selecting a random item from your list..." : "Find and capture this item."))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 14)
                            .padding(.horizontal, 24)

                        targetCard
                            .frame(maxWidth: isChoosingTarget ? 281 : 244)
                            .padding(.top, -4)

                        if !isLegacyReferenceMode, let targetItem {
                            HStack(spacing: 10) {
                                Text(targetItem.emoji)
                                    .font(.system(size: 28))
                                Text(targetItem.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                            }

                            if canRerunTarget {
                                Button(action: rerunTargetSelection) {
                                    Label("Rerun", systemImage: "shuffle")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Colors.cardSurface)
                                        .overlay(
                                            Capsule()
                                                .stroke(Colors.cardStroke, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, -6)
                            }
                        }

                        if let similarityPercent, isLegacyReferenceMode {
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
                            ProgressView("Analyzing photo...")
                                .progressViewStyle(.circular)
                                .tint(Colors.accentTeal)
                                .foregroundColor(Colors.textPrimary)
                        }

                        captureButton
                            .padding(.top, 4)
                            .offset(y: -28)
                            .padding(.bottom, -28)

                        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showPhotoLibraryPicker = true
                            } label: {
                                Text("Choose from Library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(MissionTheme.secondaryButtonText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MissionTheme.secondaryButtonFill)
                                    .cornerRadius(20)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }

            if showSuccessCelebration {
                successCelebrationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear(perform: configureMission)
        .onDisappear {
            spinTask?.cancel()
            spinTask = nil
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
        .alert("Mission not configured", isPresented: $showConfigurationAlert) {
            Button("Close") {
                dismiss()
            }
        } message: {
            Text("No hunt item is configured. Edit this mission and select at least one item.")
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Text("Household Hunt")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Colors.cardSurface)
                    .overlay(
                        Circle().stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var targetCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Colors.cardSurface)
                .aspectRatio(0.86, contentMode: .fit)

            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: isEvaluating ? 6 : 3)
                    .overlay(MissionTheme.isTiimo ? Color.black.opacity(0.12) : Color.black.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(8)
            } else if isChoosingTarget, let spinDisplayItem {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ForEach(Array(rouletteItems.enumerated()), id: \.offset) { index, item in
                            let isCenter = index == 1
                            VStack(spacing: 6) {
                                Text(item.emoji)
                                    .font(.system(size: isCenter ? 67 : 41))
                                    .rotationEffect(.degrees(isCenter ? spinAngle : 0))
                                    .animation(.easeInOut(duration: 0.12), value: spinAngle)
                                if isCenter {
                                    Text(item.name)
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(Colors.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isCenter ? 8 : 0)
                            .opacity(isCenter ? 1 : 0.45)
                        }
                    }
                    .padding(.horizontal, 8)

                    if rouletteItems.isEmpty {
                        Text(spinDisplayItem.name)
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(Colors.textPrimary)
                    }

                    Text("Rolling through selected items...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.horizontal, 18)
            } else if let targetItem {
                VStack(spacing: 14) {
                    Text(targetItem.emoji)
                        .font(.system(size: 68))
                    Text(targetItem.name)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Colors.textPrimary)
                    Text("Take a photo of this item")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.horizontal, 18)
            } else if let legacyReferenceImage {
                Image(uiImage: legacyReferenceImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 42))
                        .foregroundColor(Colors.textSecondary)
                    Text("Loading target...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
            }

            if let overlay = overlayMessage {
                Text(overlay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MissionTheme.isTiimo ? Colors.textPrimary : Color.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
                .padding(.horizontal, 16)
        )
    }

    private var successCelebrationOverlay: some View {
        ZStack {
            MissionTheme.successScrim.ignoresSafeArea()
            MissionEmojiConfettiBackground()

            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 86, weight: .bold))
                    .foregroundColor(Colors.accentGreen)
                Text("Mission complete")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Colors.textPrimary)
            }
            .padding(.horizontal, 20)
        }
        .allowsHitTesting(false)
    }

    private var overlayMessage: String? {
        if isEvaluating {
            return "Analyzing \(targetName)..."
        }
        if isChoosingTarget {
            return "Choosing target..."
        }
        if let feedbackMessage, !feedbackMessage.isEmpty {
            return feedbackMessage
        }
        return nil
    }

    private var captureButton: some View {
        Button(action: handleCaptureTapped) {
            ZStack {
                Circle()
                    .fill(Colors.cardSurface)
                    .frame(width: 94, height: 94)
                    .overlay(
                        Circle()
                            .stroke(Colors.cardStroke, lineWidth: 2)
                    )

                Circle()
                    .stroke(Colors.textPrimary.opacity(0.65), lineWidth: 2)
                    .frame(width: 74, height: 74)

                Image(systemName: "camera.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canCapture)
    }

    private func configureMission() {
        let selectedItems = HouseholdItemHuntCatalogStore.selectedItems(for: mission)
        if !selectedItems.isEmpty {
            selectionPool = selectedItems
            if selectedItems.count == 1 {
                targetItem = selectedItems[0]
                spinDisplayItem = selectedItems[0]
                isChoosingTarget = false
            } else {
                beginTargetSpin(with: selectedItems)
            }
            return
        }

        guard let legacyFilename = mission.customData[HouseholdItemHuntCatalogStore.referenceImageFilenameKey], !legacyFilename.isEmpty else {
            showConfigurationAlert = true
            return
        }

        legacyReferenceImage = HouseholdItemHuntImageStore.loadReferenceImage(filename: legacyFilename)
        showConfigurationAlert = legacyReferenceImage == nil
    }

    private func beginTargetSpin(with items: [HouseholdItemHuntCatalogItem], avoidingID: String? = nil) {
        guard !items.isEmpty else { return }
        spinTask?.cancel()
        isChoosingTarget = true
        targetItem = nil
        capturedImage = nil
        feedbackMessage = nil
        similarityPercent = nil
        spinDisplayItem = items.first
        spinIndex = 0
        spinAngle = 0

        spinTask = Task {
            let totalTicks = min(42, max(20, items.count * 3))
            let totalDuration = min(2.85, max(1.55, 1.05 + (Double(items.count) * 0.07)))
            var index = 0
            var previousTime: Double = 0
            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                let item = items[index % items.count]
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        spinDisplayItem = item
                        spinIndex = index % items.count
                        spinAngle += 120
                    }
                }
                index += 1
                let progress = Double(tick + 1) / Double(totalTicks)
                let easedTime = totalDuration * pow(progress, 1.32)
                let delay = max(0.02, easedTime - previousTime)
                previousTime = easedTime
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }
            let candidates: [HouseholdItemHuntCatalogItem]
            if let avoidingID {
                let filtered = items.filter { $0.id != avoidingID }
                candidates = filtered.isEmpty ? items : filtered
            } else {
                candidates = items
            }

            let chosen = candidates.randomElement() ?? candidates[0]
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    targetItem = chosen
                    spinDisplayItem = chosen
                    isChoosingTarget = false
                }
            }
        }
    }

    private func rerunTargetSelection() {
        guard canRerunTarget else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        beginTargetSpin(with: selectionPool, avoidingID: targetItem?.id)
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
        capturedImage = candidate
        feedbackMessage = nil
        similarityPercent = nil
        isEvaluating = true

        if let targetItem {
            if let customReferenceFilename = targetItem.referenceImageFilename,
               let customReferenceImage = HouseholdItemHuntImageStore.loadReferenceImage(filename: customReferenceFilename) {
                evaluateAgainstReference(referenceImage: customReferenceImage, targetName: targetItem.name)
                return
            }

            Task {
                let labels = await ObjectHuntMatcher.classify(image: candidate)
                let matched = HouseholdItemHuntCatalogStore.matches(item: targetItem, labels: labels)

                await MainActor.run {
                    isEvaluating = false

                    if matched {
                        feedbackColor = Colors.accentGreen
                        feedbackMessage = "Matched \(targetItem.name). Mission complete."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        completeMissionIfNeeded()
                    } else {
                        let detected = HouseholdItemHuntCatalogStore.primaryDetectedLabel(from: labels) ?? "something else"
                        let detectedPhrase = HouseholdItemHuntCatalogStore.articlePhrase(for: detected)
                        let targetPhrase = HouseholdItemHuntCatalogStore.articlePhrase(for: targetItem.name.lowercased())
                        feedbackColor = Colors.accentRed
                        feedbackMessage = "That's \(detectedPhrase), not \(targetPhrase)."
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
            return
        }

        guard let legacyReferenceImage else {
            isEvaluating = false
            showConfigurationAlert = true
            return
        }

        Task {
            do {
                let result = try await HouseholdItemHuntMatcher.shared.evaluate(reference: legacyReferenceImage, candidate: candidate)
                await MainActor.run {
                    isEvaluating = false
                    similarityPercent = result.similarityPercent

                    if result.isMatch {
                        feedbackColor = Colors.accentGreen
                        feedbackMessage = "Perfect match. Mission complete."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        completeMissionIfNeeded()
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

    private func evaluateAgainstReference(referenceImage: UIImage, targetName: String) {
        guard let candidate = capturedImage else {
            isEvaluating = false
            return
        }

        Task {
            do {
                let result = try await HouseholdItemHuntMatcher.shared.evaluate(reference: referenceImage, candidate: candidate)
                await MainActor.run {
                    isEvaluating = false
                    similarityPercent = result.similarityPercent

                    if result.isMatch {
                        feedbackColor = Colors.accentGreen
                        feedbackMessage = "Matched \(targetName). Mission complete."
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        completeMissionIfNeeded()
                    } else {
                        feedbackColor = Colors.accentRed
                        feedbackMessage = "That does not match \(HouseholdItemHuntCatalogStore.articlePhrase(for: targetName.lowercased())). Try again."
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

    private func completeMissionIfNeeded() {
        guard !didComplete else { return }
        didComplete = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            showSuccessCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onSuccess?()
            dismiss()
        }
    }
}
