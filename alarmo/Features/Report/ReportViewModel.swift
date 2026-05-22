import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class ReportViewModel: ObservableObject {
    private let modelContext: ModelContext
    private let service: ReportService
    private var alarmStore: AlarmStore?
    
    @Published var selectedDomain: ReportDomain = .alarms
    @Published var selectedPeriod: ReportPeriod = .week
    @Published var trendGrouping: ReportTrendGrouping = .day
    @Published var referenceDate: Date = Date()
    @Published var selectedItemId: UUID? = nil
    @Published var selectedReportDate: Date? = Date()
    
    @Published var metrics = ReportMetrics()
    @Published var dayMetrics = ReportMetrics()
    @Published var trends: [TrendPoint] = []
    @Published var heatmap: [Date: Double] = [:]
    @Published var habitConsistencySeries: [Date: Double] = [:]
    @Published var availableItems: [ReportItemInfo] = []
    
    @Published var isLoading = false
    
    // Rate switch mode for the main ring
    @Published var showMonthlyRate = false // false = Overall (Today), true = Monthly
    
    struct ReportItemInfo: Identifiable, Equatable {
        let id: UUID
        let title: String
        let icon: String
        let goalUnit: String
        let goalValue: Double
    }
    
    var periodLabel: String {
        let f = DateFormatter()
        switch selectedPeriod {
        case .week:
            f.dateFormat = "'Week' w, yyyy"
            return f.string(from: referenceDate)
        case .month:
            f.dateFormat = "LLLL yyyy"
            return f.string(from: referenceDate)
        case .year:
            f.dateFormat = "yyyy"
            return f.string(from: referenceDate)
        }
    }
    
    init(modelContext: ModelContext, alarmStore: AlarmStore?) {
        self.modelContext = modelContext
        self.service = ReportService(modelContext: modelContext)
        self.alarmStore = alarmStore
        self.trendGrouping = service.defaultTrendGrouping(for: selectedPeriod)
    }
    
    func refresh() async {
        isLoading = true
        
        await service.backfillFromLogs()
        ensureTrendGroupingMatchesPeriod()
        fetchAvailableItems()
        
        let (newMetrics, newTrends, newHeatmap) = await service.generateReport(
            domain: selectedDomain,
            period: selectedPeriod,
            referenceDate: referenceDate,
            trendGrouping: trendGrouping,
            itemId: selectedItemId
        )
        
        self.metrics = newMetrics
        self.trends = newTrends
        self.heatmap = newHeatmap
        if selectedDomain == .habits {
            habitConsistencySeries = await service.generateHabitConsistencySeries(
                itemId: selectedItemId,
                referenceDate: referenceDate
            )
        } else {
            habitConsistencySeries = [:]
        }
        if selectedReportDate == nil {
            selectedReportDate = Calendar.current.startOfDay(for: referenceDate)
        }
        await refreshDayMetrics()
        self.isLoading = false
    }

    func refreshDayMetrics() async {
        let focusDay = selectedReportDate ?? referenceDate
        dayMetrics = await service.generateDayReport(
            domain: selectedDomain,
            date: focusDay,
            itemId: selectedItemId
        )
    }

    func setReportDate(_ date: Date?) async {
        selectedReportDate = date
        await refreshDayMetrics()
    }

    func updateTrendGrouping(_ grouping: ReportTrendGrouping) async {
        trendGrouping = grouping
        await refresh()
    }
    
    func movePeriod(by delta: Int) {
        let component: Calendar.Component = {
            switch selectedPeriod {
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }()
        if let next = Calendar.current.date(byAdding: component, value: delta, to: referenceDate) {
            referenceDate = next
            selectedReportDate = Calendar.current.startOfDay(for: next)
            Task { await refresh() }
        }
    }

    var availableTrendGroupings: [ReportTrendGrouping] {
        service.availableTrendGroupings(for: selectedPeriod)
    }

    func syncPeriod(_ period: ReportPeriod) {
        selectedPeriod = period
        ensureTrendGroupingMatchesPeriod()
    }

    private func ensureTrendGroupingMatchesPeriod() {
        let options = service.availableTrendGroupings(for: selectedPeriod)
        if !options.contains(trendGrouping) {
            trendGrouping = service.defaultTrendGrouping(for: selectedPeriod)
        }
    }
    
    private func fetchAvailableItems() {
        switch selectedDomain {
        case .habits:
            let type: PlanItemType = .habit
            let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.isArchived == false })
            if let items = try? modelContext.fetch(descriptor) {
                self.availableItems = items
                    .filter { $0.type == type }
                    .map {
                        ReportItemInfo(
                            id: $0.id,
                            title: $0.title,
                            icon: $0.iconName,
                            goalUnit: $0.goalUnit,
                            goalValue: $0.goalValue
                        )
                    }
            }
        case .pomodoro:
            self.availableItems = []
        case .alarms:
            if let alarms = alarmStore?.alarms {
                self.availableItems = alarms.map { alarm in
                    ReportItemInfo(
                        id: alarm.id,
                        title: alarm.name.isEmpty ? "Alarm" : alarm.name,
                        icon: "alarm",
                        goalUnit: "fires",
                        goalValue: 0
                    )
                }
            } else {
                self.availableItems = []
            }
        }
    }
}
