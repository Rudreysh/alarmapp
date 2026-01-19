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
                    .frame(width: 80, height: 80)
                
                Text("0")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Stand up and\nPrepare yourself")
                .font(.system(size: 32, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Button(action: {
                // Request Permission / Start
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
    
    // MARK: - Active View
    private var activeView: some View {
        ZStack {
            VStack(spacing: 24) {
                if viewModel.showGetUpWarning {
                    Text("Get Up!")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Take steps softly")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
                
                HStack(alignment: .center) {
                    Spacer()
                    Text("\(viewModel.remainingSteps)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    
                    // Round indicator (faded 1) as seen in image
                    Text("1")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white.opacity(0.1))
                        .offset(x: 20)
                }
            }
            
            if viewModel.state == .success {
                successOverlay
            }
        }
    }
    
    private var successOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Good job!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Colors.cardSurface)
                    .appShadow(Shadows.card)
            )
        }
        .transition(.scale.combined(with: .opacity))
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
