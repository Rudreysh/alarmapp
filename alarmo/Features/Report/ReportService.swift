import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums & Models

enum ReportDomain: String, CaseIterable, Identifiable, Sendable {
    case alarms = "Alarms"
    case habits = "Habits"
    case pomodoro = "Pomodoro"
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .habits: return "flame"
        case .pomodoro: return "timer"
        case .alarms: return "bell.badge"
        }
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }
}

enum ReportTrendGrouping: String, CaseIterable, Identifiable, Sendable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"

    var id: String { rawValue }
}

struct ReportMetrics: Sendable {
    // Universal
    var completionRate: Double = 0 // 0.0 - 1.0
    var totalDone: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var dailyAverage: Double = 0
    var perfectDays: Int = 0
    
    // Progress-based Rates
    var todayRate: Double = 0
    var monthRate: Double = 0
    var habitValueTotal: Double = 0
    var habitValueDailyAverage: Double = 0
    var habitActiveDays: Int = 0

    // Pomodoro specific
    var startedCount: Int = 0
    var completedCount: Int = 0
    var interruptedCount: Int = 0
    var focusMinutes: Double = 0
    
    // Alarms specific
    var firedCount: Int = 0
    var dismissedCount: Int = 0
    var snoozeCount: Int = 0
    var missedCount: Int = 0
    var avgDismissTime: TimeInterval = 0
    var totalSnoozeTime: TimeInterval = 0
    var avgSnoozeCount: Double = 0
    var wakeupConsistency: Double = 0 // 0-1, lower variation in dismiss time is better
}

struct TrendPoint: Identifiable, Sendable, Equatable {
    var id = UUID()
    var date: Date
    var label: String
    var value: Double
    var isProjected: Bool = false
}

// MARK: - Report Service

@MainActor
class ReportService {
    private let modelContext: ModelContext
    private let calendar = Calendar.current
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public API
    
