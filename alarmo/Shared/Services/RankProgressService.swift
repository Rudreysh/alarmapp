import Foundation
import Combine

@MainActor
final class RankProgressService: ObservableObject {
    static let shared = RankProgressService()

    static let baseDailyCap = 100
    static let bonusDailyCap = 60
    static let hardDailyCap = 160
    static let dailyTargetXP = 80

    private let transactionsKey = "xp.transactions.v1"
    private let legacyMigratedKey = "xp.legacyPointsMigrated.v1"

    @Published private(set) var transactions: [XPTransaction] = []

    private init() {
        load()
        migrateLegacyPointsIfNeeded()
    }

    var totalXP: Int {
        transactions.reduce(0) { $0 + max(0, $1.amount) }
    }

    var currentRank: RankLevel {
        RankCatalog.rank(for: totalXP)
    }

    var nextRank: RankLevel? {
        RankCatalog.nextRank(after: currentRank)
    }

    var xpToNextRank: Int {
        guard let nextRank else { return max(0, RankCatalog.masteryXP - totalXP) }
        return max(0, nextRank.minXP - totalXP)
    }

    var rankProgress: Double {
        RankCatalog.progress(totalXP: totalXP, current: currentRank)
    }

    var todayXP: Int {
        breakdown(for: Date()).cappedTotalXP
    }

    var todayBreakdown: DailyXPBreakdown {
        breakdown(for: Date())
    }

    @discardableResult
    func addXP(source: XPSource, amount: Int, category: XPCategory, date: Date = Date()) -> XPGrantResult {
        let day = localDay(for: date)
        let uniqueId = "\(source.type.rawValue):\(source.sourceId):\(day)"
        let before = totalXP
        let oldRank = RankCatalog.rank(for: before)

        guard amount > 0 else {
            return skipped(amount: amount, before: before, oldRank: oldRank, reason: "non_positive")
        }

        guard !transactions.contains(where: { $0.id == uniqueId }) else {
            print("[XP] skipped duplicate source=\(source.type.rawValue) sourceId=\(source.sourceId) day=\(day)")
            return skipped(amount: amount, before: before, oldRank: oldRank, reason: "duplicate")
        }

        let awardedAmount = cappedAmount(for: amount, category: category, day: day)
        guard awardedAmount > 0 else {
            print("[XP] cap hit day=\(day)")
            return skipped(amount: amount, before: before, oldRank: oldRank, reason: "daily_cap")
        }

        let tx = XPTransaction(
            id: uniqueId,
            sourceType: source.type,
            sourceId: source.sourceId,
            category: category,
            amount: awardedAmount,
            awardedAt: date,
            localDay: day,
            alarmId: source.alarmId,
            sessionId: source.sessionId,
            habitId: source.habitId,
            metadata: source.metadata
        )

        transactions.insert(tx, at: 0)
        if transactions.count > 1200 {
            transactions = Array(transactions.prefix(1200))
        }
        save()

        let after = before + awardedAmount
        let newRank = RankCatalog.rank(for: after)
        if newRank.id > oldRank.id {
            print("[Rank] rank-up from=\(oldRank.displayName) to=\(newRank.displayName) totalXP=\(after)")
        }
        print("[XP] granted source=\(source.type.rawValue) amount=\(awardedAmount) category=\(category.rawValue) day=\(day)")

        return XPGrantResult(transaction: tx, requestedAmount: amount, awardedAmount: awardedAmount, totalXPBefore: before, totalXPAfter: after, oldRank: oldRank, newRank: newRank, skippedReason: nil)
    }

    func breakdown(for date: Date) -> DailyXPBreakdown {
        breakdown(for: localDay(for: date))
    }

    func localDay(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func cappedAmount(for amount: Int, category: XPCategory, day: String) -> Int {
        let current = breakdown(for: day)
        let hardRemaining = max(0, Self.hardDailyCap - current.cappedTotalXP)
        guard hardRemaining > 0 else { return 0 }

        let categoryRemaining: Int
        switch category {
        case .wake:
            categoryRemaining = max(0, 20 - current.baseWakeXP)
        case .habit:
            // Allow every completed habit to be rewarded; hard daily cap still applies.
            categoryRemaining = hardRemaining
        case .focus:
            categoryRemaining = max(0, 15 - current.baseFocusXP)
        case .missionBonus, .noSnoozeBonus, .streakBonus, .daily:
            categoryRemaining = max(0, Self.bonusDailyCap - bonusTotal(in: current))
        }

        return min(amount, hardRemaining, categoryRemaining)
    }

    private func breakdown(for day: String) -> DailyXPBreakdown {
        var result = DailyXPBreakdown(localDay: day)
        for tx in transactions where tx.localDay == day {
            switch tx.category {
            case .wake: result.baseWakeXP += tx.amount
            case .habit: result.baseHabitXP += tx.amount
            case .focus: result.baseFocusXP += tx.amount
            case .missionBonus: result.bonusMissionXP += tx.amount
            case .noSnoozeBonus: result.bonusNoSnoozeXP += tx.amount
            case .streakBonus, .daily: result.bonusStreakXP += tx.amount
            }
        }

        let total = result.baseWakeXP + result.baseHabitXP + result.baseFocusXP + bonusTotal(in: result)
        result.uncappedTotalXP = total
        result.cappedTotalXP = min(Self.hardDailyCap, total)
        result.capHit = total >= Self.hardDailyCap
        return result
    }

    private func bonusTotal(in breakdown: DailyXPBreakdown) -> Int {
        breakdown.bonusMissionXP + breakdown.bonusNoSnoozeXP + breakdown.bonusStreakXP
    }

    private func skipped(amount: Int, before: Int, oldRank: RankLevel, reason: String) -> XPGrantResult {
        XPGrantResult(transaction: nil, requestedAmount: amount, awardedAmount: 0, totalXPBefore: before, totalXPAfter: before, oldRank: oldRank, newRank: oldRank, skippedReason: reason)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: transactionsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: transactionsKey),
              let decoded = try? JSONDecoder().decode([XPTransaction].self, from: data) else {
            return
        }
        transactions = decoded
    }

    private func migrateLegacyPointsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: legacyMigratedKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: legacyMigratedKey) }
        let legacyPoints = max(0, SettingsStore.shared.points)
        guard legacyPoints > 0, transactions.isEmpty else { return }

        let day = localDay(for: Date())
        transactions = [
            XPTransaction(
                id: "manual:legacy_points_migration:\(day)",
                sourceType: .manual,
                sourceId: "legacy_points_migration",
                category: .daily,
                amount: legacyPoints,
                awardedAt: Date(),
                localDay: day,
                alarmId: nil,
                sessionId: nil,
                habitId: nil,
                metadata: ["reason": "legacy_points_migration"]
            )
        ]
        save()
    }
}
