import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class ReportViewModel: ObservableObject {
    private let modelContext: ModelContext
    private let service: ReportService
    private var alarmStore: AlarmStore?
    
    @Published var selectedDomain: ReportDomain = .habits
    @Published var selectedPeriod: ReportPeriod = .week
    @Published var referenceDate: Date = Date()
    @Published var selectedItemId: UUID? = nil
    
    @Published var metrics = ReportMetrics()
    @Published var trends: [TrendPoint] = []
    @Published var heatmap: [Date: Double] = [:]
    @Published var availableItems: [ReportItemInfo] = []
    
    @Published var isLoading = false
    
    // Rate switch mode for the main ring
    @Published var showMonthlyRate = false // false = Overall (Today), true = Monthly
    
    struct ReportItemInfo: Identifiable, Equatable {
        let id: UUID
        let title: String
        let icon: String
        let goalUnit: String
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
    }
    
    func refresh() async {
        isLoading = true
        
        await service.backfillFromLogs()
        fetchAvailableItems()
        
        let (newMetrics, newTrends, newHeatmap) = await service.generateReport(
            domain: selectedDomain,
            period: selectedPeriod,
            referenceDate: referenceDate,
            itemId: selectedItemId
        )
        
        self.metrics = newMetrics
        self.trends = newTrends
        self.heatmap = newHeatmap
        self.isLoading = false
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
            Task { await refresh() }
        }
    }
    
    private func fetchAvailableItems() {
        switch selectedDomain {
        case .habits, .tasks:
            let type: PlanItemType = selectedDomain == .habits ? .habit : .task
            let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.isArchived == false })
            if let items = try? modelContext.fetch(descriptor) {
                self.availableItems = items
                    .filter { $0.type == type }
                    .map { ReportItemInfo(id: $0.id, title: $0.title, icon: $0.iconName, goalUnit: $0.goalUnit) }
            }
        case .alarms:
            if let alarms = alarmStore?.alarms {
                self.availableItems = alarms.map { alarm in
                    ReportItemInfo(
                        id: alarm.id,
                        title: alarm.name.isEmpty ? "Alarm" : alarm.name,
                        icon: "alarm",
                        goalUnit: "fires"
                    )
                }
            } else {
                self.availableItems = []
            }
        }
    }
}
