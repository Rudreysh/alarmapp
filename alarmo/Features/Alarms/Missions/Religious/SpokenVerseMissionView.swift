import SwiftUI
import AVFoundation
import Speech
import Combine

struct SpokenVerseMissionView: View {
    let mission: AlarmMission
    let verse: SpokenVerseItem
    let onComplete: () -> Void

    @StateObject private var viewModel: SpokenVerseMissionViewModel

    init(mission: AlarmMission, verse: SpokenVerseItem, onComplete: @escaping () -> Void) {
        self.mission = mission
        self.verse = verse
        self.onComplete = onComplete
        _viewModel = StateObject(
            wrappedValue: SpokenVerseMissionViewModel(targetText: verse.text)
        )
    }

    private var theme: SpokenVerseTheme {
        SpokenVerseTheme.forType(mission.type)
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 14) {
                headerPanel
                versePanel
                statusPanel
                actionButton
                transcriptPanel
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .onAppear { viewModel.prepare() }
        .onDisappear { viewModel.stopListening() }
        .onChange(of: viewModel.hasMatchedTarget) { _, matched in
            if matched {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onComplete()
                }
            }
        }
    }

    private var headerPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: theme.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.accent)
                .frame(width: 32, height: 32)
                .background(theme.accent.opacity(0.16))
                .clipShape(Circle())

            Text(verse.title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.accent)
                .tracking(1.8)

            Spacer()

            Text(viewModel.isListening ? "Recording" : "Ready")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(viewModel.isListening ? Colors.accentRed : Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Colors.bgSecondary)
                .cornerRadius(10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var versePanel: some View {
        ScrollView {
            Text(verse.text)
                .font(.system(size: 33, weight: .bold, design: .serif))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 380)
        .background(
            LinearGradient(
                colors: [Colors.cardSurface, theme.accent.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(theme.accent.opacity(0.36), lineWidth: 1)
        )
        .cornerRadius(26)
    }

    private var statusPanel: some View {
        Group {
            if viewModel.hasMatchedTarget {
                Label("Correct recitation", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.accentGreen)
            } else if viewModel.isListening {
                Label("Listening now. Tap stop when done.", systemImage: "waveform")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.accent)
            } else {
                Label("Tap mic and read aloud once", systemImage: "mic.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var actionButton: some View {
        Button(action: {
            if viewModel.hasMatchedTarget {
                onComplete()
            } else {
                viewModel.toggleListening()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.hasMatchedTarget ? Colors.accentGreen : Colors.cardSurface)
                    .frame(width: 114, height: 114)
                    .overlay(
                        Circle()
                            .stroke(viewModel.hasMatchedTarget ? Colors.accentGreen.opacity(0.7) : theme.accent.opacity(0.5), lineWidth: 3)
                    )
                Image(systemName: viewModel.hasMatchedTarget ? "checkmark" : (viewModel.isListening ? "stop.fill" : "mic.fill"))
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(viewModel.hasMatchedTarget ? .white : theme.accent)
            }
            .overlay(
                Circle()
                    .stroke(Colors.textPrimary.opacity(0.24), lineWidth: 2)
                    .frame(width: 128, height: 128)
            )
        }
        .buttonStyle(.plain)
    }

    private var transcriptPanel: some View {
        VStack(spacing: 10) {
            Text(viewModel.hasMatchedTarget ? "Mission complete" : "Speak clearly, then tap again to verify")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textSecondary)

            if let feedback = viewModel.feedbackMessage, !feedback.isEmpty {
                Text(feedback)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(viewModel.hasMatchedTarget ? Colors.accentGreen : Colors.accentRed)
                    .multilineTextAlignment(.center)
            }

            if !viewModel.detectedTranscript.isEmpty {
                Text("Heard: \"\(viewModel.detectedTranscript)\"")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Colors.accentRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 8)
    }
}

struct ReligiousMissionLaunchView: View {
    let mission: AlarmMission
    let onComplete: () -> Void
    private let fixedVerse: SpokenVerseItem?

    init(mission: AlarmMission, onComplete: @escaping () -> Void, verse: SpokenVerseItem? = nil) {
        self.mission = mission
        self.onComplete = onComplete
        self.fixedVerse = verse
    }

    private var resolvedVerse: SpokenVerseItem? {
        fixedVerse
            ?? ReligiousMissionContentStore.pickRandomItem(for: mission)
            ?? ReligiousMissionContentStore.items(for: mission.type).first
    }

    var body: some View {
        Group {
            if let verse = resolvedVerse {
                SpokenVerseMissionView(
                    mission: mission,
                    verse: verse,
                    onComplete: onComplete
                )
            } else {
                VStack(spacing: 16) {
                    Text(mission.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text("No verse is available for this mission. Reopen settings and select at least one item.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Colors.bgPrimary.ignoresSafeArea())
            }
        }
    }
}

private struct SpokenVerseTheme {
    let symbol: String
    let accent: Color

    static func forType(_ type: WakeUpMissionType) -> SpokenVerseTheme {
        let religionBlue = Color(red: 0.44, green: 0.80, blue: 0.98)
        switch type {
        case .bibleVerse:
            return .init(symbol: "book.closed.fill", accent: religionBlue)
        case .quranVerse:
            return .init(symbol: "moon.stars.fill", accent: religionBlue)
        case .bhagavadGitaVerse:
            return .init(symbol: "sun.max.fill", accent: religionBlue)
        case .affirmation:
            return .init(symbol: "sparkles", accent: religionBlue)
        default:
            return .init(symbol: "quote.bubble.fill", accent: religionBlue)
        }
    }
}

final class SpokenVerseMissionViewModel: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var errorMessage: String?
    @Published var hasMatchedTarget = false
    @Published var feedbackMessage: String?
    @Published var detectedTranscript: String = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let targetTokens: Set<String>
    private let minimumScore: Double = 0.52
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var didResolvePermissions = false
    private var hasPermissions = false

    init(targetText: String) {
        self.targetTokens = Set(Self.tokens(from: targetText))
        super.init()
    }

    func prepare() {
        guard !didResolvePermissions else { return }
        requestPermissionsIfNeeded { _ in }
    }

    func toggleListening() {
        isListening ? stopAndEvaluate() : startListening()
    }

    func startListening() {
        guard !hasMatchedTarget else { return }
        errorMessage = nil
        feedbackMessage = nil
        detectedTranscript = ""

        requestPermissionsIfNeeded { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone and speech permissions are required for this mission."
                    self.isListening = false
                }
                return
            }
            self.startRecognitionSession()
        }
    }

    func stopAndEvaluate() {
        guard isListening else { return }
        stopListening()
        evaluate(transcript: detectedTranscript)
    }

    func stopListening() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    private func startRecognitionSession() {
        stopListening()
        errorMessage = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
            }

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    DispatchQueue.main.async {
                        self.detectedTranscript = result.bestTranscription.formattedString
                    }
                    if result.isFinal && self.isListening {
                        self.stopListening()
                        self.evaluate(transcript: result.bestTranscription.formattedString)
                    }
                }

                if error != nil && self.isListening {
                    self.stopListening()
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not process your voice clearly. Please try again."
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to start listening. Please try again."
                self.isListening = false
            }
            stopListening()
        }
    }

    private func evaluate(transcript: String) {
        guard !targetTokens.isEmpty else { return }
        let spokenTokens = Set(Self.tokens(from: transcript))
        guard !spokenTokens.isEmpty else {
            DispatchQueue.main.async {
                self.feedbackMessage = "Incorrect. We could not detect enough words. Try again."
            }
            return
        }

        let overlapCount = targetTokens.intersection(spokenTokens).count
        let score = Double(overlapCount) / Double(targetTokens.count)
        let matchedMinimumWords = overlapCount >= min(6, targetTokens.count)

        if score >= minimumScore && matchedMinimumWords {
            DispatchQueue.main.async {
                self.hasMatchedTarget = true
                self.feedbackMessage = "Correct recitation."
            }
        } else {
            DispatchQueue.main.async {
                self.feedbackMessage = "Incorrect. Your spoken words did not match enough of the verse."
            }
        }
    }

    private static func tokens(from text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }

    private func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        if didResolvePermissions {
            completion(hasPermissions)
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard let self else {
                completion(false)
                return
            }
            guard speechStatus == .authorized else {
                self.didResolvePermissions = true
                self.hasPermissions = false
                completion(false)
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                self.didResolvePermissions = true
                self.hasPermissions = micGranted
                completion(micGranted)
            }
        }
    }
}
