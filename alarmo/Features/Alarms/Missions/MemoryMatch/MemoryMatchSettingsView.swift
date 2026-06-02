import SwiftUI

struct MemoryMatchSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDifficulty: MemoryDifficulty = .fourByFour
    @State private var rounds: Int = 1
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    
    let onSave: (MemoryDifficulty, Int) -> Void
    
    init(onSave: @escaping (MemoryDifficulty, Int) -> Void) {
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
                missionTitle: "Memory Match",
                missionIcon: "brain.head.profile"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            MemoryMatchGameView(
                viewModel: MemoryMatchViewModel(
                    difficulty: selectedDifficulty,
                    rounds: rounds,
                    isPreviewMode: true,
                    onComplete: {
                        showGamePreview = false
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
            Text("Memory Match")
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
            
            // Mock Grid Preview
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { c in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(MissionTheme.softFill)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: r == 0 && c == 1 ? "leaf.fill" : (r == 1 && c == 2 ? "leaf.fill" : "questionmark"))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(r == 0 && c == 1 || r == 1 && c == 2 ? .green : MissionTheme.backgroundSubtleText)
                                )
                        }
                    }
                }
            }
            .padding(16)
            .background(MissionTheme.segmentedTrackFill)
            .cornerRadius(16)
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 8) {
                Text(selectedDifficulty.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                // Difficulty Slider style
                HStack(spacing: 0) {
                    ForEach(MemoryDifficulty.allCases) { diff in
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(selectedDifficulty == diff ? MissionTheme.selectedControlFill : MissionTheme.unselectedControlFill)
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Circle()
                                        .fill(selectedDifficulty == diff ? MissionTheme.selectedControlFill : Color.clear)
                                        .frame(width: 12, height: 12)
                                )
                                .onTapGesture {
                                    selectedDifficulty = diff
                                }

                            Text(diff.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
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
            
            Text(selectedDifficulty.hasBonus ? "Includes 1 Bonus Star" : "Pure Pairs")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
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
                    onSave(selectedDifficulty, rounds)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
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
