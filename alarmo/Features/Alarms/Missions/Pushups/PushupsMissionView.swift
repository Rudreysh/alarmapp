import SwiftUI
import Combine

enum ExerciseMissionKind {
    case pushups
    case squats

    init(missionType: WakeUpMissionType) {
        self = missionType == .squat ? .squats : .pushups
    }

    var missionType: WakeUpMissionType {
        switch self {
        case .pushups: return .pushups
        case .squats: return .squat
        }
    }

    var title: String {
        switch self {
        case .pushups: return "Push-ups"
        case .squats: return "Squats"
        }
    }

    var lowercasePlural: String {
        switch self {
        case .pushups: return "push-ups"
        case .squats: return "squats"
        }
    }

    var singularLowercase: String {
        switch self {
        case .pushups: return "push-up"
        case .squats: return "squat"
        }
    }

    var iconName: String {
        switch self {
        case .pushups: return "figure.core.training"
        case .squats: return "figure.strengthtraining.traditional"
        }
    }

    var accent: Color {
        switch self {
        case .pushups: return Colors.accentOrange
        case .squats: return Colors.accentTeal
        }
    }

    var legacyCountKey: String {
        switch self {
        case .pushups: return "pushupCount"
        case .squats: return "squatCount"
        }
    }
}

enum ExerciseDifficultyLevel: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Difficult"
        }
    }

    var targetCount: Int {
        switch self {
        case .easy: return 10
        case .medium: return 15
        case .hard: return 20
        }
    }

    var missionDifficulty: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    static func resolve(targetCount: Int, rawDifficulty: Int) -> ExerciseDifficultyLevel {
        if let exact = allCases.first(where: { $0.targetCount == targetCount }) {
            return exact
        }

        switch rawDifficulty {
        case ..<2:
            return .easy
        case 2:
            return .medium
        case 3...:
            return .hard
        default:
            break
        }

        if targetCount <= 12 { return .easy }
        if targetCount >= 18 { return .hard }
        return .medium
    }
}

enum ExerciseMissionConfigResolver {
    static let sharedCountKey = "targetCount"

    static func normalizedMissionType(_ mission: AlarmMission, kind: ExerciseMissionKind) -> AlarmMission {
        if mission.type == kind.missionType { return mission }
        var normalized = mission
        normalized.type = kind.missionType
        return normalized
    }

    static func targetCount(for mission: AlarmMission, kind: ExerciseMissionKind) -> Int {
        if let count = mission.config[sharedCountKey], count > 0 {
            return count
        }
        if let count = mission.config[kind.legacyCountKey], count > 0 {
            return count
        }

        if mission.difficulty > 0 {
            return ExerciseDifficultyLevel.resolve(targetCount: 15, rawDifficulty: mission.difficulty).targetCount
        }
        return ExerciseDifficultyLevel.medium.targetCount
    }

    static func difficulty(for mission: AlarmMission, kind: ExerciseMissionKind) -> ExerciseDifficultyLevel {
        let count = targetCount(for: mission, kind: kind)
        return ExerciseDifficultyLevel.resolve(targetCount: count, rawDifficulty: mission.difficulty)
    }

    static func applySelection(to mission: AlarmMission, kind: ExerciseMissionKind, difficulty: ExerciseDifficultyLevel) -> AlarmMission {
        var updated = AlarmMission(
            type: kind.missionType,
            difficulty: difficulty.missionDifficulty,
            rounds: max(1, mission.rounds),
            config: mission.config,
            customData: mission.customData
        )
        updated.config[sharedCountKey] = difficulty.targetCount
        updated.config[kind.legacyCountKey] = difficulty.targetCount
        return updated
    }
}

