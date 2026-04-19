import SwiftUI

struct ShakeMissionView: View {
    @StateObject var viewModel: ShakeMissionViewModel
    @Environment(\.dismiss) var dismiss
    
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
            Color.clear.frame(width: 24) // Balance spacer
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Prepare
    
    private var prepareView: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Text("Shake your phone\nto dismiss")
                .font(.system(size: 32, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text("You need to shake \(viewModel.targetShakes) times")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            
            Button(action: {
                viewModel.start()
            }) {
                Text("Start Now")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(32)
            }
        }
    }
    
    // MARK: - Active
    
    private var activeView: some View {
        VStack(spacing: 32) {
            // Animated phone icon
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(Colors.accentTeal)
                .rotationEffect(.degrees(viewModel.currentShakes % 2 == 0 ? -15 : 15))
                .animation(.easeInOut(duration: 0.15), value: viewModel.currentShakes)
            
            // Counter
            Text("\(viewModel.currentShakes)")
                .font(.system(size: 100, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            
            Text("of \(viewModel.targetShakes) shakes")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 12)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Colors.accentTeal, Colors.accentTeal.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(viewModel.progress, 1.0), height: 12)
                        .animation(.easeOut(duration: 0.15), value: viewModel.progress)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 40)
            
            Text("SHAKE HARDER!")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Colors.accentTeal.opacity(viewModel.progress < 0.5 ? 0.5 : 1.0))
                .scaleEffect(viewModel.progress > 0.8 ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
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
                
                Text("Good job!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("You're wide awake now!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
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
                .foregroundColor(.white)
            
            Text("Please enable Motion access in Settings to use the Shake mission.")
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
        }
    }
}
