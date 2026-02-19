import SwiftUI

struct MyPointsView: View {
    @ObservedObject var pointsService = PointsService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Level Card
                    levelCard
                    
                    // Today's Summary
                    todaySummaryCard
                    
                    // How to Earn Points
                    howToEarnCard
                    
                    // Recent Activity
                    recentActivityCard
                }
                .padding()
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("My Points")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Level Card
    
    private var levelCard: some View {
        VStack(spacing: 20) {
            // Level Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 4)
                
                VStack(spacing: 2) {
                    Text("Lv")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(pointsService.currentLevel)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 4) {
                Text(pointsService.levelTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Text("\(pointsService.totalPoints) P")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Colors.cardSurface)
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * pointsService.levelProgress, height: 8)
                            .animation(.spring(response: 0.6), value: pointsService.levelProgress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("Lv \(pointsService.currentLevel)")
                        .font(.caption2)
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text("\(pointsService.pointsToNextLevel) pts to Lv \(pointsService.currentLevel + 1)")
                        .font(.caption2)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(24)
        .background(Colors.cardSurface.opacity(0.6))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
    
    // MARK: - Today's Summary
    
    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            HStack(spacing: 16) {
                todayStat(
                    icon: "plus.circle.fill",
                    color: .green,
                    value: "\(pointsService.todayPoints > 0 ? "+" : "")\(pointsService.todayPoints)",
                    label: "Earned"
                )
                
                todayStat(
                    icon: "list.bullet.circle.fill",
                    color: .blue,
                    value: "\(pointsService.todayTransactions.count)",
                    label: "Activities"
                )
                
                todayStat(
                    icon: "star.circle.fill",
                    color: .orange,
                    value: "\(pointsService.totalPoints)",
                    label: "Total"
                )
            }
        }
        .padding(20)
        .background(Colors.cardSurface.opacity(0.6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
    
    private func todayStat(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - How to Earn
    
    private var howToEarnCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Earn Points")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            VStack(spacing: 12) {
                earnRow(icon: "alarm.fill", color: .cyan, title: "Dismiss Alarm (no snooze)", points: "+\(PointsConfig.alarmDismissedClean)")
                earnRow(icon: "target", color: .green, title: "Complete Mission", points: "+\(PointsConfig.alarmDismissedWithMission)")
                earnRow(icon: "checkmark.circle.fill", color: .blue, title: "Complete Habit", points: "+\(PointsConfig.habitCompleted)")
                earnRow(icon: "flame.fill", color: .orange, title: "Streak Bonus (7 days)", points: "+\(PointsConfig.habitStreakMilestone7)")
                earnRow(icon: "checkmark.square.fill", color: .purple, title: "Complete Task", points: "+\(PointsConfig.taskCompleted)")
                earnRow(icon: "timer", color: .pink, title: "Focus (per 5 min)", points: "+\(PointsConfig.focusPerFiveMinutes)")
                earnRow(icon: "sun.max.fill", color: .yellow, title: "Daily Check-in", points: "+\(PointsConfig.dailyLogin)")
                
                Divider().background(Colors.cardStroke)
                
                earnRow(icon: "zzz", color: .red, title: "Snooze Penalty", points: "\(PointsConfig.alarmSnoozePenalty)")
            }
        }
        .padding(20)
        .background(Colors.cardSurface.opacity(0.6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
    
    private func earnRow(icon: String, color: Color, title: String, points: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(8)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Colors.textPrimary)
            
            Spacer()
            
            Text(points)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(points.hasPrefix("-") ? .red : .green)
        }
    }
    
    // MARK: - Recent Activity
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            if pointsService.recentTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(Colors.textSecondary)
                    
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)
                    
                    Text("Start by dismissing an alarm or completing a habit to earn your first points!")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pointsService.recentTransactions.prefix(30).enumerated()), id: \.element.id) { index, tx in
                        transactionRow(tx)
                        
                        if index < min(29, pointsService.recentTransactions.count - 1) {
                            Divider()
                                .background(Colors.cardStroke)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Colors.cardSurface.opacity(0.6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
    
    private func transactionRow(_ tx: PointsTransaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tx.reason.icon)
                .font(.system(size: 14))
                .foregroundColor(tx.amount >= 0 ? .green : .red)
                .frame(width: 32, height: 32)
                .background((tx.amount >= 0 ? Color.green : Color.red).opacity(0.12))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.reason.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                
                HStack(spacing: 4) {
                    if let name = tx.entityName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                    
                    Text("·")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                    
                    Text(relativeTime(tx.date))
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            
            Spacer()
            
            Text("\(tx.amount > 0 ? "+" : "")\(tx.amount)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tx.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 10)
    }
    
    private func relativeTime(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 86400 * 7 { return "\(Int(diff / 86400))d ago" }
        
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
