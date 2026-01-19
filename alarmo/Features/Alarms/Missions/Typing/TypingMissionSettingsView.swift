import SwiftUI
import Combine

class TypingSettingsViewModel: ObservableObject {
    @Published var settings: TypingSettings
    @Published var previewPhrase: String = ""
    @Published var isCyclingExamples: Bool = false
    
    private var missionId: String
    private var cancellables = Set<AnyCancellable>()
    private var cyclingTimer: AnyCancellable?
    
    init(missionId: String = "default") {
        self.missionId = missionId
        self.settings = TypingMissionStore.shared.loadSettings(for: missionId)
        updatePreviewPhrase()
    }
    
    func updatePreviewPhrase() {
        let allPhrases = TypingMissionStore.shared.allPhrases
        let selected = allPhrases.filter { settings.selectedPhraseIDs.contains($0.id) }
        
        if let random = selected.randomElement() {
            previewPhrase = random.text
        } else if let fallback = TypingSettings.defaultPhrases.randomElement() {
            previewPhrase = fallback.text
        }
    }
    
    func toggleExampleCycling() {
        isCyclingExamples.toggle()
        if isCyclingExamples {
            cyclingTimer = Timer.publish(every: 0.8, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.updatePreviewPhrase()
                }
        } else {
            cyclingTimer?.cancel()
            cyclingTimer = nil
        }
    }
    
    func save() {
        TypingMissionStore.shared.saveSettings(settings, for: missionId)
    }
}

struct TypingMissionSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: TypingSettingsViewModel
    @State private var showPhraseSelection = false
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    
    let onSave: (TypingSettings) -> Void
    
    init(onSave: @escaping (TypingSettings) -> Void) {
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: TypingSettingsViewModel())
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Example Section
                        exampleSection
                        
                        // Times Picker Section
                        timesPickerSection
                        
                        // Select Phrase Section
                        selectPhraseRow
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 24)
                }
            }
            
            // Footer Buttons
            footerButtons
        }
        .fullScreenCover(isPresented: $showPhraseSelection) {
            PhraseSelectionView(selectedIDs: $viewModel.settings.selectedPhraseIDs) {
                viewModel.updatePreviewPhrase()
            }
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "Typing",
                missionIcon: "keyboard.fill"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            let phrases = TypingMissionStore.shared.allPhrases.filter { viewModel.settings.selectedPhraseIDs.contains($0.id) }
            TypingMissionGameplayView(viewModel: TypingGameplayViewModel(
                settings: viewModel.settings,
                phrases: phrases.isEmpty ? TypingSettings.defaultPhrases : phrases,
                isPreviewMode: true,
                onComplete: {
                    showGamePreview = false
                }
            ))
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
            Text("Typing")
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
    
    private var exampleSection: some View {
        VStack(spacing: 24) {
            Button(action: { viewModel.toggleExampleCycling() }) {
                Text("Example")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Text(viewModel.previewPhrase)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(height: 80)
                .padding(.horizontal, 24)
        }
    }
    
    private var timesPickerSection: some View {
        VStack {
            Picker("Times", selection: $viewModel.settings.repeatCount) {
                ForEach(1...10, id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        if i == viewModel.settings.repeatCount {
                            Text("times")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
        }
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var selectPhraseRow: some View {
        Button(action: { showPhraseSelection = true }) {
            HStack {
                Text("Select phrase")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.settings.selectedPhraseIDs.count) phrase")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
                Image(systemName: "chevron.right")
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(24)
            .background(Colors.cardSurface)
            .cornerRadius(24)
        }
        .padding(.horizontal, 20)
    }
    
    private var footerButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button(action: { showAlarmPreview = true }) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(32)
                }
                
                Button(action: {
                    viewModel.save()
                    onSave(viewModel.settings)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(32)
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
}
