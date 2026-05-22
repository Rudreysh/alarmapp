import SwiftUI

struct RankProgressPreviewView: View {
    @ObservedObject private var rankService = RankProgressService.shared
    @State private var showTips = false

    let currentXP: Int
    let completedTasks: Int
    let streakDays: Int

    private var rank: RankLevel { rankService.currentRank }
    private var nextRank: RankLevel? { rankService.nextRank }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    rankHero
                    transitionCard
                    todayPanel
                    ladder
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, AppConstants.tabBarHeight + 24)
            }
        }
        .navigationTitle("Rank")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rankHero: some View {
        VStack(spacing: 12) {
            Image(rank.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 178, height: 178)
                .shadow(color: rank.tier.accentColor.opacity(0.35), radius: 18, x: 0, y: 8)

            Text(rank.displayName.uppercased())
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(rank.tier.accentColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text("\(rankService.totalXP) XP")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var transitionCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                rankNode(rank: rank, subtitle: "XP: \(rankService.totalXP)", locked: false)
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Colors.textSecondary)
                if let nextRank {
                    rankNode(rank: nextRank, subtitle: "\(rankService.xpToNextRank) XP needed", locked: true)
                } else {
                    rankNode(rank: rank, subtitle: "Mastery target", locked: false)
                }
            }

            progressBar(progress: rankService.rankProgress, tint: rank.tier.accentColor, height: 10)
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private func rankNode(rank: RankLevel, subtitle: String, locked: Bool) -> some View {
        VStack(spacing: 8) {
            Text(rank.displayName.uppercased())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(rank.tier.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ZStack(alignment: .bottomTrailing) {
                Image(rank.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .opacity(locked ? 0.45 : 1)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.black)
                        .padding(5)
                        .background(Circle().fill(Color.yellow))
                }
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayPanel: some View {
        let breakdown = rankService.todayBreakdown
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text("\(breakdown.cappedTotalXP)/\(RankProgressService.dailyTargetXP) XP")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Color.yellow)
            }

            progressBar(
                progress: min(1, Double(breakdown.cappedTotalXP) / Double(RankProgressService.dailyTargetXP)),
                tint: Color.yellow,
                height: 9
            )

            HStack(spacing: 10) {
                statCard(title: "STREAK", value: "\(streakDays) days")
                completedStatCard
            }
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .sheet(isPresented: $showTips) {
            tipsSheet
        }
    }

    private var ladder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Ranks")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)

            LazyVStack(spacing: 10) {
                ForEach(RankCatalog.all) { item in
                    let unlocked = rankService.totalXP >= item.minXP
                    HStack(spacing: 12) {
                        Image(item.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .opacity(unlocked ? 1 : 0.35)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(unlocked ? Colors.textPrimary : Colors.textSecondary)
                            Text(unlocked ? "Unlocked" : "\(item.minXP) XP required")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(unlocked ? item.tier.accentColor : Colors.textSecondary)
                        }

                        Spacer()

                        if item.id == rank.id {
                            Text("CURRENT")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.yellow))
                        } else if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(Colors.cardSurface.opacity(item.id == rank.id ? 1 : 0.55))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(item.id == rank.id ? item.tier.accentColor : Colors.cardStroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Colors.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Colors.bgSecondary.opacity(0.55))
        .cornerRadius(14)
    }

    private var completedStatCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMPLETED")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Colors.textSecondary)
            Text("\(completedTasks)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Colors.bgSecondary.opacity(0.55))
        .cornerRadius(14)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showTips = true
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.accentBlue)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var tipsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("XP Tips")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)

                tipRow("Stop alarm without snooze", "+5 XP")
                tipRow("Complete one focus session", "+7 XP")
                tipRow("Finish planned habits", "+4 XP each")

                Spacer()
            }
            .padding(20)
            .background(Colors.bgPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTips = false }
                        .foregroundColor(Colors.accentBlue)
                }
            }
        }
    }

    private func tipRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(Color.yellow)
        }
    }

    private func progressBar(progress: Double, tint: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Colors.cardStroke.opacity(0.65))
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}
