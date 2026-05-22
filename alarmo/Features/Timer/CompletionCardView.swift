import SwiftUI

struct CompletionCardView: View {
    let taskName: String
    let sessions: Int
    let totalTime: String
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "00C853")) // Green from Focus Keeper
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("Well done!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Task Complete! 🏆")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                HStack {
                    StatItem(label: "Sessions", value: "\(sessions)")
                    Divider().frame(height: 40)
                    StatItem(label: "Focused on", value: taskName)
                    Divider().frame(height: 40)
                    StatItem(label: "Total Time", value: totalTime)
                }
                .padding(.horizontal)
            }
            
            Button(action: onDone) {
                Text("Finish")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.darkGray)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
        }
        .padding(32)
        .background(Color.white)
        .cornerRadius(24)
        .padding(24)
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    static let darkGray = Color(white: 0.2)
}
