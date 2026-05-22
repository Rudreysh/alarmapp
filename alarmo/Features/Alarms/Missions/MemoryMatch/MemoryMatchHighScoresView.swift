import SwiftUI

struct MemoryMatchHighScoresView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(MemoryDifficulty.allCases) { diff in
                            HighScoreCard(difficulty: diff)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("High Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.teal)
                }
            }
        }
    }
}

struct HighScoreCard: View {
    let difficulty: MemoryDifficulty
    
    private var highScore: MemoryMatchHighScore? {
        let key = "memoryMatch.highscore.\(difficulty.rawValue)"
        if let data = UserDefaults.standard.data(forKey: key),
           let Decoded = try? JSONDecoder().decode(MemoryMatchHighScore.self, from: data) {
            return Decoded
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(difficulty.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)
            
            if let score = highScore {
                HStack {
                    ScoreStat(label: "Best Score", value: "\(score.score)", color: .teal)
                    Spacer()
                    ScoreStat(label: "Best Time", value: formatTime(score.time), color: .blue)
                    Spacer()
                    ScoreStat(label: "Least Moves", value: "\(score.moves)", color: .purple)
                }
            } else {
                Text("No scores yet")
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
        }
        .padding(20)
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .appShadow(Shadows.card)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct ScoreStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Colors.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