    func generateReport(
        domain: ReportDomain,
        period: ReportPeriod,
        referenceDate: Date,
        trendGrouping: ReportTrendGrouping? = nil,
        itemId: UUID? = nil
    ) async -> (ReportMetrics, [TrendPoint], [Date: Double]) {
        let (startDate, endDate) = calculateDateRange(period: period, referenceDate: referenceDate)
        let grouping = trendGrouping ?? defaultTrendGrouping(for: period)
        
        var metrics = ReportMetrics()
        var trendPoints: [TrendPoint] = []
        var heatmap: [Date: Double] = [:]

        if domain == .habits {
            await syncHealthHabitLogs(startDate: startDate, endDate: endDate, itemId: itemId)
        }
        
        // 1. Fetch Events
        let events = await fetchEvents(domain: domain, startDate: startDate, endDate: endDate, itemId: itemId)
        
        // 2. Domain Specific Logic
        switch domain {
        case .habits:
            await computeHabitMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: startDate, endDate: endDate, referenceDate: referenceDate, period: period, trendGrouping: grouping, itemId: itemId)
        case .pomodoro:
            await computePomodoroMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: startDate, endDate: endDate, referenceDate: referenceDate, period: period, trendGrouping: grouping)
        case .alarms:
            await computeAlarmMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: startDate, endDate: endDate, period: period, trendGrouping: grouping, itemId: itemId)
        }
        
        return (metrics, trendPoints, heatmap)
    }

    func generateDayReport(domain: ReportDomain, date: Date, itemId: UUID? = nil) async -> ReportMetrics {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        if domain == .habits {
            await syncHealthHabitLogs(startDate: dayStart, endDate: dayEnd, itemId: itemId)
        }

        let events = await fetchEvents(domain: domain, startDate: dayStart, endDate: dayEnd, itemId: itemId)

        var metrics = ReportMetrics()
        var trendPoints: [TrendPoint] = []
        var heatmap: [Date: Double] = [:]

        switch domain {
        case .habits:
            await computeHabitMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: dayStart, endDate: dayEnd, referenceDate: dayStart, period: .week, trendGrouping: .day, itemId: itemId)
        case .pomodoro:
            await computePomodoroMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: dayStart, endDate: dayEnd, referenceDate: dayStart, period: .week, trendGrouping: .day)
        case .alarms:
            await computeAlarmMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: dayStart, endDate: dayEnd, period: .week, trendGrouping: .day, itemId: itemId)
        }

        metrics.dailyAverage = Double(metrics.totalDone)
        return metrics
    }

    func generateHabitConsistencySeries(
        itemId: UUID? = nil,
        referenceDate: Date = Date(),
        lookbackDays: Int = 540
    ) async -> [Date: Double] {
        let habits = scopedHabitItems(itemId: itemId)
        guard !habits.isEmpty else { return [:] }

        let endDay = calendar.startOfDay(for: referenceDate)
        let fallbackStart = calendar.date(byAdding: .day, value: -(max(lookbackDays, 1) - 1), to: endDay) ?? endDay
        let earliestHabitDay = habits.map { calendar.startOfDay(for: $0.createdAt) }.min() ?? endDay
        let startDay = max(fallbackStart, earliestHabitDay)
        guard startDay <= endDay else { return [:] }

        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        await syncHealthHabitLogs(startDate: startDay, endDate: endExclusive, itemId: itemId)

        var series: [Date: Double] = [:]
        var cursor = startDay
        while cursor <= endDay {
            let dayStart = calendar.startOfDay(for: cursor)
            let result = daySuccess(for: dayStart, items: habits)
            series[dayStart] = result.applicableCount > 0 ? result.rate : 0
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDay
        }
        return series
    }
    
    // MARK: - Internal Computation
    
    private func fetchEvents(domain: ReportDomain, startDate: Date, endDate: Date, itemId: UUID?) async -> [ActivityEvent] {
        let activityDomain: ActivityDomain = {
            switch domain {
            case .habits: return .habit
            case .pomodoro: return .pomodoro
            case .alarms: return .alarm
            }
        }()
        
        let descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate<ActivityEvent> { event in
                event.timestampUTC >= startDate && event.timestampUTC < endDate
            }
        )
        
        guard let allEvents = try? modelContext.fetch(descriptor) else { return [] }
        
        // In-memory filter for domain and itemId
        return allEvents.filter { event in
            event.domain == activityDomain && (itemId == nil || event.entityId == itemId)
        }
    }

    private func scopedHabitItems(itemId: UUID?) -> [PlanItem] {
        let descriptor = FetchDescriptor<PlanItem>()
        return (try? modelContext.fetch(descriptor))?.filter { item in
            item.type == .habit &&
            item.parentTask == nil &&
            (itemId == nil || item.id == itemId)
        } ?? []
    }
    
    private func computeHabitMetrics(events _: [ActivityEvent], metrics: inout ReportMetrics, trendPoints: inout [TrendPoint], heatmap: inout [Date: Double], startDate: Date, endDate: Date, referenceDate: Date, period: ReportPeriod, trendGrouping: ReportTrendGrouping, itemId: UUID?) async {
        let type: PlanItemType = .habit
        let descriptor = FetchDescriptor<PlanItem>()
        let scopedItems = (try? modelContext.fetch(descriptor))?.filter { item in
            item.type == type && item.parentTask == nil && (itemId == nil || item.id == itemId)
        } ?? []

        let effectivePeriodEnd = cappedEndDate(for: endDate)
        let daysCount = max(1, calendar.dateComponents([.day], from: startDate, to: effectivePeriodEnd).day ?? 1)

        guard !scopedItems.isEmpty else {
            metrics.totalDone = 0
            metrics.dailyAverage = 0
            metrics.completionRate = 0
            metrics.todayRate = 0
            metrics.monthRate = 0
            metrics.perfectDays = 0
            metrics.habitValueTotal = 0
            metrics.habitValueDailyAverage = 0
            metrics.habitActiveDays = 0
            trendPoints = []
            return
        }

        if let id = itemId,
           let item = scopedItems.first(where: { $0.id == id }) {
            metrics.currentStreak = calculateHabitStreak(for: item)
            metrics.bestStreak = metrics.currentStreak
        }

        // Period-wide completion/heatmap based on per-day item success.
        var dayCursor = startDate
        var dayRates: [Double] = []
        var dailySuccessCounts: [Date: Double] = [:]
        var perfectDays = 0
        var totalSuccesses = 0
        var totalTrackedValue = 0.0
        var activeDays = 0
        while dayCursor < effectivePeriodEnd {
            let result = daySuccess(for: dayCursor, items: scopedItems)
            let dayValue = dayTrackedValue(for: dayCursor, items: scopedItems)
            let hasActivity = dayHasActivity(for: dayCursor, items: scopedItems)
            let dayStart = calendar.startOfDay(for: dayCursor)

            if result.applicableCount > 0 {
                dayRates.append(result.rate)
                heatmap[dayStart] = result.rate
                dailySuccessCounts[dayStart] = Double(result.successCount)
                totalSuccesses += result.successCount
                if result.successCount == result.applicableCount {
                    perfectDays += 1
                }
            } else {
                heatmap[dayStart] = 0
                dailySuccessCounts[dayStart] = 0
            }

            totalTrackedValue += dayValue
            if hasActivity {
                activeDays += 1
            }
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
        }

        metrics.totalDone = totalSuccesses
        metrics.dailyAverage = Double(totalSuccesses) / Double(daysCount)
        metrics.habitValueTotal = totalTrackedValue
        metrics.habitValueDailyAverage = totalTrackedValue / Double(daysCount)
        metrics.habitActiveDays = activeDays
        metrics.completionRate = dayRates.isEmpty ? 0 : dayRates.reduce(0, +) / Double(dayRates.count)
        metrics.perfectDays = perfectDays

        // "Today rate" uses the currently selected reference day to match the report screen context.
        let referenceDay = calendar.startOfDay(for: referenceDate)
        metrics.todayRate = daySuccess(for: referenceDay, items: scopedItems).rate

        // Month rate for the month of the current reference date.
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
        let monthEndExclusive = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let nowDay = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(referenceDate, equalTo: Date(), toGranularity: .month)
        let monthCutoffExclusive = isCurrentMonth
            ? min(monthEndExclusive, calendar.date(byAdding: .day, value: 1, to: nowDay)!)
            : monthEndExclusive

        var monthCursor = monthStart
        var monthRates: [Double] = []
        while monthCursor < monthCutoffExclusive {
            let result = daySuccess(for: monthCursor, items: scopedItems)
            if result.applicableCount > 0 {
                monthRates.append(result.rate)
            }
            monthCursor = calendar.date(byAdding: .day, value: 1, to: monthCursor)!
        }
        metrics.monthRate = monthRates.isEmpty ? 0 : monthRates.reduce(0, +) / Double(monthRates.count)

        trendPoints = generateHabitTrendPoints(
            dailySuccessCounts: dailySuccessCounts,
            startDate: startDate,
            endDate: endDate,
            period: period,
            grouping: trendGrouping
        )
    }

    private func daySuccess(for day: Date, items: [PlanItem]) -> (rate: Double, successCount: Int, applicableCount: Int) {
        var applicableCount = 0
        var successCount = 0

        for item in items {
            guard isItemActive(item, on: day) else { continue }
            guard occurs(item: item, on: day) else { continue }
            applicableCount += 1
            if item.isGoalMet(on: day) {
                successCount += 1
            }
        }

        guard applicableCount > 0 else {
            return (0, 0, 0)
        }
        return (Double(successCount) / Double(applicableCount), successCount, applicableCount)
    }

    private func dayTrackedValue(for day: Date, items: [PlanItem]) -> Double {
        items.reduce(0) { partial, item in
            guard isItemActive(item, on: day), occurs(item: item, on: day) else {
                return partial
            }
            return partial + item.currentValue(on: day)
        }
    }

    private func dayHasActivity(for day: Date, items: [PlanItem]) -> Bool {
        for item in items {
            guard isItemActive(item, on: day), occurs(item: item, on: day) else {
                continue
            }

            let hasNonSkippedLog = item.completionLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: day) && log.note != CompletionLog.skippedMarker
            }
            if hasNonSkippedLog || item.currentValue(on: day) > 0 {
                return true
            }
        }
        return false
    }

    private func calculateHabitStreak(for item: PlanItem) -> Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            if item.isGoalMet(on: checkDate) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previous
                continue
            }

            if calendar.isDateInToday(checkDate) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previous
                continue
            }
            break
        }
        return streak
    }

    private func occurs(item: PlanItem, on day: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: day)
        let createdDay = calendar.startOfDay(for: item.createdAt)
        if createdDay > startOfDay {
            return false
        }
        
        if item.repeatRule.frequency != .none {
            return item.repeatRule.occurs(on: startOfDay, createdAt: item.createdAt)
        }
        
        if !item.anytime, let scheduledDate = item.scheduledDate {
            return calendar.isDate(scheduledDate, inSameDayAs: startOfDay)
        }
        
        // Non-repeating anytime items are treated as one-day entries on creation day.
        return calendar.isDate(createdDay, inSameDayAs: startOfDay)
    }
    
    private func isItemActive(_ item: PlanItem, on day: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        if dayStart < calendar.startOfDay(for: item.createdAt) {
            return false
        }
        
        // Preferred archival boundary; fallback to updatedAt for pre-migration archived items.
        let archiveBoundary = item.archivedAt ?? (item.isArchived ? item.updatedAt : nil)
        if let archivedDate = archiveBoundary, dayStart > calendar.startOfDay(for: archivedDate) {
            return false
        }
        
        return true
    }
    
    private func cappedEndDate(for endDate: Date) -> Date {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return min(endDate, startOfTomorrow)
    }

    private func computePomodoroMetrics(events: [ActivityEvent], metrics: inout ReportMetrics, trendPoints: inout [TrendPoint], heatmap: inout [Date: Double], startDate: Date, endDate: Date, referenceDate: Date, period: ReportPeriod, trendGrouping: ReportTrendGrouping) async {
        let pomodoroEvents = events.filter { $0.domain == .pomodoro }

        metrics.startedCount = pomodoroEvents.filter { $0.status == .started }.count
        metrics.completedCount = pomodoroEvents.filter { $0.status == .completed }.count
        metrics.interruptedCount = pomodoroEvents.filter { $0.status == .interrupted }.count
        metrics.totalDone = metrics.completedCount
        metrics.focusMinutes = pomodoroEvents
            .filter { $0.status == .completed }
            .reduce(0) { partial, event in
                partial + (event.value ?? 0) / 60.0
            }

        let attempts = max(metrics.startedCount, metrics.completedCount + metrics.interruptedCount)
        metrics.completionRate = attempts > 0 ? Double(metrics.completedCount) / Double(attempts) : 0

        let effectivePeriodEnd = cappedEndDate(for: endDate)
        let daysCount = max(1, calendar.dateComponents([.day], from: startDate, to: effectivePeriodEnd).day ?? 1)
        metrics.dailyAverage = Double(metrics.completedCount) / Double(daysCount)

        // Heatmap intensity = completed focus sessions per day.
        var dayCursor = startDate
        while dayCursor < effectivePeriodEnd {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
            let dayDone = pomodoroEvents.filter {
                $0.status == .completed &&
                $0.timestampUTC >= dayCursor &&
                $0.timestampUTC < dayEnd
            }.count
            heatmap[dayCursor] = Double(dayDone)
            dayCursor = dayEnd
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let referenceDayEnd = calendar.date(byAdding: .day, value: 1, to: referenceDay)!
        let dayAttempts = pomodoroEvents.filter {
            ($0.status == .started || $0.status == .completed || $0.status == .interrupted) &&
            $0.timestampUTC >= referenceDay &&
            $0.timestampUTC < referenceDayEnd
        }.count
        let dayCompleted = pomodoroEvents.filter {
            $0.status == .completed &&
            $0.timestampUTC >= referenceDay &&
            $0.timestampUTC < referenceDayEnd
        }.count
        metrics.todayRate = dayAttempts > 0 ? Double(dayCompleted) / Double(dayAttempts) : 0

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let monthAttempts = pomodoroEvents.filter {
            ($0.status == .started || $0.status == .completed || $0.status == .interrupted) &&
            $0.timestampUTC >= monthStart &&
            $0.timestampUTC < monthEnd
        }.count
        let monthCompleted = pomodoroEvents.filter {
            $0.status == .completed &&
            $0.timestampUTC >= monthStart &&
            $0.timestampUTC < monthEnd
        }.count
        metrics.monthRate = monthAttempts > 0 ? Double(monthCompleted) / Double(monthAttempts) : 0

        // Streak = consecutive days with at least one completed focus session.
        var streak = 0
        var best = 0
        var scanDate = calendar.startOfDay(for: Date())
        while scanDate >= startDate {
            let next = calendar.date(byAdding: .day, value: 1, to: scanDate)!
            let done = pomodoroEvents.contains {
                $0.status == .completed &&
                $0.timestampUTC >= scanDate &&
                $0.timestampUTC < next
            }
            if done {
                streak += 1
                best = max(best, streak)
            } else {
                if scanDate == calendar.startOfDay(for: Date()) {
                    // Allow streak to continue from yesterday if today has no completion yet.
                } else {
                    streak = 0
                }
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: scanDate) else { break }
            scanDate = prev
        }
        metrics.currentStreak = streak
        metrics.bestStreak = max(best, streak)
        metrics.perfectDays = heatmap.values.filter { $0 > 0 }.count

        trendPoints = generateTrendPoints(
            events: pomodoroEvents,
            domain: .pomodoro,
            startDate: startDate,
            endDate: endDate,
            period: period,
            grouping: trendGrouping
        )
    }
    
    private func computeAlarmMetrics(events: [ActivityEvent], metrics: inout ReportMetrics, trendPoints: inout [TrendPoint], heatmap: inout [Date: Double], startDate: Date, endDate: Date, period: ReportPeriod, trendGrouping: ReportTrendGrouping, itemId: UUID?) async {
        let alarmEvents = events.filter { $0.domain == .alarm }
        
        metrics.firedCount = alarmEvents.filter { $0.status == .fired }.count
        metrics.dismissedCount = alarmEvents.filter { $0.status == .dismissed }.count
        metrics.snoozeCount = alarmEvents.filter { $0.status == .snoozed }.count
        metrics.missedCount = alarmEvents.filter { $0.status == .missed }.count
        metrics.totalDone = metrics.dismissedCount
        
        // Advanced Alarm Stats Logic
        var dismissDurations: [TimeInterval] = []
        var snoozeTotalSeconds: TimeInterval = 0
        
        let sortedEvents = alarmEvents.sorted { $0.timestampUTC < $1.timestampUTC }
        
        for (index, event) in sortedEvents.enumerated() {
            if event.status == .fired {
                // Find next interaction (dismissed, snoozed, or missed) within a reasonable window (e.g., 1 hour)
                let nextInteraction = sortedEvents.dropFirst(index + 1).first { 
                    $0.entityId == event.entityId && ($0.status == .dismissed || $0.status == .snoozed || $0.status == .missed) 
                }
                
                if let interaction = nextInteraction {
                    let duration = interaction.timestampUTC.timeIntervalSince(event.timestampUTC)
                    if duration < 3600 { // Ignore if it's more than an hour (likely separate events)
                        dismissDurations.append(duration)
                    }
                }
            } else if event.status == .snoozed {
                if let durationStr = event.metadata?["durationMinutes"], let mins = Double(durationStr) {
                    snoozeTotalSeconds += mins * 60
                }
            }
        }
        
        if !dismissDurations.isEmpty {
            metrics.avgDismissTime = dismissDurations.reduce(0, +) / Double(dismissDurations.count)
            
            // Wake-up Consistency: Calculate variance of dismiss times
            // 1.0 = perfect consistency, 0.0 = high variation
            let mean = metrics.avgDismissTime
            let variance = dismissDurations.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(dismissDurations.count)
            let stdDev = sqrt(variance)
            metrics.wakeupConsistency = max(0, 1.0 - (stdDev / 300.0)) // normalize: 5 mins variation is considered low consistency
        }
        
        metrics.totalSnoozeTime = snoozeTotalSeconds
        if metrics.firedCount > 0 {
            metrics.avgSnoozeCount = Double(metrics.snoozeCount) / Double(metrics.firedCount)
            metrics.completionRate = Double(metrics.dismissedCount) / Double(metrics.firedCount)
        }
        
        // Heatmap for alarms usually means count of fires
        for event in alarmEvents where event.status == .fired {
            let day = calendar.startOfDay(for: event.timestampUTC)
            heatmap[day] = (heatmap[day] ?? 0) + 1
        }
        
        trendPoints = generateTrendPoints(events: alarmEvents, domain: .alarms, startDate: startDate, endDate: endDate, period: period, grouping: trendGrouping)
    }
    
    // MARK: - Helpers
    
    private func calculateDateRange(period: ReportPeriod, referenceDate: Date) -> (Date, Date) {
        let startOfRef = calendar.startOfDay(for: referenceDate)
        var start: Date
        var end: Date
        
        switch period {
        case .week:
            var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfRef)
            comps.weekday = calendar.firstWeekday
            start = calendar.date(from: comps)!
            end = calendar.date(byAdding: .day, value: 7, to: start)!
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: startOfRef)
            start = calendar.date(from: comps)!
            end = calendar.date(byAdding: .month, value: 1, to: start)!
        case .year:
            let comps = calendar.dateComponents([.year], from: startOfRef)
            start = calendar.date(from: comps)!
            end = calendar.date(byAdding: .year, value: 1, to: start)!
        }
        return (start, end)
    }
    
    private func generateTrendPoints(events: [ActivityEvent], domain: ReportDomain, startDate: Date, endDate: Date, period: ReportPeriod, grouping: ReportTrendGrouping) -> [TrendPoint] {
        let resolvedGrouping = sanitizeGrouping(grouping, for: period)
        var points: [TrendPoint] = []
        var cursor = startDate

        while cursor < endDate {
            let bucketEnd = nextBucketDate(from: cursor, grouping: resolvedGrouping)
            let bucketEvents = events.filter { $0.timestampUTC >= cursor && $0.timestampUTC < bucketEnd }
            let value = trendValue(for: bucketEvents, domain: domain)
            points.append(
                TrendPoint(
                    date: cursor,
                    label: trendLabel(for: cursor, grouping: resolvedGrouping),
                    value: value
                )
            )
            cursor = bucketEnd
        }
        return points
    }

    private func generateHabitTrendPoints(
        dailySuccessCounts: [Date: Double],
        startDate: Date,
        endDate: Date,
        period: ReportPeriod,
        grouping: ReportTrendGrouping
    ) -> [TrendPoint] {
        let resolvedGrouping = sanitizeGrouping(grouping, for: period)
        var points: [TrendPoint] = []
        var cursor = startDate

        while cursor < endDate {
            let bucketEnd = nextBucketDate(from: cursor, grouping: resolvedGrouping)
            var bucketTotal = 0.0
            var dayCursor = cursor
            while dayCursor < bucketEnd {
                let dayStart = calendar.startOfDay(for: dayCursor)
                bucketTotal += dailySuccessCounts[dayStart] ?? 0
                dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
            }

            points.append(
                TrendPoint(
                    date: cursor,
                    label: trendLabel(for: cursor, grouping: resolvedGrouping),
                    value: bucketTotal
                )
            )
            cursor = bucketEnd
        }

        return points
    }

    private func trendValue(for bucketEvents: [ActivityEvent], domain: ReportDomain) -> Double {
        switch domain {
        case .alarms:
            return Double(bucketEvents.filter { $0.status == .fired }.count)
        case .habits:
            return Double(bucketEvents.filter { $0.status == .success }.count)
        case .pomodoro:
            return Double(bucketEvents.filter { $0.status == .completed }.count)
        }
    }

    func availableTrendGroupings(for period: ReportPeriod) -> [ReportTrendGrouping] {
        switch period {
        case .week:
            return [.day, .week]
        case .month:
            return [.day, .week]
        case .year:
            return [.week, .month]
        }
    }

    func defaultTrendGrouping(for period: ReportPeriod) -> ReportTrendGrouping {
        switch period {
        case .week:
            return .day
        case .month:
            return .week
        case .year:
            return .month
        }
    }

    private func sanitizeGrouping(_ grouping: ReportTrendGrouping, for period: ReportPeriod) -> ReportTrendGrouping {
        let allowed = availableTrendGroupings(for: period)
        return allowed.contains(grouping) ? grouping : defaultTrendGrouping(for: period)
    }

    private func nextBucketDate(from date: Date, grouping: ReportTrendGrouping) -> Date {
        switch grouping {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date)!
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date)!
        }
    }

    private func trendLabel(for date: Date, grouping: ReportTrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch grouping {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("d")
        case .week:
            let week = calendar.component(.weekOfYear, from: date)
            return "W\(week)"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMM")
        }
        return formatter.string(from: date)
    }

    private func syncHealthHabitLogs(startDate: Date, endDate: Date, itemId: UUID?) async {
        guard HealthKitManager.shared.isHealthDataAvailable else {
            return
        }

        let descriptor = FetchDescriptor<PlanItem>()
        let habits = (try? modelContext.fetch(descriptor))?.filter { item in
            item.type == .habit &&
            item.parentTask == nil &&
            (itemId == nil || item.id == itemId)
        } ?? []
        guard !habits.isEmpty else { return }

        let syncStart = calendar.startOfDay(for: startDate)
        let syncEnd = cappedEndDate(for: endDate)

        var hasChanges = false
        for habit in habits {
            guard let trackingType = inferredTrackingType(for: habit) else { continue }
            guard isAuthorizedForTracking(trackingType, habit: habit) else { continue }

            var dayCursor = syncStart
            while dayCursor < syncEnd {
                let fetchedValue = await fetchHealthValue(for: habit, trackingType: trackingType, date: dayCursor)
                if updateHealthBackedHabitLog(habit, value: fetchedValue, for: dayCursor) {
                    hasChanges = true
                }
                dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
            }
        }

        if hasChanges {
            try? modelContext.save()
        }
    }

    private func fetchHealthValue(for habit: PlanItem, trackingType: String, date: Date) async -> Double {
        switch trackingType {
        case "steps":
            return await HealthKitManager.shared.fetchSteps(for: date)
        case "distance":
            let meters = await HealthKitManager.shared.fetchDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "running":
            if habit.goalUnit.lowercased().contains("step") {
                return await HealthKitManager.shared.fetchSteps(for: date)
            }
            let meters = await HealthKitManager.shared.fetchDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "cycling":
            let meters = await HealthKitManager.shared.fetchCyclingDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "water":
            let milliliters = await HealthKitManager.shared.fetchWaterIntake(for: date)
            return convertWater(milliliters, to: habit.goalUnit)
        case "sleep":
            let seconds = await HealthKitManager.shared.fetchSleep(for: date)
            if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                return seconds / 3600.0
            }
            return seconds / 60.0
        case "standing":
            let minutes = await HealthKitManager.shared.fetchStandMinutes(for: date)
            if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                return minutes / 60.0
            }
            return minutes
        case "mindfulness":
            let seconds = await HealthKitManager.shared.fetchMindfulMinutes(for: date)
            return seconds / 60.0
        default:
            return 0
        }
    }

    private func isAuthorizedForTracking(_ trackingType: String, habit: PlanItem) -> Bool {
        switch trackingType {
        case "steps":
            return HealthKitManager.shared.isAuthorized(for: "steps")
        case "distance":
            return HealthKitManager.shared.isAuthorized(for: "distance")
        case "running":
            if habit.goalUnit.lowercased().contains("step") {
                return HealthKitManager.shared.isAuthorized(for: "steps")
            }
            return HealthKitManager.shared.isAuthorized(for: "distance")
        case "cycling":
            return HealthKitManager.shared.isAuthorized(for: "cycling")
        case "water":
            return HealthKitManager.shared.isAuthorized(for: "water")
        case "sleep":
            return HealthKitManager.shared.isAuthorized(for: "sleep")
        case "standing":
            return HealthKitManager.shared.isAuthorized(for: "standing")
        case "mindfulness":
            return HealthKitManager.shared.isAuthorized(for: "mindfulness")
        default:
            return false
        }
    }

    private func inferredTrackingType(for item: PlanItem) -> String? {
        if let explicit = item.autoHealthTracking, !explicit.isEmpty {
            return explicit
        }

        guard item.type == .habit else { return nil }
        let title = item.title.lowercased()
        let unit = item.goalUnit.lowercased()

        if unit.contains("step") {
            if title.contains("run") || title.contains("jog") || title.contains("marathon") || title.contains("sprint") {
                return "running"
            }
            return "steps"
        }

        let distanceUnits = ["km", "mi", "m", "meter", "metre", "mile", "kilometer", "kilometre"]
        let isDistance = distanceUnits.contains { unit.hasPrefix($0) || unit == "\($0)s" }
        if isDistance {
            if title.contains("cycle") || title.contains("bike") || title.contains("ride") || title.contains("spin") {
                return "cycling"
            }
            if title.contains("run") || title.contains("jog") || title.contains("marathon") || title.contains("sprint") {
                return "running"
            }
            return "distance"
        }

        if (unit.contains("hour") || unit == "h" || unit == "hr" || unit.contains("min")),
           (title.contains("sleep") || title.contains("nap")) {
            return "sleep"
        }

        let hydrationUnits = ["ml", "l", "liter", "litre", "oz", "cup", "glass"]
        let isHydrationUnit = hydrationUnits.contains { unit == $0 || unit == "\($0)s" || unit.hasPrefix($0) }
        if isHydrationUnit && (title.contains("water") || title.contains("drink") || title.contains("hydrat")) {
            return "water"
        }

        if (unit.contains("hour") || unit == "h" || unit == "hr" || unit.contains("min")),
           (title.contains("stand") || title.contains("standing")) {
            return "standing"
        }

        if (unit.contains("min") || unit == "m"), (title.contains("meditat") || title.contains("mindful") || title.contains("breath")) {
            return "mindfulness"
        }

        return nil
    }

    private func convertDistance(_ meters: Double, to unit: String) -> Double {
        let loweredUnit = unit.lowercased()
        if loweredUnit.contains("km") || loweredUnit.contains("kilometer") || loweredUnit.contains("kilometre") {
            return meters / 1000.0
        }
        if loweredUnit.contains("mi") || loweredUnit.contains("mile") {
            return meters * 0.000_621_371
        }
        return meters
    }

    private func convertWater(_ milliliters: Double, to unit: String) -> Double {
        let loweredUnit = unit.lowercased()
        if loweredUnit == "l" || loweredUnit.contains("liter") || loweredUnit.contains("litre") {
            return milliliters / 1000.0
        }
        if loweredUnit.contains("oz") {
            return milliliters / 29.5735
        }
        if loweredUnit.contains("cup") || loweredUnit.contains("glass") {
            return milliliters / 240.0
        }
        return milliliters
    }

    private func updateHealthBackedHabitLog(_ item: PlanItem, value: Double, for date: Date) -> Bool {
        let targetDay = calendar.startOfDay(for: date)
        let existingLog = item.completionLogs.first(where: { calendar.isDate($0.date, inSameDayAs: targetDay) })

        if let existingLog {
            let previousValue = existingLog.value ?? 0
            if value > previousValue {
                existingLog.value = value
                existingLog.completed = item.isGoalMet(on: targetDay)
                if existingLog.note == CompletionLog.skippedMarker {
                    existingLog.note = nil
                }
                item.updatedAt = Date()
                return true
            }
            return false
        }

        guard value > 0 else { return false }
        let log = CompletionLog(date: targetDay, completed: false)
        log.value = value
        log.completed = item.isGoalMet(on: targetDay)
        item.completionLogs.append(log)
        item.updatedAt = Date()
        return true
    }
    
    private func calculateExpectedOccurrences(domain: ReportDomain, startDate: Date, endDate: Date, itemId: UUID?) async -> Int {
        if let id = itemId {
            let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.id == id })
            if let item = (try? modelContext.fetch(descriptor))?.first {
                var count = 0
                var current = startDate
                while current < endDate {
                    if isItemActive(item, on: current) && occurs(item: item, on: current) {
                        count += 1
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current)!
                }
                return count
            }
        } else {
            guard domain == .habits else { return 0 }
            // Overall: Sum of all occurrences for items that were active on each day.
            let type: PlanItemType = .habit
            let descriptor = FetchDescriptor<PlanItem>()
            let items = (try? modelContext.fetch(descriptor))?.filter { $0.type == type } ?? []
            
            var totalCount = 0
            for item in items {
                var current = startDate
                while current < endDate {
                    if isItemActive(item, on: current) && occurs(item: item, on: current) {
                        totalCount += 1
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current)!
                }
            }
            return totalCount
        }
        return 0
    }
    
    private func calculateStreak(entityId: UUID, domain: ActivityDomain) async -> Int {
        // Simplified backward streak computation
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // For performance, we fetch all events for this entity once
        let descriptor = FetchDescriptor<ActivityEvent>(predicate: #Predicate<ActivityEvent> { $0.entityId == entityId })
        guard let events = try? modelContext.fetch(descriptor) else { return 0 }
        
        let successDates = Set(events.filter { $0.status == .success }.map { calendar.startOfDay(for: $0.timestampUTC) })
        
        // Loop backwards
        for _ in 0..<365 {
            if successDates.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                // If it's today and not done yet, don't break streak if it was done yesterday
                if checkDate == today {
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                    continue
                }
                break
            }
        }
        
        return streak
    }
    
    func backfillFromLogs() async {
        let logDescriptor = FetchDescriptor<CompletionLog>()
        guard let logs = try? modelContext.fetch(logDescriptor), !logs.isEmpty else { return }
        
        let eventDescriptor = FetchDescriptor<ActivityEvent>()
        let existingEvents = (try? modelContext.fetch(eventDescriptor)) ?? []
        
        // Use a set of ID-Date pairs to avoid duplicates
        let existingPairs = Set(existingEvents.map { "\($0.entityId.uuidString)-\($0.timestampUTC.timeIntervalSince1970)" })
        
        for log in logs {
            guard let item = log.planItem else { continue }
            let pairKey = "\(item.id.uuidString)-\(log.date.timeIntervalSince1970)"
            if existingPairs.contains(pairKey) { continue }
            
            let event = ActivityEvent(
                domain: item.type == .habit ? .habit : .task,
                entityId: item.id,
                timestampUTC: log.date,
                status: .success,
                value: log.value
            )
            modelContext.insert(event)
        }
        try? modelContext.save()
    }
}
