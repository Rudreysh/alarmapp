import SwiftUI
import AVFoundation

private enum CameraPermissionStepState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

struct OnboardingCameraAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var isRequesting = false
    @State private var showCameraPrompt = false
    @State private var showCameraDeniedAlert = false
    @State private var permissionState: CameraPermissionStepState = .notDetermined
    @State private var animateIn = false

    
    private var isTiimoTheme: Bool {
        AlarmThemeStyle.persisted.usesTiimoLayoutBranch
    }
var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 7, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                Spacer()

                VStack(alignment: .center, spacing: 14) {
                    PermissionHeroIcon(
                        systemName: "camera.circle.fill",
                        tint: Colors.accentTeal
                    )
                        .padding(.bottom, 10)

                    Text("Permission to Access Camera")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Camera access is needed for QR, barcode, and object-based wake-up missions. You can still continue without it and enable later in Settings.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .center)
                .permissionEntrance(animateIn)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onNext) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.cardSurface)
                            .cornerRadius(32)
                    }
                    .disabled(isRequesting)

                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        Task { @MainActor in
                            await handleContinueTapped()
                        }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 24)
            }
             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onboardingContentFrame()

            if showCameraPrompt {
                cameraPromptOverlay
                    .zIndex(1)
            }

            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                PermissionAnimatedLoadingCard(title: "Requesting Camera Access")
                .zIndex(3)
            }
        }
        .task {
            refreshPermissionState()
            animateIn = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshPermissionState()
        }
        .alert("Camera Access Needed", isPresented: $showCameraDeniedAlert) {
            Button("Continue", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text("Camera access is currently disabled. Enable camera in Settings to use scanning and camera-based wake-up missions.")
        }
    }

    private var cameraPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("\"Alarmo\" would like to access your Camera.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Text("Camera access helps Alarmo run QR/barcode and object-hunt missions reliably when alarms ring.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    Button {
                        showCameraPrompt = false
                        onNext()
                    } label: {
                        Text("Don't Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Button {
                        showCameraPrompt = false
                        Task { @MainActor in
                            await requestCameraFromPrompt()
                        }
                    } label: {
                        Text("Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.accentBlue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }

    @MainActor
    private func handleContinueTapped() async {
        switch permissionState {
        case .authorized:
            onNext()
        case .denied, .restricted:
            showCameraDeniedAlert = true
        case .notDetermined:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCameraPrompt = true
            }
        }
    }

    @MainActor
    private func requestCameraFromPrompt() async {
        isRequesting = true
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { allowed in
                continuation.resume(returning: allowed)
            }
        }
        isRequesting = false
        refreshPermissionState()

        if granted || permissionState == .authorized {
            onNext()
        } else {
            showCameraDeniedAlert = true
        }
    }

    private func refreshPermissionState() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        case .notDetermined:
            permissionState = .notDetermined
        @unknown default:
            permissionState = .notDetermined
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
