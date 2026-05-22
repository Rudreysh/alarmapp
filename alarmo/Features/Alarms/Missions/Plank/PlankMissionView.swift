import SwiftUI
import Combine

struct PlankMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = MissionCameraSession()

    var onComplete: (() -> Void)?

    @State private var active = false
    @State private var holdRemaining: Int = 15
    @State private var stabilityScore: CGFloat = 0
    @State private var lastShoulderY: CGFloat?
    @State private var lastHipY: CGFloat?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black)

                    MissionCameraPreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 28))

                    VStack(spacing: 8) {
                        Text(active ? "HOLD STEADY" : "PLANK")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))

                        Text("\(holdRemaining)s")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Stability: \(Int(stabilityScore * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(18)
                }
                .frame(height: 500)
                .padding(.horizontal, 18)

                Text(active ? "Keep your body still and aligned for 15 seconds." : "Start and hold a steady plank for 15 seconds.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(active ? Colors.accentTeal : Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Colors.cardStroke, lineWidth: 1))
                    .padding(.horizontal, 18)

                Button(action: actionTapped) {
                    Text(active ? "Stop" : "Start Plank")
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
                .padding(.horizontal, 18)

                Spacer(minLength: 8)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onReceive(ticker) { _ in
            guard active else { return }
            if holdRemaining > 0 {
                holdRemaining -= 1
            }
            if holdRemaining <= 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                active = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete?()
                    dismiss()
                }
            }
        }
        .onChange(of: camera.poseMetrics) { _, pose in
            guard active, let pose else { return }
            updateStability(with: pose)
        }
        .alert("Camera permission needed", isPresented: $camera.permissionDenied) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow camera access for plank posture tracking.")
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

            Text("Plank Hold")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private func actionTapped() {
        if active {
            active = false
        } else {
            active = true
            holdRemaining = 15
            stabilityScore = 0
            lastShoulderY = nil
            lastHipY = nil
        }
    }

    private func updateStability(with pose: PoseMetrics) {
        guard pose.confidence > 0.2 else {
            stabilityScore = max(0, stabilityScore - 0.12)
            return
        }

        let shoulderDelta = abs((lastShoulderY ?? pose.shoulderY) - pose.shoulderY)
        let hipDelta = abs((lastHipY ?? pose.hipY) - pose.hipY)
        let motion = shoulderDelta + hipDelta

        let isStable = motion < 0.02
        if isStable {
            stabilityScore = min(1, stabilityScore + 0.08)
        } else {
            stabilityScore = max(0, stabilityScore - 0.05)
            if holdRemaining > 1 {
                holdRemaining += 0 // keep timer running but stability reflects quality
            }
        }

        lastShoulderY = pose.shoulderY
        lastHipY = pose.hipY
    }
}
