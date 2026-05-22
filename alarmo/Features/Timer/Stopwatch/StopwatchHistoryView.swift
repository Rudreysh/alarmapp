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
                let weeklyDelta = weeklyDeltaLabel()
                VStack(spacing: 4) {
                    Text("THIS WEEK")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                    
                    Text(formatWeeklyTotal())
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(TimerPalette.accent)
                    
                    Text(weeklyDelta.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(weeklyDelta.color)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Colors.cardSurface)
                .padding(.bottom, 8)

                List {
                    ForEach(engine.sessions) { session in
                        SessionRow(session: session)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        engine.deleteSessions(at: indexSet)
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

    private func weeklyDeltaLabel() -> (text: String, color: Color) {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek

        let thisWeek = engine.sessions
            .filter { $0.startedAt >= startOfWeek }
            .reduce(0) { $0 + $1.totalDuration }

        let lastWeek = engine.sessions
            .filter { $0.startedAt >= startOfLastWeek && $0.startedAt < startOfWeek }
            .reduce(0) { $0 + $1.totalDuration }

        if lastWeek <= 0 {
            if thisWeek > 0 {
                return ("New activity this week", Color(red: 0.20, green: 0.78, blue: 0.45))
            }
            return ("No activity yet", Colors.textTertiary)
        }

        let delta = ((thisWeek - lastWeek) / lastWeek) * 100
        let sign = delta >= 0 ? "+" : ""
        let label = "\(sign)\(Int(delta.rounded()))% vs last week"
        let labelColor = delta >= 0 ? Color(red: 0.20, green: 0.78, blue: 0.45) : Color(red: 0.90, green: 0.25, blue: 0.25)
        return (label, labelColor)
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
                        .foregroundColor(Colors.textPrimary)
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
                .fill(Colors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
        )
        .contextMenu {
            ShareLink(item: generateShareText()) {
                Label("Share Session", systemImage: "square.and.arrow.up")
            }
            
            ShareLink(item: generateCSVText()) {
                Label("Export as CSV", systemImage: "tablecells")
            }
        }
    }
    
    private func generateShareText() -> String {
        var text = "⏱️ Awayk Stopwatch Session\n"
        text += "Label: \(session.label)\n"
        text += "Date: \(session.startedAt.formatted())\n"
        text += "Duration: \(swFormatTime(session.totalDuration, showHundredths: false))\n"
        text += "Laps: \(session.lapCount)\n"
        if let best = session.bestLap {
            text += "Best Lap: \(swFormatTime(best, showHundredths: true))\n"
        }
        text += "\nTracked with Awayk"
        return text
    }

    private func generateCSVText() -> String {
        let dateText = session.startedAt.formatted(date: .numeric, time: .shortened)
        let durationText = swFormatTime(session.totalDuration, showHundredths: false)
        let bestLapText = session.bestLap.map { swFormatTime($0, showHundredths: true) } ?? ""
        return """
        label,started_at,total_duration,lap_count,best_lap
        \(session.label),\(dateText),\(durationText),\(session.lapCount),\(bestLapText)
        """
    }
}
