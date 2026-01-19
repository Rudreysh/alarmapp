import SwiftUI

struct MathMissionPlayView: View {
    @StateObject var viewModel: MathMissionViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                Spacer()
                
                // Problem Display
                if let problem = viewModel.currentProblem {
                    VStack(spacing: 32) {
                        Text(problem.displayExpression)
                            .font(.system(size: 60, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        answerArea
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Numpad
                NumericKeypadView(
                    onDigit: viewModel.tapDigit,
                    onDelete: viewModel.deleteDigit,
                    onSubmit: viewModel.submit,
                    isDisabled: viewModel.feedbackState != .idle
                )
                .padding(.horizontal, 24)
                .padding(.bottom, viewModel.isPreviewMode ? 8 : 32)

                if viewModel.isPreviewMode {
                    Text("PREVIEW MODE")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
            }
            .blur(radius: viewModel.showSuccessOverlay ? 10 : 0)
            
            // Success Overlay
            if viewModel.showSuccessOverlay {
                successOverlay
                    .transition(.opacity.combined(with: .scale))
            }
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
            Text(viewModel.progressText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            // Timer Display
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("\(viewModel.timeRemaining)s")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(viewModel.timeRemaining < 10 ? .red : .cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            Button(action: { viewModel.isSoundEnabled.toggle() }) {
                Image(systemName: viewModel.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var answerArea: some View {
        ZStack {
            if viewModel.feedbackState == .idle {
                HStack {
                    Spacer()
                    Text(viewModel.inputText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Blinking Cursor
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: 40)
                        .opacity(viewModel.inputText.count < 9 ? 1 : 0) // Basic blink could be added with animation
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            } else {
                feedbackBar
            }
        }
        .animation(.spring(), value: viewModel.feedbackState)
    }
    
    private var feedbackBar: some View {
        HStack {
            Image(systemName: viewModel.feedbackState == .correct ? "circle" : "xmark")
                .font(.system(size: 40, weight: .bold))
            Spacer()
            Text(viewModel.inputText)
                .font(.system(size: 48, weight: .bold))
        }
        .padding(.horizontal, 32)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(viewModel.feedbackState == .correct ? Color.green : Color.red)
        .cornerRadius(16)
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                
                
                Text(viewModel.isPreviewMode && viewModel.currentIndex == viewModel.problems.count - 1 ? "Preview Complete" : "Good job!")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
            }
        }
    }
}
