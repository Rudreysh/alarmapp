import SwiftUI

struct TicTacToeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: TTTDifficulty = .medium
    @State private var selectedSize: TTTBoardSize = .threeByThree
    @State private var rounds: Int = 1
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    
    let onSave: (TTTDifficulty, TTTBoardSize, Int) -> Void
    
    init(onSave: @escaping (TTTDifficulty, TTTBoardSize, Int) -> Void) {
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 32) {
                        exampleSection
                        
                        difficultySection
                        
                        roundsSection
                        
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
                missionTitle: "Tic Tac Toe",
                missionIcon: "grid"
            ) {
                showAlarmPreview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showGamePreview = true
                }
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            TicTacToeGameView(
                viewModel: TicTacToeViewModel(
                    rounds: rounds,
                    isPreviewMode: true,
                    onComplete: {
                        showGamePreview = false
                        // User said: "when the mission in completed in the preview mode go back to the ui where there is preview and done button"
                    }
                )
            )
        }
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Text("Tic Tac Toe")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
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
                .background(MissionTheme.exampleBadgeFill)
                .foregroundColor(MissionTheme.exampleBadgeText)
                .clipShape(Capsule())
            
            // Mock 3x3 Grid
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { c in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MissionTheme.softFill)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(r == c ? "X" : (r == 0 && c == 2 ? "O" : ""))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(r == c ? .orange : MissionTheme.backgroundSubtleText)
                                )
                        }
                    }
                }
            }
            .padding(16)
            .background(MissionTheme.softFill)
            .cornerRadius(16)
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 8) {
                Text(selectedDifficulty.label)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                // Difficulty Slider style (using buttons for now to match the "segmented" feel but high precision)
                HStack(spacing: 0) {
                    ForEach(TTTDifficulty.allCases) { diff in
                        Rectangle()
                            .fill(selectedDifficulty == diff ? Colors.textPrimary : MissionTheme.softStroke)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Circle()
                                    .fill(selectedDifficulty == diff ? Colors.textPrimary : Color.clear)
                                    .frame(width: 12, height: 12)
                            )
                            .onTapGesture {
                                selectedDifficulty = diff
                            }
                    }
                }
                .padding(.horizontal, 10)
                
                HStack {
                    Text("Very easy").font(.system(size: 12)).foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text("Very hard").font(.system(size: 12)).foregroundColor(Colors.textSecondary)
                }
            }
            
            Divider().background(MissionTheme.softStroke)

            HStack {
                Text("Board Size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Picker("", selection: $selectedSize) {
                    ForEach(TTTBoardSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding(24)
        .background(Colors.cardSurface)
        .cornerRadius(24)
    }
    
    private var roundsSection: some View {
        VStack {
            Picker("Rounds", selection: $rounds) {
                ForEach(1...5, id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        if i == rounds {
                            Text("rounds")
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
                        .foregroundColor(MissionTheme.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.secondaryButtonFill)
                        .cornerRadius(32)
                }
                
                Button(action: {
                    onSave(selectedDifficulty, selectedSize, rounds)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.primaryButtonGradient)
                        .cornerRadius(32)
                        .shadow(color: MissionTheme.primaryButtonShadow, radius: 15, x: 0, y: 10)
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
