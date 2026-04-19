import SwiftUI
import Combine

struct PushupsMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = MissionCameraSession()

    var onComplete: (() -> Void)?

    @State private var state: MissionState = .ready
    @State private var remainingSeconds: Int = 15
    @State private var reps: Int = 0
    @State private var downPhase = false
    @State private var baselineMetric: CGFloat?
    @State private var lastMetric: CGFloat?
    @State private var humanFrames: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum MissionState {
        case ready
        case recording
        case success
        case failed
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black)

                    MissionCameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                    VStack(spacing: 8) {
                        Text(state == .recording ? "RECORDING" : "PUSH-UPS")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))

                        countdownRing

                        Text("\(remainingSeconds)s")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Reps: \(reps)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 520)
                .padding(.horizontal, 18)

                statusBanner
                    .padding(.horizontal, 18)

                actionButton
                    .padding(.horizontal, 18)

                Spacer(minLength: 12)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onReceive(timer) { _ in
            guard state == .recording else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
            if remainingSeconds <= 0 {
                finishAttempt()
            }
        }
        .onChange(of: camera.poseMetrics) { _, pose in
            guard state == .recording, let pose else { return }
            processPose(pose)
        }
        .alert("Camera permission needed", isPresented: $camera.permissionDenied) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow camera access to record push-ups.")
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Push-ups")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.24), lineWidth: 10)
                .frame(width: 86, height: 86)
            Circle()
                .trim(from: 0, to: CGFloat(remainingSeconds) / 15.0)
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.95), Color.red.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 86, height: 86)
        }
    }

    private var statusBanner: some View {
        let text: String
        let tone: Color
        switch state {
        case .ready:
            text = "Record for 15s. Human push-up motion is required."
            tone = Colors.textSecondary
        case .recording:
            text = "Move down and up. Minimum 4 reps in 15s."
            tone = Colors.accentTeal
        case .success:
            text = "Great set. Mission completed."
            tone = .green
        case .failed:
            text = "Not enough valid movement detected. Try again."
            tone = Colors.accentRed
        }

        return Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(tone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Colors.cardStroke, lineWidth: 1))
    }

    private var actionButton: some View {
        Button(action: buttonTapped) {
            Text(buttonTitle)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private var buttonTitle: String {
        switch state {
        case .ready: return "Start Recording"
        case .recording: return "Stop"
        case .success: return "Done"
        case .failed: return "Retry"
        }
    }

    private func buttonTapped() {
        switch state {
        case .ready:
            startAttempt()
        case .recording:
            finishAttempt()
        case .success:
            onComplete?()
            dismiss()
        case .failed:
            startAttempt()
        }
    }

    private func startAttempt() {
        state = .recording
        remainingSeconds = 15
        reps = 0
        downPhase = false
        baselineMetric = nil
        lastMetric = nil
        humanFrames = 0
    }

    private func finishAttempt() {
        guard state == .recording else { return }

        let enoughHumanFrames = humanFrames >= 5
        let enoughReps = reps >= 4
        if enoughHumanFrames && enoughReps {
            state = .success
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onComplete?()
                dismiss()
            }
        } else {
            state = .failed
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func processPose(_ pose: PoseMetrics) {
        guard pose.confidence > 0.2 else { return }
        humanFrames += 1

        let torso = max(abs(pose.shoulderY - pose.hipY), 0.05)
        let movementMetric = (pose.shoulderY - pose.wristY) / torso

        if baselineMetric == nil {
            baselineMetric = movementMetric
            lastMetric = movementMetric
            return
        }

        guard let base = baselineMetric else { return }
        baselineMetric = (base * 0.92) + (movementMetric * 0.08)
        let dynamicBase = baselineMetric ?? movementMetric

        let lower = dynamicBase - 0.25
        let upper = dynamicBase + 0.22

        if !downPhase && movementMetric < lower {
            downPhase = true
        } else if downPhase && movementMetric > upper {
            downPhase = false
            reps += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        lastMetric = movementMetric
    }
}
