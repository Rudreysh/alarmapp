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

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Wayk")
                    .font(.system(size: 56, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 16) {
                        Text(verse.title.uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Colors.accentOrange)
                            .tracking(2.5)

                        Text(verse.text)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundColor(Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(.horizontal, 8)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Colors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .cornerRadius(30)
                }
                .padding(.horizontal, 18)

                if viewModel.hasMatchedTarget {
                    Label("Matched", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentGreen)
                } else {
                    Text(viewModel.isListening ? "Listening..." : "Read aloud to complete")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }

                Button(action: {
                    if viewModel.hasMatchedTarget {
                        onComplete()
                    } else {
                        viewModel.toggleListening()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.hasMatchedTarget ? Colors.accentOrange : Colors.cardSurface)
                            .frame(width: 108, height: 108)
                        Image(systemName: viewModel.hasMatchedTarget ? "checkmark" : (viewModel.isListening ? "waveform" : "mic.fill"))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(viewModel.hasMatchedTarget ? .white : Colors.textPrimary)
                    }
                    .overlay(
                        Circle()
                            .stroke(Colors.textPrimary.opacity(0.35), lineWidth: 4)
                            .frame(width: 120, height: 120)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)

                Text(viewModel.hasMatchedTarget ? "Mission complete" : "Speak the text clearly")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.bottom, 20)

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.accentRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                }
            }
            .padding(.top, 8)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .onChange(of: viewModel.hasMatchedTarget) { _, matched in
            if matched {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onComplete()
                }
            }
        }
    }
}

final class SpokenVerseMissionViewModel: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var errorMessage: String?
    @Published var hasMatchedTarget = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let targetTokens: Set<String>
    private let minimumScore: Double = 0.52
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(targetText: String) {
        self.targetTokens = Set(Self.tokens(from: targetText))
        super.init()
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func startListening() {
        guard !hasMatchedTarget else { return }
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

    func stopListening() {
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
                    self.evaluate(transcript: result.bestTranscription.formattedString)
                    if result.isFinal && !self.hasMatchedTarget {
                        self.restartAfterShortDelay()
                    }
                }

                if error != nil && !self.hasMatchedTarget {
                    self.restartAfterShortDelay()
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

    private func restartAfterShortDelay() {
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, !self.hasMatchedTarget else { return }
            self.startListening()
        }
    }

    private func evaluate(transcript: String) {
        guard !targetTokens.isEmpty else { return }
        let spokenTokens = Set(Self.tokens(from: transcript))
        guard !spokenTokens.isEmpty else { return }

        let overlapCount = targetTokens.intersection(spokenTokens).count
        let score = Double(overlapCount) / Double(targetTokens.count)
        let matchedMinimumWords = overlapCount >= min(6, targetTokens.count)

        if score >= minimumScore && matchedMinimumWords {
            DispatchQueue.main.async {
                self.hasMatchedTarget = true
                self.stopListening()
            }
        }
    }

    private static func tokens(from text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }

    private func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                completion(false)
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                completion(micGranted)
            }
        }
    }
}
