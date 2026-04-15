import SwiftUI
import AVFoundation
import UIKit

// MARK: - Session Intervention View
/// Shown when the user tries to stop/take a break during a blocked focus session.
/// Mirrors the Opal "Don't give up so easily" flow.
struct SessionInterventionView: View {
    let breakMode: SessionBreakMode
    let enabledChallenges: [UnblockChallenge]
    
    /// Called after a challenge is completed — app shields are cleared by caller.
    let onStopConfirmed: () -> Void
    /// Called to take a timed break (unblocks for break duration, then re-blocks).
    let onTakeBreak: () -> Void
    /// Called when user taps "Nevermind" — stays in session.
    let onDismiss: () -> Void
    
    @State private var activeMission: UnblockChallenge? = nil
    @State private var showingMission: Bool = false
    
    // Mocked blocked app icons
    private let blockedAppEmojis: [(String, String)] = [
        ("🎬", "YouTube"), ("📸", "Instagram"), ("🐦", "X"),
        ("💬", "WhatsApp"), ("🎵", "TikTok"), ("🧭", "Safari"),
        ("📺", "Netflix"), ("🎮", "Roblox"), ("💬", "Slack"),
        ("🍬", "Candy Crush"), ("📒", "Notion"), ("💬", "Messages")
    ]
    
