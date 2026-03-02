import SwiftUI
import Combine

struct OnboardingMissionView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var viewModel: OnboardingMissionViewModel
    let onBack: () -> Void
    let onDone: () -> Void
    @State private var previewedMission: MissionOption?

    init(onboardingViewModel: OnboardingViewModel, onBack: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.onboardingViewModel = onboardingViewModel
        self._viewModel = StateObject(wrappedValue: OnboardingMissionViewModel(onboardingViewModel: onboardingViewModel))
        self.onBack = onBack
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Colors.bgSecondary.opacity(0.6))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                ProgressHeader(step: 4, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)

                Text("Choose a wakeup mission")
                    .font(.system(size: 28, weight: .bold)) // Fits on one line, scaled down from 32
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.l)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.m) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Spacing.m),
                                GridItem(.flexible(), spacing: Spacing.m)
                            ],
                            spacing: Spacing.m
                        ) {
                            ForEach(viewModel.options.filter { $0.id != .off }) { option in
                                MissionRowView(option: option, isSelected: viewModel.selected == option.id, onTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.select(option)
                                    }
                                }, onPreview: {
                                    previewedMission = option
                                })
                            }
                        }
                        
                        if let offOption = viewModel.options.first(where: { $0.id == .off }) {
                            MissionRowView(option: offOption, isSelected: viewModel.selected == offOption.id, onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.select(offOption)
                                }
                            })
                            .padding(.top, Spacing.s)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, 40)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Done", style: .blueGlass) {
                    onboardingViewModel.completeOnboarding()
                    onDone()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $previewedMission) { mission in
            MissionPreviewSheet(mission: mission)
                .presentationDetents([.fraction(0.45), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct MissionPreviewSheet: View {
    let mission: MissionOption
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            if let icon = mission.icon, let background = mission.iconBackground {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(background)
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 64, height: 64)
            }

            Text(mission.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                
            Text(description(for: mission.id))
                .font(.system(size: 16))
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                
            MissionAnimationView(type: mission.id)
                .padding(.top, Spacing.m)
                
            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.bgPrimary)
    }
    
    private func description(for id: WakeUpMissionType) -> String {
        switch id {
        case .math: return "Solve simple math problems to turn off the alarm and wake up your brain."
        case .typing: return "Type a motivational quote to successfully dismiss the alarm."
        case .findColorTiles, .memoryMatch: return "Memorize and match color tiles to prove you are fully awake."
        case .shake: return "Shake your phone vigorously a few times to turn off the alarm."
        case .ticTacToe: return "Win or draw a game of Tic-Tac-Toe to wake up."
        case .step: return "Take a certain number of steps to dismiss the alarm."
        case .qrBarcode: return "Scan a specific QR or Barcode to turn the alarm off."
        case .squat: return "Do a set of squats to dismiss the alarm and energize your body."
        case .off: return "Turn off the alarm normally."
        }
    }
}

private struct MissionAnimationView: View {
    let type: WakeUpMissionType
    @State private var animate = false
    @State private var tick = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if type == .typing {
                Text("Target word: \"Wake up\"")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.bottom, -8)
            } else if type == .math {
                Text("Problem: 3 x 4 = ?")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.bottom, -8)
            }
            
            HStack(spacing: Spacing.xl) {
                // CORRECT SCENARIO
                VStack(spacing: Spacing.m) {
                    Text("✅ Correct")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                    
                    correctAnimationBlock
                }
                
                // INCORRECT SCENARIO
                VStack(spacing: Spacing.m) {
                    Text("❌ Incorrect")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                    
                    incorrectAnimationBlock
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
            tick += 1
        }
    }
    
    @ViewBuilder
    private var correctAnimationBlock: some View {
        Group {
            switch type {
            case .math:
                HStack {
                    Text("12")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(animate ? Colors.accentTeal : Colors.textPrimary)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Colors.accentTeal)
                        .opacity(animate ? 1 : 0)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .typing:
                let words = ["|", "W|", "Wa|", "Wak|", "Wake|", "Wake |", "Wake u|", "Wake up|", "Wake up|", "Wake up|"]
                let text = words[tick % words.count]
                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Colors.accentTeal)
                    .frame(width: 140, height: 60)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
            case .findColorTiles, .memoryMatch:
                let pattern = [0, 4, 8]
                let t = tick % 10
                let showTarget = t == 1 || t == 2
                let tappedCount = t >= 4 ? min(t - 3, 3) : 0
                let showResult = t >= 7
                let taps = Array(pattern.prefix(tappedCount))

                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row * 3 + col
                                    let isTarget = pattern.contains(index)
                                    let isTapped = taps.contains(index)
                                    
                                    let color: Color = {
                                        if showTarget && isTarget { return Colors.textPrimary }
                                        if isTapped { return Colors.accentTeal }
                                        return Colors.cardStroke
                                    }()
                                    
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(color)
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    
                    ZStack {
                        if showResult {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Colors.accentTeal)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 20)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .shake:
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 24))
                        .foregroundColor(Colors.accentTeal)
                        .rotationEffect(.degrees(animate ? 15 : -15))
                    Text("100%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .ticTacToe:
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("X").foregroundColor(Colors.accentTeal)
                        Text("X").foregroundColor(Colors.accentTeal)
                        Text("X").foregroundColor(Colors.accentTeal)
                    }
                    .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .step:
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Colors.accentTeal)
                        .offset(x: animate ? 5 : -5)
                    Text("10/10")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .qrBarcode:
                Image(systemName: "checkmark.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(Colors.accentTeal)
                    .scaleEffect(animate ? 1.1 : 1.0)
                    .frame(width: 140, height: 60)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
            case .squat:
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(Colors.accentTeal)
                        .scaleEffect(animate ? 1.1 : 0.9)
                    Text("10/10")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .off:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private var incorrectAnimationBlock: some View {
        Group {
            switch type {
            case .math:
                HStack {
                    Text("10")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(animate ? Colors.accentRed : Colors.textPrimary)
                        .offset(x: animate ? -3 : 3)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Colors.accentRed)
                        .opacity(animate ? 1 : 0)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .typing:
                let words = ["|", "W|", "Wk|", "Wka|", "Wkae|", "Wkae |", "Wkae u|", "Wkae up|", "Wkae up|", "Wkae up|"]
                let text = words[tick % words.count]
                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Colors.accentRed)
                    .underline(true, color: Colors.accentRed)
                    .frame(width: 140, height: 60)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
            case .findColorTiles, .memoryMatch:
                let pattern = [0, 4, 8]
                let wrongTap = [1, 4, 7]
                let t = tick % 10
                let showTarget = t == 1 || t == 2
                let tappedCount = t >= 4 ? min(t - 3, 3) : 0
                let showResult = t >= 7
                let taps = Array(wrongTap.prefix(tappedCount))
                
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row * 3 + col
                                    let isTarget = pattern.contains(index)
                                    let isTapped = taps.contains(index)
                                    
                                    let color: Color = {
                                        if showTarget && isTarget { return Colors.textPrimary }
                                        if isTapped { return Colors.accentRed }
                                        return Colors.cardStroke
                                    }()
                                    
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(color)
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    
                    ZStack {
                        if showResult {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Colors.accentRed)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 20)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .shake:
                HStack {
                    Image(systemName: "iphone")
                        .font(.system(size: 24))
                        .foregroundColor(Colors.textSecondary)
                    Text("0%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .ticTacToe:
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("X").foregroundColor(Colors.textSecondary)
                        Text("O").foregroundColor(Colors.accentRed)
                        Text("X").foregroundColor(Colors.textSecondary)
                    }
                    .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .step:
                HStack {
                    Image(systemName: "figure.stand")
                        .foregroundColor(Colors.textSecondary)
                    Text("2/10")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .qrBarcode:
                Image(systemName: "xmark.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(Colors.accentRed)
                    .scaleEffect(animate ? 1.1 : 1.0)
                    .frame(width: 140, height: 60)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
            case .squat:
                HStack {
                    Image(systemName: "figure.cooldown")
                        .foregroundColor(Colors.textSecondary)
                    Text("2/10")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentRed)
                }
                .frame(width: 140, height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
            case .off:
                EmptyView()
            }
        }
    }
}
