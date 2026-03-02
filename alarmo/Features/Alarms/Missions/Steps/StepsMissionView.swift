import SwiftUI

struct StepsMissionView: View {
    @StateObject var viewModel: StepsMissionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack {
                headerView
                Spacer()
                
                switch viewModel.state {
                case .idle:
                    prepareView
                case .active, .success:
                    activeView
                case .blocked:
                    blockedView
                }
                
                Spacer()
            }
            .animation(.easeInOut, value: viewModel.state)
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if viewModel.state == .blocked {
                // Auto-retry when coming back from settings
                print("App entering foreground, retrying step mission...")
                viewModel.reset()
            }
        }
    }
    
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
            
            // Mute button logic could go here if sound players were used
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Prepare View
    private var prepareView: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "figure.walk")
                    .font(.system(size: 60))
                    .foregroundColor(Colors.textPrimary)
            }
            
            Text("Stand up and\nPrepare yourself")
                .font(.system(size: 32, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Button(action: {
                viewModel.start()
            }) {
                Text("Start Now")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
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
    }
    
    // MARK: - Active View
    private var activeView: some View {
        ZStack {
            VStack(spacing: 40) {
                if viewModel.showGetUpWarning {
                    Text("Get Up!")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.orange)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Walk Around")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
                
                ZStack {
                    // Background track
                    Circle()
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                        .frame(width: 250, height: 250)
                    
                    // Progress
                    let progress = 1.0 - (CGFloat(viewModel.remainingSteps) / CGFloat(viewModel.targetSteps))
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.78, blue: 0.92),
                                    Color(red: 0.05, green: 0.66, blue: 0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 24, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 250, height: 250)
                        .animation(.easeOut(duration: 0.5), value: progress)
                        .shadow(color: Color(red: 0, green: 0.7, blue: 0.9).opacity(0.4), radius: 10, x: 0, y: 0)
                    
                    // Inner content
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            // A simple scale/bounce effect when steps update
                            .scaleEffect(viewModel.remainingSteps % 2 == 0 ? 1.0 : 1.1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.remainingSteps)
                        
                        Text("\(viewModel.remainingSteps)")
                            .font(.system(size: 72, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.default, value: viewModel.remainingSteps)
                        
                        Text("steps left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            
            if viewModel.state == .success {
                successOverlay
            }
        }
    }
    
    private var successOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Great job!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("You're awake now! 👟")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
        }
        .transition(.scale.combined(with: .opacity))
        .padding(40)
        .background(Color.black.opacity(0.85))
        .cornerRadius(32)
    }
    
    // MARK: - Blocked View
    private var blockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Motion access required")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text("Please enable 'Motion & Fitness' access in Settings to use this mission.")
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
            .background(Colors.accentTeal)
            .cornerRadius(24)
            
            Button("Try Again") {
                viewModel.reset()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Colors.textSecondary)
        }
    }
}
