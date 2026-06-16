import SwiftUI

struct TypingMissionGameplayView: View {
    @StateObject var viewModel: TypingGameplayViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Phrase Display Area
                phraseDisplayView
                    .onTapGesture { isTextFieldFocused = true }
                
                Spacer()
                
                // Progress Counter
                Text("\(viewModel.matchLen) / \(viewModel.targetPhrase.count)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(viewModel.hasMismatch ? .red : .cyan)
                    .padding(.bottom, 20)
                
                // Done Button
                Button(action: {
                    viewModel.handleDone()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(viewModel.isDoneEnabled ? MissionTheme.secondaryButtonText : Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.isDoneEnabled ? MissionTheme.secondaryButtonFill : MissionTheme.softFill)
                        .cornerRadius(32)
                }
                .disabled(!viewModel.isDoneEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, viewModel.isPreviewMode ? 8 : 12)
                
                if viewModel.isPreviewMode {
                    Text("PREVIEW MODE")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(MissionTheme.backgroundSubtleText)
                        .padding(.bottom, 20)
                }
                
                // Hidden TextField to capture input
                TextField("", text: $viewModel.typedInput)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .opacity(0)
                    .frame(width: 1, height: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { isTextFieldFocused = true }
            .blur(radius: viewModel.showSuccessOverlay ? 10 : 0)
            
            // Success Overlay
            if viewModel.showSuccessOverlay {
                successOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            isTextFieldFocused = true
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
            Text("\(viewModel.roundIndex)/\(viewModel.totalRounds)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
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
            .background(MissionTheme.timerCapsuleFill)
            .cornerRadius(12)
            
            Spacer()
            Button(action: { viewModel.soundEnabled.toggle() }) {
                Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var phraseDisplayView: some View {
        HStack(spacing: 0) {
            // Segments based on match state
            HStack(spacing: 0) {
                // Green (Correct)
                if !viewModel.greenSegment.isEmpty {
                    Text(viewModel.greenSegment)
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .background(Color.green.opacity(0.8))
                }
                
                // Red (Incorrect - within phrase)
                if viewModel.hasMismatch && !viewModel.redSegment.isEmpty {
                    Text(viewModel.redSegment)
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .background(Color.red.opacity(0.8))
                }
                
                // Red (Extra characters - beyond phrase)
                if !viewModel.extraSegment.isEmpty {
                    Text(viewModel.extraSegment)
                        .foregroundColor(.white)
                        .padding(.horizontal, 2)
                        .background(Color.red.opacity(0.6))
                }
                
                // Blinking Cursor
                BlinkingCursor()
                    .frame(height: 32)
                
                // Remainder (Gray)
                if !viewModel.remainderSegment.isEmpty {
                    Text(viewModel.remainderSegment)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .font(.system(size: 32, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(12)
            .background(MissionTheme.softFill)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
    
    private var successOverlay: some View {
        ZStack {
            MissionTheme.successScrim.ignoresSafeArea()
            MissionEmojiConfettiBackground()
            
            VStack(spacing: 24) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                
                Text(viewModel.isPreviewMode && viewModel.roundIndex == viewModel.totalRounds ? "Preview Complete" : "Good job!")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(Colors.textPrimary)
            }
            .padding(28)
            .background(MissionTheme.successCardFill)
            .cornerRadius(28)
        }
    }
}

struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Colors.textPrimary)
            .frame(width: 2)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}