struct ExerciseCameraMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = MissionCameraSession()

    let mission: AlarmMission
    var onComplete: (() -> Void)?

    @State private var state: ExerciseState = .ready
    @State private var detectedReps: Int = 0
    @State private var downPhase = false
    @State private var baselineMetric: CGFloat?
    @State private var humanFrames: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var lastRepTimestamp: TimeInterval = 0
    @State private var feedbackMessage: String?
    @State private var feedbackColor: Color = Colors.textSecondary
    @State private var didComplete = false
    @State private var showSuccessCelebration = false
    @State private var analysisTask: DispatchWorkItem?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum ExerciseState {
        case ready
        case recording
        case analyzing
        case success
        case failed
    }

    private var kind: ExerciseMissionKind {
        ExerciseMissionKind(missionType: mission.type)
    }

    private var targetCount: Int {
        ExerciseMissionConfigResolver.targetCount(for: mission, kind: kind)
    }

    private var maxRecordingSeconds: Int {
        max(18, min(55, targetCount * 3))
    }

    private var progress: Double {
        min(1, max(0, Double(detectedReps) / Double(max(1, targetCount))))
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                cameraCard
                    .padding(.horizontal, 18)

                statusBanner
                    .padding(.horizontal, 18)

                recordButton
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                Spacer(minLength: 8)
            }

            if showSuccessCelebration {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
            analysisTask?.cancel()
            analysisTask = nil
        }
        .onReceive(timer) { _ in
            guard state == .recording else { return }
            elapsedSeconds += 1
            if elapsedSeconds >= maxRecordingSeconds {
                stopAndAnalyze()
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
            Text("Allow camera access to record and verify \(kind.lowercasePlural).")
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Colors.cardSurface)
                    .overlay(
                        Circle().stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }

            Spacer()

            Text(kind.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var cameraCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black)

            MissionCameraPreview(session: camera.session)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 12) {
                targetHud
                Spacer()

                if state == .analyzing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.15)
                        Text("Analyzing \(kind.lowercasePlural)...")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(18)
                } else if state == .recording {
                    Text("Elapsed \(elapsedSeconds)s / \(maxRecordingSeconds)s")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(12)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundColor(.white.opacity(0.32))
                }

                Spacer()
                    .frame(height: 24)
            }
            .padding(18)
        }
        .frame(height: 560)
    }

    private var targetHud: some View {
        VStack(spacing: 8) {
            Text(state == .recording ? "RECORDING" : (state == .analyzing ? "ANALYZING" : "RECORD"))
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.white.opacity(0.85))
                .tracking(1.2)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 86, height: 86)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        kind.accent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 86, height: 86)

                Text("\(state == .ready ? targetCount : detectedReps)")
                    .font(.system(size: 37, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            Text("\(targetCount) \(kind.lowercasePlural)")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.34))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(18)
    }

    private var statusBanner: some View {
        Text(statusText)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(statusColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Colors.cardStroke, lineWidth: 1))
    }

    private var statusText: String {
        switch state {
        case .ready:
            return "Tap record and complete \(targetCount) \(kind.lowercasePlural). Keep your full body in frame."
        case .recording:
            return "Recording \(kind.lowercasePlural). Detected \(detectedReps) / \(targetCount)."
        case .analyzing:
            return "Analyzing your \(kind.lowercasePlural) recording..."
        case .success:
            return "Great set. Mission completed."
        case .failed:
            return feedbackMessage ?? "Could not verify enough valid movement. Try again."
        }
    }

    private var statusColor: Color {
        switch state {
        case .ready: return Colors.textSecondary
        case .recording: return kind.accent
        case .analyzing: return Colors.textPrimary
        case .success: return Colors.accentGreen
        case .failed: return feedbackColor
        }
    }

    private var recordButton: some View {
        Button(action: handleRecordButtonTapped) {
            ZStack {
                Circle()
                    .fill(Colors.cardSurface)
                    .frame(width: 108, height: 108)
                    .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 2))

                Circle()
                    .fill(state == .recording ? Colors.accentRed : kind.accent.opacity(0.78))
                    .frame(width: state == .recording ? 44 : 58, height: state == .recording ? 44 : 58)

                Image(systemName: state == .recording ? "stop.fill" : "record.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .opacity(state == .recording ? 1 : 0.88)
            }
            .overlay(
                Circle()
                    .stroke(Colors.textPrimary.opacity(0.35), lineWidth: 3)
                    .frame(width: 122, height: 122)
            )
        }
        .buttonStyle(.plain)
        .disabled(state == .analyzing)
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()
            MissionEmojiConfettiBackground()

            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundColor(Colors.accentGreen)
                Text("Mission complete")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
        }
        .allowsHitTesting(false)
    }

    private func handleRecordButtonTapped() {
        switch state {
        case .ready, .failed:
            startRecording()
        case .recording:
            stopAndAnalyze()
        case .success:
            completeMissionIfNeeded()
        case .analyzing:
            break
        }
    }

    private func startRecording() {
        analysisTask?.cancel()
        analysisTask = nil
        state = .recording
        feedbackMessage = nil
        feedbackColor = Colors.textSecondary
        detectedReps = 0
        downPhase = false
        baselineMetric = nil
        humanFrames = 0
        elapsedSeconds = 0
        lastRepTimestamp = 0
    }

    private func stopAndAnalyze() {
        guard state == .recording else { return }
        state = .analyzing
        let task = DispatchWorkItem {
            evaluateRecording()
        }
        analysisTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: task)
    }

    private func evaluateRecording() {
        let enoughHumanFrames = humanFrames >= max(20, elapsedSeconds * 6)
        let enoughReps = detectedReps >= targetCount

        if enoughHumanFrames && enoughReps {
            state = .success
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                showSuccessCelebration = true
            }
            completeMissionIfNeeded()
            return
        }

        state = .failed
        feedbackColor = Colors.accentRed
        if !enoughHumanFrames {
            feedbackMessage = "Full body was not visible clearly. Place the camera farther back and retry."
        } else {
            feedbackMessage = "Detected \(detectedReps) / \(targetCount) \(kind.lowercasePlural). Record again and complete the full count."
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func completeMissionIfNeeded() {
        guard !didComplete else { return }
        didComplete = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            onComplete?()
            dismiss()
        }
    }

    private func processPose(_ pose: PoseMetrics) {
        guard pose.confidence > 0.2 else { return }
        humanFrames += 1

        switch kind {
        case .pushups:
            processPushupsPose(pose)
        case .squats:
            processSquatPose(pose)
        }
    }

    private func processPushupsPose(_ pose: PoseMetrics) {
        let torso = max(abs(pose.shoulderY - pose.hipY), 0.05)
        let movementMetric = (pose.shoulderY - pose.wristY) / torso
        guard movementMetric.isFinite else { return }

        if baselineMetric == nil {
            baselineMetric = movementMetric
            return
        }

        let baseline = baselineMetric ?? movementMetric
        baselineMetric = (baseline * 0.92) + (movementMetric * 0.08)
        let dynamicBase = baselineMetric ?? movementMetric

        let lower = dynamicBase - 0.25
        let upper = dynamicBase + 0.22

        if !downPhase && movementMetric < lower {
            downPhase = true
        } else if downPhase && movementMetric > upper {
            downPhase = false
            registerRepIfNeeded()
        }
    }

    private func processSquatPose(_ pose: PoseMetrics) {
        let bodySpan = max(abs(pose.shoulderY - pose.ankleY), 0.08)
        let movementMetric = (pose.hipY - pose.ankleY) / bodySpan
        guard movementMetric.isFinite else { return }

        if baselineMetric == nil {
            baselineMetric = movementMetric
            return
        }

        let baseline = baselineMetric ?? movementMetric
        baselineMetric = (baseline * 0.93) + (movementMetric * 0.07)
        let dynamicBase = baselineMetric ?? movementMetric

        let lower = dynamicBase - 0.12
        let upper = dynamicBase - 0.03

        if !downPhase && movementMetric < lower {
            downPhase = true
        } else if downPhase && movementMetric > upper {
            downPhase = false
            registerRepIfNeeded()
        }
    }

    private func registerRepIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastRepTimestamp > 0.45 else { return }
        lastRepTimestamp = now
        detectedReps += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct PushupsMissionView: View {
    let mission: AlarmMission
    var onComplete: (() -> Void)?

    init(mission: AlarmMission = AlarmMission(type: .pushups), onComplete: (() -> Void)? = nil) {
        self.mission = mission
        self.onComplete = onComplete
    }

    var body: some View {
        ExerciseCameraMissionView(
            mission: ExerciseMissionConfigResolver.normalizedMissionType(mission, kind: .pushups),
            onComplete: onComplete
        )
    }
}

