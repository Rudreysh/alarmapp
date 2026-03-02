import SwiftUI
import Combine

class MathSettingsViewModel: ObservableObject {
    @Published var config: MathMissionConfig
    @Published var exampleProblem: MathProblem
    
    init() {
        // Load existing if any, or defaults
        self.config = MathMissionConfig()
        self.exampleProblem = MathProblemGenerator.generateProblem(difficulty: .normal)
    }
    
    func refreshExample() {
        exampleProblem = MathProblemGenerator.generateProblem(difficulty: config.difficulty)
    }
}

struct MathMissionSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = MathSettingsViewModel()
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    
    let onSave: (MathMissionConfig) -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Example Section
                        exampleSection
                        
                        // Difficulty Slider
                        DifficultySliderView(difficulty: $viewModel.config.difficulty)
                            .onChange(of: viewModel.config.difficulty) { _, _ in
                                viewModel.refreshExample()
                            }
                        
                        // Times Picker
                        timesPickerSection
                        
                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
            }
            
            footerButtons
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "Math",
                missionIcon: "plus.forwardslash.minus"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            MathMissionPlayView(
                viewModel: MathMissionViewModel(config: viewModel.config, isPreviewMode: true, onComplete: {
                    showGamePreview = false
                })
            )
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
            Text("Math")
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
    }
    
    private var exampleSection: some View {
        VStack(spacing: 16) {
            Text("Example")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            
            HStack(spacing: 12) {
                Text("\(viewModel.exampleProblem.displayExpression) =")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // ? Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private var timesPickerSection: some View {
        VStack {
            Picker("Times", selection: $viewModel.config.repeatCount) {
                ForEach(1...10, id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        if i == viewModel.config.repeatCount {
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
                    onSave(viewModel.config)
                    dismiss()
                }) {
                    Text("Done")
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
