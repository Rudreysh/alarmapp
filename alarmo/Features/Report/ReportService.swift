import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums & Models

enum ReportDomain: String, CaseIterable, Identifiable, Sendable {
    case habits = "Habits"
    case tasks = "Tasks"
    case alarms = "Alarms"
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .habits: return "leaf"
        case .tasks: return "checkmark.square"
        case .alarms: return "alarm"
        }
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
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

struct TrendPoint: Identifiable, Sendable {
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
    
    func generateReport(domain: ReportDomain, period: ReportPeriod, referenceDate: Date, itemId: UUID? = nil) async -> (ReportMetrics, [TrendPoint], [Date: Double]) {
        let (startDate, endDate) = calculateDateRange(period: period, referenceDate: referenceDate)
        
        var metrics = ReportMetrics()
        var trendPoints: [TrendPoint] = []
        var heatmap: [Date: Double] = [:]
        
        // 1. Fetch Events
        let events = await fetchEvents(domain: domain, startDate: startDate, endDate: endDate, itemId: itemId)
        
        // 2. Compute Common Metrics
        metrics.totalDone = events.filter { $0.status == .success || $0.status == .dismissed }.count
        
        // 3. Domain Specific Logic
        switch domain {
        case .habits, .tasks:
            await computeHabitTaskMetrics(domain: domain, events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: startDate, endDate: endDate, referenceDate: referenceDate, period: period, itemId: itemId)
        case .alarms:
            await computeAlarmMetrics(events: events, metrics: &metrics, trendPoints: &trendPoints, heatmap: &heatmap, startDate: startDate, endDate: endDate, period: period, itemId: itemId)
        }
        
        return (metrics, trendPoints, heatmap)
    }
    
    // MARK: - Internal Computation
    
    private func fetchEvents(domain: ReportDomain, startDate: Date, endDate: Date, itemId: UUID?) async -> [ActivityEvent] {
        let activityDomain: ActivityDomain = {
            switch domain {
            case .habits: return .habit
            case .tasks: return .task
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
    
    private func computeHabitTaskMetrics(domain: ReportDomain, events: [ActivityEvent], metrics: inout ReportMetrics, trendPoints: inout [TrendPoint], heatmap: inout [Date: Double], startDate: Date, endDate: Date, referenceDate: Date, period: ReportPeriod, itemId: UUID?) async {
        let type: PlanItemType = domain == .habits ? .habit : .task
        let descriptor = FetchDescriptor<PlanItem>()
        let scopedItems = (try? modelContext.fetch(descriptor))?.filter { item in
            item.type == type && item.parentTask == nil && (itemId == nil || item.id == itemId)
        } ?? []

        let effectivePeriodEnd = cappedEndDate(for: endDate)
        let daysCount = max(1, calendar.dateComponents([.day], from: startDate, to: effectivePeriodEnd).day ?? 1)
        metrics.dailyAverage = Double(metrics.totalDone) / Double(daysCount)

        trendPoints = generateTrendPoints(events: events, startDate: startDate, endDate: endDate, period: period)

        if let id = itemId {
            metrics.currentStreak = await calculateStreak(entityId: id, domain: domain == .habits ? .habit : .task)
            metrics.bestStreak = metrics.currentStreak // TODO: Persist best streak separately
        }

        guard !scopedItems.isEmpty else {
            metrics.completionRate = 0
            metrics.todayRate = 0
            metrics.monthRate = 0
            metrics.perfectDays = 0
            return
        }

        // Period-wide completion/heatmap based on per-day item success.
        var dayCursor = startDate
        var dayRates: [Double] = []
        var perfectDays = 0
        while dayCursor < effectivePeriodEnd {
            let result = daySuccess(for: dayCursor, items: scopedItems)
            if result.applicableCount > 0 {
                dayRates.append(result.rate)
                heatmap[dayCursor] = result.rate
                if result.successCount == result.applicableCount {
                    perfectDays += 1
                }
            } else {
                heatmap[dayCursor] = 0
            }
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
        }

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
    
    private func computeAlarmMetrics(events: [ActivityEvent], metrics: inout ReportMetrics, trendPoints: inout [TrendPoint], heatmap: inout [Date: Double], startDate: Date, endDate: Date, period: ReportPeriod, itemId: UUID?) async {
        let alarmEvents = events.filter { $0.domain == .alarm }
        
        metrics.firedCount = alarmEvents.filter { $0.status == .fired }.count
        metrics.dismissedCount = alarmEvents.filter { $0.status == .dismissed }.count
        metrics.snoozeCount = alarmEvents.filter { $0.status == .snoozed }.count
        metrics.missedCount = alarmEvents.filter { $0.status == .missed }.count
        
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
        
        trendPoints = generateTrendPoints(events: alarmEvents, startDate: startDate, endDate: endDate, period: period)
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
    
    private func generateTrendPoints(events: [ActivityEvent], startDate: Date, endDate: Date, period: ReportPeriod) -> [TrendPoint] {
        var points: [TrendPoint] = []
        var cursor = startDate
        
        while cursor < endDate {
            let bucketEnd: Date
            let label: String
            
            if period == .year {
                bucketEnd = calendar.date(byAdding: .month, value: 1, to: cursor)!
                let f = DateFormatter(); f.dateFormat = "MMM"
                label = f.string(from: cursor)
            } else {
                bucketEnd = calendar.date(byAdding: .day, value: 1, to: cursor)!
                let f = DateFormatter(); f.dateFormat = "d"
                label = f.string(from: cursor)
            }
            
            let count = events.filter { $0.timestampUTC >= cursor && $0.timestampUTC < bucketEnd && ($0.status == .success || $0.status == .dismissed) }.count
            points.append(TrendPoint(date: cursor, label: label, value: Double(count)))
            
            cursor = bucketEnd
        }
        return points
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
            // Overall: Sum of all occurrences for items that were active on each day.
            let type: PlanItemType = domain == .habits ? .habit : .task
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
