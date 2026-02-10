import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ReportViewModel
    
    init(modelContext: ModelContext, alarmStore: AlarmStore? = nil) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(modelContext: modelContext, alarmStore: alarmStore))
    }
    
    @State private var isPickerExpanded = false
    @State private var selectedReportDate: Date? = Date()
    
    @Namespace private var domainNamespace
    @Namespace private var periodNamespace
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Domain & Period Selection)
                reportHeader
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Section: Item Selector
                        itemSelector
                        
                        if !viewModel.availableItems.isEmpty {
                            horizontalQuickSwitcher
                        }
                        
                        // OVERALL VIEW: Calendar + Overall Rate Ring + Simple KPIs
                        if viewModel.selectedItemId == nil {
                            // Monthly Calendar (full month view for overall)
                            OverallMonthCalendarView(
                                heatmap: viewModel.heatmap,
                                referenceDate: viewModel.referenceDate,
                                onMove: { delta in viewModel.movePeriod(by: delta) },
                                selectedDate: $selectedReportDate
                            )
                            
                            // Overall/Monthly Rate Ring
                            VStack(spacing: 8) {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        viewModel.showMonthlyRate.toggle()
                                    }
                                }) {
                                    RingProgressView(
                                        progress: viewModel.showMonthlyRate ? viewModel.metrics.monthRate : viewModel.metrics.completionRate,
                                        subtitle: viewModel.showMonthlyRate ? "Monthly Rate" : "Overall Rate"
                                    )
                                    .padding(.vertical, 20)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Simple KPI Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                if viewModel.selectedDomain == .alarms {
                                    KPICard(icon: "bolt.fill", iconColor: .orange, value: "\(viewModel.metrics.firedCount)", unit: "Fired", label: "Total Fires")
                                    KPICard(icon: "checkmark.seal.fill", iconColor: .green, value: "\(viewModel.metrics.dismissedCount)", unit: "Done", label: "Dismissed")
                                    KPICard(icon: "zzz", iconColor: .purple, value: "\(viewModel.metrics.snoozeCount)", unit: "Times", label: "Total Snoozes")
                                    KPICard(icon: "xmark.circle.fill", iconColor: .red, value: "\(viewModel.metrics.missedCount)", unit: "Missed", label: "Total Missed")
                                } else {
                                    KPICard(icon: "medal.fill", iconColor: .orange, value: "\(viewModel.metrics.currentStreak)", unit: "Day", label: "Best Streaks")
                                    KPICard(icon: "calendar.badge.checkmark", iconColor: .blue, value: "\(viewModel.metrics.perfectDays)", unit: "Day", label: "Perfect Days")
                                    KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.metrics.totalDone)", unit: "Done", label: "Habits Done")
                                    KPICard(icon: "chart.line.uptrend.xyaxis", iconColor: .purple, value: String(format: "%.1f", viewModel.metrics.dailyAverage), unit: "Avg", label: "Daily Average")
                                }
                            }
                        }
                        // SINGLE HABIT VIEW: Calendar + Yearly Status + Detailed KPIs
                        else {
                            // Monthly Calendar (full month view)
                            OverallMonthCalendarView(
                                heatmap: viewModel.heatmap,
                                referenceDate: viewModel.referenceDate,
                                onMove: { delta in viewModel.movePeriod(by: delta) },
                                selectedDate: $selectedReportDate
                            )
                            
                            // Yearly Status
                            YearlyStatusView(
                                heatmap: viewModel.heatmap,
                                year: Calendar.current.component(.year, from: viewModel.referenceDate),
                                referenceDate: viewModel.referenceDate
                            )
                            
                            // Detailed KPI Grid (6-8 metrics)
                            if viewModel.selectedDomain == .alarms {
                                alarmSpecificKPIs
                            } else {
                                habitSpecificKPIs
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
    
    private var reportHeader: some View {
        VStack(spacing: 16) {
            // Domain Segment
            HStack(spacing: 0) {
                ForEach(ReportDomain.allCases) { domain in
                    let isSelected = viewModel.selectedDomain == domain
                    Button {
                        viewModel.selectedDomain = domain
                        viewModel.selectedItemId = nil
                        Task { await viewModel.refresh() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? domain.icon + ".fill" : domain.icon)
                                .font(.system(size: 14))
                            Text(domain.rawValue)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Colors.accentBlue)
                                        .matchedGeometryEffect(id: "domain_bg", in: domainNamespace)
                                        .shadow(color: Colors.accentBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                            }
                        )
                        .foregroundColor(isSelected ? .white : Colors.textSecondary)
                    }
                }
            }
            .background(Colors.cardSurface.opacity(0.5))
            .cornerRadius(18)
            .padding(.horizontal)
            
            // Period Selection & Navigation
            HStack {
                HStack(spacing: 0) {
                    ForEach(ReportPeriod.allCases) { period in
                        let isSelected = viewModel.selectedPeriod == period
                        Button {
                            viewModel.selectedPeriod = period
                            Task { await viewModel.refresh() }
                        } label: {
                            Text(period.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Colors.cardSurface)
                                                .matchedGeometryEffect(id: "period_bg", in: periodNamespace)
                                                .shadow(color: Color.black.opacity(0.1), radius: 2)
                                        }
                                    }
                                )
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                        }
                    }
                }
                .padding(4)
                .background(Colors.bgPrimary.opacity(0.5))
                .cornerRadius(12)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button { 
                        withAnimation { viewModel.movePeriod(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.cardSurface)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Colors.accentBlue)
                            )
                    }
                    
                    Text(viewModel.periodLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Colors.textPrimary)
                    
                    Button { 
                        withAnimation { viewModel.movePeriod(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.cardSurface)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Colors.accentBlue)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Colors.bgPrimary)
    }
    
    private var horizontalQuickSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                // All Item
                let isAllSelected = viewModel.selectedItemId == nil
                Button {
                    withAnimation(.spring()) {
                        viewModel.selectedItemId = nil
                    }
                    Task { await viewModel.refresh() }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isAllSelected ? Colors.accentBlue.opacity(0.15) : Color.clear)
                                .frame(width: 48, height: 48)
                            Image(systemName: isAllSelected ? "square.grid.2x2.fill" : "square.grid.2x2")
                                .font(.system(size: 20))
                                .foregroundColor(isAllSelected ? Colors.accentBlue : Colors.textSecondary)
                        }
                        Text("All")
                            .font(.system(size: 11, weight: isAllSelected ? .heavy : .medium))
                            .foregroundColor(isAllSelected ? Colors.textPrimary : Colors.textSecondary)
                    }
                }
                
                ForEach(viewModel.availableItems) { item in
                    let isSelected = viewModel.selectedItemId == item.id
                    Button {
                        withAnimation(.spring()) {
                            viewModel.selectedItemId = item.id
                        }
                        Task { await viewModel.refresh() }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Colors.accentBlue.opacity(0.15) : Color.clear)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? Colors.accentBlue.opacity(0.3) : Colors.cardStroke, lineWidth: 1)
                                    )
                                
                                if item.icon.allSatisfy({ !$0.isASCII }) {
                                    Text(item.icon)
                                        .font(.system(size: 20))
                                } else {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(isSelected ? Colors.accentBlue : Colors.textSecondary)
                                }
                            }
                            Text(item.title)
                                .font(.system(size: 11, weight: isSelected ? .heavy : .medium))
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Colors.cardSurface.opacity(0.3))
    }
    
    private var itemSelector: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPickerExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let selected = viewModel.availableItems.first(where: { $0.id == viewModel.selectedItemId }) {
                        if selected.icon.allSatisfy({ !$0.isASCII }) {
                            Text(selected.icon)
                        } else {
                            Image(systemName: selected.icon)
                        }
                        Text(selected.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("Overall View")
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
            }
            
            if isPickerExpanded {
                VStack(spacing: 0) {
                    // Overall View Option
                    Button {
                        viewModel.selectedItemId = nil
                        withAnimation { isPickerExpanded = false }
                        Task { await viewModel.refresh() }
                    } label: {
                        Text("Overall View")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                    }
                    
                    Divider().background(Colors.cardStroke)
                    
                    // Item List
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.availableItems) { item in
                                Button {
                                    viewModel.selectedItemId = item.id
                                    withAnimation { isPickerExpanded = false }
                                    Task { await viewModel.refresh() }
                                } label: {
                                    HStack(spacing: 16) {
                                        if item.icon.allSatisfy({ !$0.isASCII }) {
                                            Text(item.icon).font(.system(size: 20))
                                        } else {
                                            Image(systemName: item.icon).font(.system(size: 20))
                                        }
                                        
                                        Text(item.title)
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        if viewModel.selectedItemId == item.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Colors.accentBlue)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 24)
                                }
                                
                                if item != viewModel.availableItems.last {
                                    Divider().background(Colors.cardStroke).padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
                .background(Colors.bgSecondary)
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Colors.cardStroke, lineWidth: 1))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -10)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
        }
        .zIndex(10)
    }
    
    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            KPICard(
                title: viewModel.selectedDomain == .alarms ? "Fired" : "Current Streak",
                value: viewModel.selectedDomain == .alarms ? "\(viewModel.metrics.firedCount)" : "\(viewModel.metrics.currentStreak) Days",
                icon: viewModel.selectedDomain == .alarms ? "alarm" : "flame.fill",
                color: .orange
            )
            
            KPICard(
                title: viewModel.selectedDomain == .alarms ? "Snoozes" : "Best Streak",
                value: viewModel.selectedDomain == .alarms ? "\(viewModel.metrics.snoozeCount)" : "\(viewModel.metrics.bestStreak) Days",
                icon: viewModel.selectedDomain == .alarms ? "zzz" : "trophy.fill",
                color: .purple
            )
            
            KPICard(
                title: viewModel.selectedDomain == .alarms ? "Dismissed" : "Total Done",
                value: viewModel.selectedDomain == .alarms ? "\(viewModel.metrics.dismissedCount)" : "\(viewModel.metrics.totalDone)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            if viewModel.selectedDomain == .alarms {
                KPICard(
                    title: "Avg Dismiss",
                    value: String(format: "%.1fs", viewModel.metrics.avgDismissTime),
                    icon: "timer",
                    color: .blue
                )
            } else {
                KPICard(
                    title: "Daily Avg",
                    value: String(format: "%.1f", viewModel.metrics.dailyAverage),
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
        }
    }
    
    @ViewBuilder
    private var habitSpecificKPIs: some View {
        if let selectedItem = viewModel.availableItems.first(where: { $0.id == viewModel.selectedItemId }) {
            let unit = selectedItem.goalUnit
            let isStepBased = unit.lowercased().contains("step")
            let isTimeBased = ["min", "minutes", "hr", "hours", "h"].contains(unit.lowercased())
            let isVolumeBased = ["ml", "oz", "l", "liters"].contains(unit.lowercased())
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Row 1: Success in Month, Total Success
                KPICard(
                    icon: "calendar.badge.checkmark",
                    iconColor: .blue,
                    value: "\(viewModel.metrics.perfectDays)",
                    unit: "Day",
                    label: "success in February"
                )
                
                KPICard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    value: "\(viewModel.metrics.totalDone)",
                    unit: "Day",
                    label: "Total Success"
                )
                
                // Row 2: Current Streak, Best Streak
                KPICard(
                    icon: "layers.fill",
                    iconColor: .purple,
                    value: "\(viewModel.metrics.currentStreak)",
                    unit: "Day",
                    label: "Current Streak"
                )
                
                KPICard(
                    icon: "medal.fill",
                    iconColor: .orange,
                    value: "\(viewModel.metrics.bestStreak)",
                    unit: "Day",
                    label: "Best Streak"
                )
                
                // Row 3: Volume/Count metrics
                if isStepBased {
                    KPICard(
                        icon: "chart.bar.fill",
                        iconColor: .green,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: "steps",
                        label: "Vol. in Feb"
                    )
                    
                    KPICard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .pink,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: "steps",
                        label: "Vol. Total"
                    )
                } else if isTimeBased {
                    KPICard(
                        icon: "clock.fill",
                        iconColor: .green,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Time in Feb"
                    )
                    
                    KPICard(
                        icon: "hourglass",
                        iconColor: .pink,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Time Total"
                    )
                } else if isVolumeBased {
                    KPICard(
                        icon: "drop.fill",
                        iconColor: .blue,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Vol. in Feb"
                    )
                    
                    KPICard(
                        icon: "drop.triangle.fill",
                        iconColor: .cyan,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Vol. Total"
                    )
                } else {
                    KPICard(
                        icon: "number",
                        iconColor: .green,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Count in Feb"
                    )
                    
                    KPICard(
                        icon: "sum",
                        iconColor: .pink,
                        value: String(format: "%.0f", viewModel.heatmap.values.reduce(0, +)),
                        unit: unit,
                        label: "Count Total"
                    )
                }
                
                // Row 4: Daily Average, Overall Rate
                KPICard(
                    icon: "chart.xyaxis.line",
                    iconColor: .purple,
                    value: String(format: "%.1f", viewModel.metrics.dailyAverage),
                    unit: isStepBased ? "steps" : unit,
                    label: "Daily Avg."
                )
                
                KPICard(
                    icon: "chart.pie.fill",
                    iconColor: .blue,
                    value: String(format: "%.2f", viewModel.metrics.completionRate * 100),
                    unit: "%",
                    label: "Overall Rate"
                )
            }
        }
    }
    
    private func calculateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfRef = calendar.startOfDay(for: viewModel.referenceDate)
        var start: Date
        var end: Date
        
        switch viewModel.selectedPeriod {
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
    
    @ViewBuilder
    private var alarmSpecificKPIs: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Alarm Performance")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Row 1: Speed & Consistency
                KPICard(
                    icon: "hare.fill",
                    iconColor: .orange,
                    value: String(format: "%.1f", viewModel.metrics.avgDismissTime),
                    unit: "sec",
                    label: "Avg. Wakeup Speed"
                )
                
                KPICard(
                    icon: "target",
                    iconColor: .blue,
                    value: String(format: "%.0f", viewModel.metrics.wakeupConsistency * 100),
                    unit: "%",
                    label: "Wakeup Consistency"
                )
                
                // Row 2: Snoozing
                KPICard(
                    icon: "zzz",
                    iconColor: .purple,
                    value: String(format: "%.1f", viewModel.metrics.avgSnoozeCount),
                    unit: "per",
                    label: "Avg. Snooze Count"
                )
                
                KPICard(
                    icon: "timer",
                    iconColor: .pink,
                    value: String(format: "%.0f", viewModel.metrics.totalSnoozeTime / 60),
                    unit: "min",
                    label: "Total Snooze Time"
                )
                
                // Row 3: Volume
                KPICard(
                    icon: "bell.badge.fill",
                    iconColor: .green,
                    value: "\(viewModel.metrics.firedCount)",
                    unit: "fires",
                    label: "Total Fires"
                )
                
                KPICard(
                    icon: "checkmark.circle.fill",
                    iconColor: .teal,
                    value: String(format: "%.1f", viewModel.metrics.completionRate * 100),
                    unit: "%",
                    label: "Success Rate"
                )
            }
        }
    }
}
