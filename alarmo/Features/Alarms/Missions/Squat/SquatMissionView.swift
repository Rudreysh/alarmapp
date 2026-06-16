import SwiftUI

struct SquatMissionView: View {
    @StateObject var viewModel: SquatMissionViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isAnimatingDemo = false
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack {
                headerView
                Spacer()
                
                switch viewModel.state {
                case .idle:
                    prepareView
                case .active:
                    activeView
                case .success:
                    successView
                case .blocked:
                    blockedView
                }
                
                Spacer()
            }
            .animation(.easeInOut, value: viewModel.state)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: {
                viewModel.stop()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Text("1/1")
                .font(.headline)
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Prepare
    
    private var prepareView: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(MissionTheme.softStroke, lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundColor(Colors.textPrimary)
                    // Animate the squatting motion
                    .offset(y: isAnimatingDemo ? 15 : 0)
                    .scaleEffect(y: isAnimatingDemo ? 0.8 : 1.0, anchor: .bottom)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isAnimatingDemo = true
                        }
                    }
                    .onDisappear {
                        isAnimatingDemo = false
                    }
            }
            
            Text("Do squats\nto dismiss")
                .font(.system(size: 32, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textPrimary)
            
            Text("Complete \(viewModel.targetSquats) squats to turn off the alarm")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                viewModel.start()
            }) {
                    Text("Start Now")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(MissionTheme.primaryButtonGradient)
                        .cornerRadius(32)
                        .shadow(color: MissionTheme.primaryButtonShadow, radius: 15, x: 0, y: 10)
            }
        }
    }
    
    // MARK: - Active
    
    private var activeView: some View {
        VStack(spacing: 32) {
            // Animated figure
            ZStack {
                // Background Track
                Circle()
                    .stroke(MissionTheme.softStroke, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 200, height: 200)
                
                // Progress
                Circle()
                    .trim(from: 0.0, to: viewModel.progress)
                    .stroke(
                            LinearGradient(
                                colors: [
                                    MissionTheme.isTiimo ? Color(hex: "#9B90F1") : Color(red: 0.08, green: 0.78, blue: 0.92),
                                    MissionTheme.isTiimo ? Colors.accentBlue : Color(red: 0.05, green: 0.66, blue: 0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)
                        .animation(.easeOut(duration: 0.3), value: viewModel.progress)
                        .shadow(color: MissionTheme.primaryButtonShadow.opacity(0.8), radius: 10, x: 0, y: 0)
                
                // Icon
                Image(systemName: viewModel.phase == .squatting ? "figure.cooldown" : "figure.strengthtraining.traditional")
                    .font(.system(size: 70))
                    .foregroundColor(Colors.textPrimary)
                    // Real-time squatting animation matching the user's detected phase
                    .offset(y: viewModel.phase == .squatting ? 25 : 0)
                    .scaleEffect(y: viewModel.phase == .squatting ? 0.8 : 1.0, anchor: .bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.phase)
            }
            
            // Phase indicator
            Text(viewModel.phase == .squatting ? "⬇️ DOWN" : "⬆️ UP")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(viewModel.phase == .squatting ? .orange : Color(red: 0.08, green: 0.78, blue: 0.92))
                .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
            
            // Counter
            HStack(alignment: .lastTextBaseline) {
                Text("\(viewModel.currentSquats)")
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundColor(Colors.textPrimary)
                    .contentTransition(.numericText())
                
                Text("/\(viewModel.targetSquats)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
            }
            
            Text("Keep a steady pace!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .padding(.top, 10)
        }
    }
    
    // MARK: - Success
    
    private var successView: some View {
        ZStack {
            MissionEmojiConfettiBackground()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Great workout!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Text("You're definitely awake now! 💪")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(40)
            .background(MissionTheme.successCardFill)
            .cornerRadius(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Blocked
    
    private var blockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Motion access required")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textPrimary)
            
            Text("Please enable 'Motion & Fitness' access in Settings to use the Squat mission.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textSecondary)
                .padding(.horizontal, 32)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(MissionTheme.primaryButtonGradient)
            .cornerRadius(24)
        }
    }
}