struct ExerciseMissionSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let kind: ExerciseMissionKind
    let initialMission: AlarmMission
    let onSave: (AlarmMission) -> Void

    @State private var selectedDifficulty: ExerciseDifficultyLevel
    @State private var showAlarmPreview = false
    @State private var showMissionPreview = false
    @State private var previewMission: AlarmMission?
    @State private var animateDemo = false

    init(kind: ExerciseMissionKind, initialMission: AlarmMission, onSave: @escaping (AlarmMission) -> Void) {
        self.kind = kind
        let normalized = ExerciseMissionConfigResolver.normalizedMissionType(initialMission, kind: kind)
        self.initialMission = normalized
        self.onSave = onSave
        _selectedDifficulty = State(initialValue: ExerciseMissionConfigResolver.difficulty(for: normalized, kind: kind))
    }

    private var configuredMission: AlarmMission {
        ExerciseMissionConfigResolver.applySelection(to: initialMission, kind: kind, difficulty: selectedDifficulty)
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        previewAnimationCard
                        difficultySection
                        countCard
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }

            footerButtons
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: kind.title,
                missionIcon: kind.iconName
            ) {
                launchMissionPreviewAfterAlarmPreview()
            }
        }
        .fullScreenCover(isPresented: $showMissionPreview) {
            if let previewMission {
                ExerciseCameraMissionView(
                    mission: previewMission,
                    onComplete: {
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

            Text(kind.title)
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

    private var previewAnimationCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Colors.cardSurface)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(kind.accent.opacity(0.45), lineWidth: 7)
                        .frame(width: 104, height: 104)
                    Image(systemName: kind.iconName)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(kind.accent)
                        .offset(y: animateDemo ? 11 : -3)
                        .scaleEffect(y: animateDemo ? 0.86 : 1.0, anchor: .bottom)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animateDemo)
                }

                Text("Record and verify \(kind.lowercasePlural)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)

                Text("Choose difficulty, then Preview to test full camera detection before saving.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }
            .padding(.vertical, 22)
            .onAppear {
                animateDemo = true
            }
        }
        .frame(height: 260)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Difficulty")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            HStack(spacing: 10) {
                ForEach(ExerciseDifficultyLevel.allCases) { level in
                    Button {
                        selectedDifficulty = level
                    } label: {
                        VStack(spacing: 4) {
                            Text(level.title)
                                .font(.system(size: 14, weight: .bold))
                            Text("\(level.targetCount)")
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundColor(selectedDifficulty == level ? .white : Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedDifficulty == level ? kind.accent : Colors.cardSurface)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedDifficulty == level ? kind.accent : Colors.cardStroke, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var countCard: some View {
        VStack(spacing: 8) {
            Text("\(selectedDifficulty.targetCount)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(kind.accent)

            Text(kind.lowercasePlural.capitalized)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Text("\(selectedDifficulty.title) mode")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
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
        previewMission = configuredMission
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
        onSave(configuredMission)
        dismiss()
    }
}

struct PushupsMissionSettingsView: View {
    let initialMission: AlarmMission
    let onSave: (AlarmMission) -> Void

    init(initialMission: AlarmMission = AlarmMission(type: .pushups), onSave: @escaping (AlarmMission) -> Void) {
        self.initialMission = initialMission
        self.onSave = onSave
    }

    var body: some View {
        ExerciseMissionSettingsView(
            kind: .pushups,
            initialMission: initialMission,
            onSave: onSave
        )
    }
}