    var body: some View {
        ZStack {
            ZStack {
                TimerGlassBackground()
                Color.black.opacity(0.30)
            }
            .ignoresSafeArea()
            
            Group {
                if showingMission, let mission = activeMission {
                    missionView(for: mission)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    interventionHome
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showingMission)
        }
    }
    
    // MARK: - Intervention Home Screen
    private var interventionHome: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Floating app icons — centered block above the title
            floatingAppIcons
                .frame(height: 320)
                .padding(.bottom, 8)
            
            // Title
            VStack(spacing: 10) {
                Text("Don't give up so easily")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your apps are blocked. Complete a challenge\nto take a break or stop.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Break button (only shown if not hardcore)
                if breakMode != .hardcore {
                    challengeButton(
                        title: "Take a Break",
                        subtitle: breakMode == .harder ? "Complete a mission to unlock temporarily" : "Pause blocking for 15 minutes",
                        icon: "pause.fill",
                        gradient: LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.white.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        textColor: .black.opacity(0.8)
                    ) {
                        if breakMode == .harder {
                            launchChallenge(for: .onBreak)
                        } else {
                            onTakeBreak()
                        }
                    }
                }
                
                // Stop session
                challengeButton(
                    title: "Stop Session",
                    subtitle: enabledChallenges.isEmpty ? "This will unblock your apps" : "Complete a mission to stop",
                    icon: "lock.open.fill",
                    gradient: LinearGradient(
                        colors: [TimerPalette.accentSoft.opacity(0.9), TimerPalette.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    textColor: .white
                ) {
                    if enabledChallenges.isEmpty {
                        onStopConfirmed()
                    } else {
                        launchChallenge(for: .onStop)
                    }
                }
                
                // Stay in session
                Button(action: { onDismiss() }) {
                    Text("Stay in Session")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Mission View Router
    @ViewBuilder
    private func missionView(for challenge: UnblockChallenge) -> some View {
        Group {
            switch challenge {
            case .qrBarcode:
                QRBarcodeMissionView(
                    targetCode: "PREVIEW_DUMMY_MODE",
                    onSuccess: { handleMissionSuccess() }
                )
            case .typing:
                let settings = focusTypingSettings()
                TypingMissionGameplayView(
                    viewModel: TypingGameplayViewModel(
                        settings: settings,
                        phrases: focusTypingPhrases(settings: settings),
                        isPreviewMode: false,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .math:
                MathMissionPlayView(
                    viewModel: MathMissionViewModel(
                        config: MathMissionConfig(difficulty: .normal, repeatCount: 3),
                        isPreviewMode: false,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .findColorTiles:
                FindColorTilesMissionView(
                    viewModel: FindColorTilesViewModel(
                        settings: FindColorTilesSettings(difficulty: .normal, rounds: 3, soundEnabled: false),
                        isPreviewMode: false,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .shake:
                ShakeMissionView(
                    viewModel: ShakeMissionViewModel(
                        targetShakes: 30,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .step:
                StepsMissionView(
                    viewModel: StepsMissionViewModel(
                        targetSteps: 20,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .squat:
                SquatMissionView(
                    viewModel: SquatMissionViewModel(
                        targetSquats: 10,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .memoryMatch:
                MemoryMatchGameView(
                    viewModel: MemoryMatchViewModel(
                        difficulty: .fourByFour,
                        rounds: 1,
                        isPreviewMode: false,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .ticTacToe:
                TicTacToeGameView(
                    viewModel: TicTacToeViewModel(
                        rounds: 1,
                        isPreviewMode: false,
                        onComplete: { handleMissionSuccess() }
                    )
                )
            case .breathing:
                BreathingExerciseView {
                    handleMissionSuccess()
                } onCancel: {
                    showingMission = false
                }
            case .householdItemHunt:
                FocusHouseholdItemHuntMissionView(
                    onComplete: { handleMissionSuccess() },
                    onCancel: { showingMission = false }
                )
            case .off:
                Color.clear
                    .onAppear {
                        handleMissionSuccess()
                    }
            }
        }
        // Native Cancel button overlaid so user can back out of the mission
        .overlay(alignment: .topLeading) {
            Button(action: { showingMission = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    private func handleMissionSuccess() {
        showingMission = false
        handleChallengeComplete()
    }
    
    // MARK: - State
    
    private enum IntentKind { case onBreak, onStop }
    @State private var currentIntent: IntentKind = .onStop
    @State private var challengeRotationIndex: Int = 0
    
    private func launchChallenge(for intent: IntentKind) {
        currentIntent = intent
        let available = enabledChallenges.filter { $0 != .off }
        guard !available.isEmpty else {
            // No challenges — proceed directly
            handleChallengeComplete()
            return
        }

        let index = challengeRotationIndex % available.count
        activeMission = available[index]
        challengeRotationIndex = (challengeRotationIndex + 1) % max(available.count, 1)
        showingMission = true
    }
    
    private func handleChallengeComplete() {
        switch currentIntent {
        case .onBreak:
            onTakeBreak()
        case .onStop:
            onStopConfirmed()
        }
    }

    // MARK: - Mission Data
    private func focusTypingSettings() -> TypingSettings {
        var settings = TypingMissionStore.shared.loadSettings(for: "default")
        settings.repeatCount = 1
        return settings
    }

    private func focusTypingPhrases(settings: TypingSettings) -> [Phrase] {
        let selected = TypingMissionStore.shared.allPhrases
            .filter { settings.selectedPhraseIDs.contains($0.id) }
        return selected.isEmpty ? TypingSettings.defaultPhrases : selected
    }
    
    // MARK: - Floating App Icons
    private var floatingAppIcons: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            ZStack {
                ForEach(Array(blockedAppEmojis.prefix(10).enumerated()), id: \.offset) { index, item in
                    FloatingAppIcon(
                        emoji: item.0,
                        name: item.1,
                        index: index,
                        totalCount: 10,
                        centerX: cx,
                        centerY: cy
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    // MARK: - Challenge Button
    private func challengeButton(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient,
        textColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Stylish circular icon container
                ZStack {
                    Circle()
                        .fill(textColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(textColor)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.65))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}

private struct FocusHouseholdItemHuntMissionView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var referenceImage: UIImage?
    @State private var isCapturingReference = false
    @State private var showImagePicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .camera
    @State private var showPermissionAlert = false
    @State private var isEvaluating = false
    @State private var feedbackMessage: String?
    @State private var feedbackColor: Color = Colors.textSecondary
    @State private var similarityPercent: Int?

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Household Item Hunt")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 52)

                Text("Set a target item first, then take another photo of the same item to unlock.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 250)

                    if let image = referenceImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.macro")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                            Text("No target item yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                if let similarityPercent {
                    Text("Similarity: \(similarityPercent)%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(feedbackColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if isEvaluating {
                    ProgressView("Comparing images...")
                        .tint(Colors.accentTeal)
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    Button(action: { startCapture(referenceMode: true) }) {
                        Text(referenceImage == nil ? "Set Target Item" : "Reset Target Item")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    .disabled(isEvaluating)

                    Button(action: { startCapture(referenceMode: false) }) {
                        Text("Match Item to Unlock")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [TimerPalette.accentSoft, TimerPalette.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(referenceImage == nil || isEvaluating)
                }
                .padding(.horizontal, 24)

                Button("Cancel") { onCancel() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.top, 4)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(sourceType: pickerSource) { image in
                guard let image else { return }
                handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .alert("Camera permission needed", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text("Enable camera access to complete Household Item Hunt.")
        }
    }

    private func startCapture(referenceMode: Bool) {
        isCapturingReference = referenceMode
        similarityPercent = nil
        feedbackMessage = nil
        feedbackColor = Colors.textSecondary

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                pickerSource = .camera
                showImagePicker = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            pickerSource = .camera
                            showImagePicker = true
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
        } else {
            pickerSource = .photoLibrary
            showImagePicker = true
        }
    }

    private func handleCapturedImage(_ image: UIImage) {
        if isCapturingReference {
            referenceImage = image
            feedbackMessage = "Target item saved. Now capture the same item to unlock."
            feedbackColor = .green
            return
        }

        guard let referenceImage else {
            feedbackMessage = "Set a target item first."
            feedbackColor = Colors.accentRed
            return
        }

        isEvaluating = true
        Task {
            do {
                let result = try await HouseholdItemHuntMatcher.shared.evaluate(
                    reference: referenceImage,
                    candidate: image
                )
                await MainActor.run {
                    isEvaluating = false
                    similarityPercent = result.similarityPercent
                    if result.isMatch {
                        feedbackMessage = "Match found. Mission complete."
                        feedbackColor = .green
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onComplete()
                    } else {
                        feedbackMessage = "Not close enough. Try capturing the same item again."
                        feedbackColor = Colors.accentRed
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            } catch {
                await MainActor.run {
                    isEvaluating = false
                    feedbackMessage = error.localizedDescription
                    feedbackColor = Colors.accentRed
                }
            }
        }
    }
}

// MARK: - Floating App Icon (animated orbiting icon)

struct FloatingAppIcon: View {
    let emoji: String
    let name: String
    let index: Int
    let totalCount: Int
    let centerX: CGFloat
    let centerY: CGFloat
    
    @State private var posX: CGFloat = 0
    @State private var posY: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var floatTimer: Timer? = nil
    
    // Spread icons in a fan: front-facing ellipse centered in the view
    private var baseAngle: Double {
        (Double(index) / Double(totalCount)) * 360.0
    }
    
    // Compact radii so all icons sit in the frame
    private var baseRadius: CGFloat {
        // Wider spread: alternating sizes for a layered circle effect
        let radii: [CGFloat] = [80, 105, 85, 110, 90, 100, 82, 108, 88, 98]
        return radii[index % radii.count]
    }
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 36))
            .frame(width: 58, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            // position() places anchor point at the given coordinate within the parent
            .position(x: posX, y: posY)
            .onAppear {
                // Start at correct position before timer fires
                let angle = baseAngle * .pi / 180
                posX = centerX + cos(angle) * baseRadius
                posY = centerY + sin(angle) * baseRadius * 0.95 // Almost circular orbit
                startAnimation()
            }
            .onDisappear { floatTimer?.invalidate() }
    }
    
    private func startAnimation() {
        floatTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let speed = 0.003 + Double(index % 3) * 0.001
                rotation += speed
                let phase = rotation
                let angleRad = (baseAngle * .pi / 180) + phase
                let wobble = sin(phase * 2 + Double(index)) * 8
                let r = baseRadius + wobble
                posX = centerX + cos(angleRad) * r
                posY = centerY + sin(angleRad) * r * 0.95   // squish Y slightly for perspective
            }
        }
    }
}
