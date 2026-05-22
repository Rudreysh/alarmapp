import SwiftUI

struct PrimaryPlayPauseButton: View {
    let isRunning: Bool
    let theme: PomodoroTheme
    let action: () -> Void
    
    @State private var isPressing = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 90, height: 90)
                
                // Inner circle
                Circle()
                    .fill(theme.buttonBg)
                    .frame(width: 82, height: 82)
                
                // Icon
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
            }
            .scaleEffect(isPressing ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressing = true }
                .onEnded { _ in isPressing = false }
        )
    }
}
