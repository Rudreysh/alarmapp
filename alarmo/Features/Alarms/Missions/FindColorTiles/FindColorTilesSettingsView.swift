import SwiftUI

struct FindColorTilesSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var settings: FindColorTilesSettings
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    let onSave: (FindColorTilesSettings) -> Void
    
    init(onSave: @escaping (FindColorTilesSettings) -> Void) {
        self.onSave = onSave
        let initial = MissionSettingsStore.shared.load(for: "findColorTiles", default: FindColorTilesSettings())
        _settings = State(initialValue: initial)
    }
    
    var body: some View {
        ZStack {
            // Consistent background color
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Example Section
                        exampleSection
                        
                        // Difficulty Section
                        difficultySection
                        
                        // Rounds Section
                        roundsSection
                        
                        // Extra bottom padding for floating buttons
                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
            }
            
            // Footer Buttons
            footerButtons
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "Find Color Tiles",
                missionIcon: "square.grid.2x2.fill"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            FindColorTilesMissionView(viewModel: FindColorTilesViewModel(
                settings: settings,
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
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Text("Find Color Tiles")
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
        .background(Colors.bgPrimary)
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
            
            // Preview Grid - Responsive size
            let n = max(1, settings.difficulty.gridSize)
            let spacing: CGFloat = 8
            let totalSize: CGFloat = 180
            let tileSize = max(0, (totalSize - CGFloat(n - 1) * spacing) / CGFloat(n))
            
            VStack(spacing: spacing) {
                ForEach(0..<n, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<n, id: \.self) { col in
                            let isTarget = (row + col) % 3 == 0
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isTarget ? Color.orange : Color(white: 0.25))
                                .frame(width: tileSize, height: tileSize)
                        }
                    }
                }
            }
            .frame(width: totalSize, height: totalSize)
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(settings.difficulty.label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            CustomSlider(value: Binding(
                get: { Double(settings.difficulty.rawValue) },
                set: { settings.difficulty = MissionDifficulty(rawValue: Int($0)) ?? .normal }
            ), range: 0...3, step: 1)
                .padding(.horizontal, 20)
            
            HStack {
                Text("Very easy").font(.system(size: 13)).foregroundColor(Colors.textSecondary)
                Spacer()
                Text("Very hard").font(.system(size: 13)).foregroundColor(Colors.textSecondary)
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 28)
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var roundsSection: some View {
        VStack {
            Picker("Rounds", selection: $settings.rounds) {
                ForEach([1, 2, 3, 4, 5, 7, 10], id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        if i == settings.rounds {
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
        .padding(.horizontal, 20)
    }
    
    private var footerButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button(action: {
                    showAlarmPreview = true
                }) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MissionTheme.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.secondaryButtonFill)
                        .cornerRadius(32)
                }
                
                Button(action: {
                    MissionSettingsStore.shared.save(settings, for: "findColorTiles")
                    onSave(settings)
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
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(MissionTheme.softFillStrong)
                    .frame(height: 4)
                
                // Tick marks
                HStack {
                    ForEach(0...Int((range.upperBound - range.lowerBound) / step), id: \.self) { index in
                        Circle()
                            .fill(MissionTheme.backgroundSubtleText)
                            .frame(width: 4, height: 4)
                        if index != Int((range.upperBound - range.lowerBound) / step) {
                            Spacer()
                        }
                    }
                }
                
                // Thumb
                Circle()
                    .fill(MissionTheme.selectedControlFill)
                    .frame(width: 28, height: 28)
                    .offset(x: self.getThumbOffset(geometry: geometry))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                self.updateValue(gesture: gesture, geometry: geometry)
                            }
                    )
            }
        }
        .frame(height: 28)
    }
    
    private func getThumbOffset(geometry: GeometryProxy) -> CGFloat {
        let proportion = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let usableWidth = max(0, geometry.size.width - 28)
        return CGFloat(proportion) * usableWidth
    }
    
    private func updateValue(gesture: DragGesture.Value, geometry: GeometryProxy) {
        let proportion = gesture.location.x / geometry.size.width
        let newValue = Double(proportion) * (range.upperBound - range.lowerBound) + range.lowerBound
        let steppedValue = round(newValue / step) * step
        self.value = min(max(steppedValue, range.lowerBound), range.upperBound)
    }
}
