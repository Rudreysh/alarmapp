import SwiftUI

struct StopwatchHistoryView: View {
    @ObservedObject var engine: StopwatchEngine
    
    var body: some View {
        VStack(spacing: 0) {
            if engine.sessions.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 60))
                        .foregroundColor(Colors.textTertiary)
                    Text("No sessions recorded yet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                    Text("Complete a stopwatch session to see your history here.")
                        .font(.system(size: 14))
                        .foregroundColor(Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                    Spacer()
                }
            } else {
                // Weekly Highlights
                VStack(spacing: 4) {
                    Text("THIS WEEK")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                    
                    Text(formatWeeklyTotal())
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(TimerPalette.accent)
                    
                    Text("+12% vs last week") // Placeholder stat
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.45))
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .padding(.bottom, 8)

                List {
                    ForEach(engine.sessions) { session in
                        SessionRow(session: session)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        engine.sessions.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.plain)
                .background(Color.clear)
            }
            
            if !engine.sessions.isEmpty {
                Button(action: {
                    withAnimation { engine.clearHistory() }
                }) {
                    Text("Clear All History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.25))
                        .padding()
                }
            }
        }
        .onAppear {
            engine.loadSessions()
        }
    }
    
    private func formatWeeklyTotal() -> String {
        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        
        let weeklyTotal = engine.sessions
            .filter { $0.startedAt >= startOfWeek }
            .reduce(0) { $0 + $1.totalDuration }
        
        return swFormatTime(weeklyTotal, showHundredths: false)
    }
}

struct SessionRow: View {
    let session: StopwatchSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)
                }
                
                Spacer()
                
                Text(swFormatTime(session.totalDuration, showHundredths: false))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(TimerPalette.accent)
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                    Text("\(session.lapCount) Laps")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Colors.textSecondary)
                
                if let best = session.bestLap {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                        Text("Best: \(swFormatTime(best, showHundredths: true))")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.45))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .contextMenu {
            ShareLink(item: generateShareText()) {
                Label("Share Session", systemImage: "square.and.arrow.up")
            }
            
            Button("Export as CSV") {
                // Placeholder for CSV export
            }
        }
    }
    
    private func generateShareText() -> String {
        var text = "⏱️ Alarmo Stopwatch Session\n"
        text += "Label: \(session.label)\n"
        text += "Date: \(session.startedAt.formatted())\n"
        text += "Duration: \(swFormatTime(session.totalDuration, showHundredths: false))\n"
        text += "Laps: \(session.lapCount)\n"
        if let best = session.bestLap {
            text += "Best Lap: \(swFormatTime(best, showHundredths: true))\n"
        }
        text += "\nTracked with Alarmo"
        return text
    }
}
