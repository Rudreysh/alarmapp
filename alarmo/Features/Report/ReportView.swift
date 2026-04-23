import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var settingsStore = SettingsStore.shared
    @StateObject private var viewModel: ReportViewModel
    
    init(modelContext: ModelContext, alarmStore: AlarmStore? = nil) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(modelContext: modelContext, alarmStore: alarmStore))
    }
    
    @State private var isPickerExpanded = false
    @State private var selectedReportDate: Date? = Date()
    @State private var selectedTrendPoint: TrendPoint?

    private struct HabitWeekSnapshot: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
        var intensity: Double { min(max(value, 0), 1) }
        var hasLog: Bool { value > 0 }
        var goalMet: Bool { value >= 1 }
    }

    private struct HabitStreakLeader: Identifiable {
        let id: UUID
        let title: String
        let icon: String
        let goalValue: Double
        let goalUnit: String
        let streakDays: Int
    }
    
    @Namespace private var domainNamespace
    @Namespace private var periodNamespace

    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                // Header (Domain & Period Selection)
                reportHeader
                
                ScrollView(showsIndicators: false) {
                    reportScrollContent
                }
            }
        }
        .task {
            selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
            await viewModel.refresh()
            await viewModel.setReportDate(selectedReportDate)
        }
        .onChange(of: selectedReportDate) { _, newDate in
            Task { await viewModel.setReportDate(newDate) }
        }
        .onChange(of: viewModel.trends) { _, newTrends in
            if let selected = selectedTrendPoint,
               let matching = newTrends.first(where: { $0.id == selected.id }) {
                selectedTrendPoint = matching
            } else {
                selectedTrendPoint = newTrends.last
            }
        }
    }

    private var reportScrollContent: some View {
        VStack(spacing: 24) {
            itemSelector

            if !viewModel.availableItems.isEmpty {
                horizontalQuickSwitcher
            }

            if viewModel.selectedItemId == nil {
                overallReportSection
            } else {
                selectedItemReportSection
            }
        }
        .padding(20)
        .padding(.bottom, AppConstants.tabBarHeight + Spacing.m)
    }

    private var calendarSection: some View {
        OverallMonthCalendarView(
            heatmap: viewModel.heatmap,
            period: viewModel.selectedPeriod,
            referenceDate: viewModel.referenceDate,
            onMove: { delta in
                viewModel.movePeriod(by: delta)
                selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
            },
            selectedDate: $selectedReportDate
        )
    }

    private var overallReportSection: some View {
        VStack(spacing: 24) {
            calendarSection
            if viewModel.selectedDomain == .habits {
                allHabitsOverviewSection
                habitSignalSection
            }
            trendSection
            if viewModel.selectedDomain == .habits {
                habitConsistencySection
            }
            selectedDayMetricsCard
            rateRingSection
            overallKPIs
        }
    }

    private var selectedItemReportSection: some View {
        VStack(spacing: 24) {
            calendarSection

            if viewModel.selectedPeriod == .year {
                YearlyStatusView(
                    heatmap: viewModel.heatmap,
                    year: Calendar.current.component(.year, from: viewModel.referenceDate),
                    referenceDate: viewModel.referenceDate
                )
            }

            if viewModel.selectedDomain == .habits {
                selectedHabitOverviewSection
                habitSignalSection
                trendSection
                habitConsistencySection
            }

            if viewModel.selectedDomain == .alarms {
                alarmSpecificKPIs
            } else if viewModel.selectedDomain == .pomodoro {
                pomodoroSpecificKPIs
            } else {
                habitSpecificKPIs
            }
        }
    }

    private var habitConsistencySection: some View {
        ConsistencyTrendCard(
            title: "Consistency",
            dailyRates: viewModel.habitConsistencySeries,
            maxReferenceDate: viewModel.referenceDate,
            accentColor: Colors.accentBlue
        )
    }

    private var habitSignalSection: some View {
        HabitSignalWheelCard(
            title: "Habit Signals",
            metrics: habitSignalMetrics,
            accentColor: ReportPalette.accent
        )
    }

    private var rateRingSection: some View {
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
    }

    private var overallKPIs: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            if viewModel.selectedDomain == .alarms {
                KPICard(icon: "bolt.fill", iconColor: .orange, value: "\(viewModel.metrics.firedCount)", unit: "Fired", label: "Total Fires")
                KPICard(icon: "checkmark.seal.fill", iconColor: .green, value: "\(viewModel.metrics.dismissedCount)", unit: "Done", label: "Dismissed")
                KPICard(icon: "zzz", iconColor: .purple, value: "\(viewModel.metrics.snoozeCount)", unit: "Times", label: "Total Snoozes")
                KPICard(icon: "xmark.circle.fill", iconColor: .red, value: "\(viewModel.metrics.missedCount)", unit: "Missed", label: "Total Missed")
            } else if viewModel.selectedDomain == .pomodoro {
                KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.metrics.completedCount)", unit: "Done", label: "Completed")
                KPICard(icon: "play.circle.fill", iconColor: .blue, value: "\(viewModel.metrics.startedCount)", unit: "Start", label: "Started")
                KPICard(icon: "pause.circle.fill", iconColor: .orange, value: "\(viewModel.metrics.interruptedCount)", unit: "Break", label: "Interrupted")
                KPICard(icon: "clock.fill", iconColor: .purple, value: String(format: "%.0f", viewModel.metrics.focusMinutes), unit: "min", label: "Focus Time")
            } else {
                KPICard(icon: "medal.fill", iconColor: .orange, value: "\(viewModel.metrics.currentStreak)", unit: "Day", label: "Best Streaks")
                KPICard(icon: "calendar.badge.checkmark", iconColor: ReportPalette.accent, value: "\(viewModel.metrics.perfectDays)", unit: "Day", label: "Perfect Days")
                KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.metrics.totalDone)", unit: "Done", label: "Habits Done")
                KPICard(icon: "chart.line.uptrend.xyaxis", iconColor: .purple, value: String(format: "%.1f", viewModel.metrics.dailyAverage), unit: "Avg", label: "Daily Average")
            }
        }
    }
    
    private var reportHeader: some View {
        VStack(spacing: 16) {
            // Domain Segment — Capsule style matching Timer tabs
            HStack(spacing: 6) {
                ForEach(ReportDomain.allCases) { domain in
                    let isSelected = viewModel.selectedDomain == domain
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.selectedDomain = domain
                            viewModel.selectedItemId = nil
                            selectedTrendPoint = nil
                        }
                        selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
                        Task { await viewModel.refresh() }
                    } label: {
                        HStack(spacing: domain == .pomodoro ? 0 : 6) {
                            if domain != .pomodoro {
                                Image(systemName: isSelected ? domain.icon + ".fill" : domain.icon)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(domain.rawValue)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? LinearGradient(
                                            colors: isLightMode
                                                ? [Color.white, Color(red: 0.90, green: 0.96, blue: 1.0)]
                                                : [Color(red: 0.18, green: 0.21, blue: 0.28).opacity(0.95), Color(red: 0.12, green: 0.15, blue: 0.21).opacity(0.95)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [
                                                isLightMode ? Color(red: 0.93, green: 0.94, blue: 0.97) : Color.white.opacity(0.06),
                                                isLightMode ? Color(red: 0.88, green: 0.90, blue: 0.94) : Color.white.opacity(0.03)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .matchedGeometryEffect(id: "domain_bg", in: domainNamespace)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? (isLightMode ? Color(red: 0.55, green: 0.76, blue: 0.96).opacity(0.7) : Color.white.opacity(0.2))
                                        : (isLightMode ? Colors.cardStroke : Color.white.opacity(0.1)),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                isLightMode ? Color.white.opacity(0.96) : Color(red: 0.12, green: 0.15, blue: 0.20).opacity(0.92),
                                isLightMode ? Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.96) : Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .clipShape(Capsule())
            .padding(.horizontal)
            
            // Period Selection & Navigation
            HStack {
                HStack(spacing: 4) {
                    ForEach(ReportPeriod.allCases) { period in
                        let isSelected = viewModel.selectedPeriod == period
                        Button {
                            viewModel.syncPeriod(period)
                            selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
                            Task { await viewModel.refresh() }
                        } label: {
                            Text(period.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isSelected
                                                ? LinearGradient(
                                                    colors: isLightMode
                                                        ? [Color.white, Color(red: 0.90, green: 0.96, blue: 1.0)]
                                                        : [Color(red: 0.18, green: 0.21, blue: 0.28).opacity(0.95), Color(red: 0.12, green: 0.15, blue: 0.21).opacity(0.95)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(
                                                    colors: [
                                                        isLightMode ? Color(red: 0.93, green: 0.94, blue: 0.97) : Color.white.opacity(0.05),
                                                        isLightMode ? Color(red: 0.88, green: 0.90, blue: 0.94) : Color.white.opacity(0.03)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )
                                        .matchedGeometryEffect(id: "period_bg", in: periodNamespace)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    isSelected
                                                        ? (isLightMode ? Color(red: 0.55, green: 0.76, blue: 0.96).opacity(0.7) : Color.white.opacity(0.2))
                                                        : (isLightMode ? Colors.cardStroke : Color.white.opacity(0.08)),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: isSelected ? Color.black.opacity(isLightMode ? 0.08 : 0.15) : .clear, radius: 2, y: 1)
                                )
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isLightMode ? Color.white.opacity(0.98) : Color(red: 0.10, green: 0.13, blue: 0.18).opacity(0.9),
                                    isLightMode ? Color(red: 0.94, green: 0.95, blue: 0.98).opacity(0.98) : Color(red: 0.07, green: 0.10, blue: 0.15).opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLightMode ? Colors.cardStroke : Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(12)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button { 
                        withAnimation { viewModel.movePeriod(by: -1) }
                        selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.cardSurface)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(ReportPalette.accent)
                            )
                    }
                    
                    Text(viewModel.periodLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Colors.textPrimary)
                    
                    Button { 
                        withAnimation { viewModel.movePeriod(by: 1) }
                        selectedReportDate = Calendar.current.startOfDay(for: viewModel.referenceDate)
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.cardSurface)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(ReportPalette.accent)
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
                        selectedTrendPoint = nil
                    }
                    Task { await viewModel.refresh() }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isAllSelected ? ReportPalette.accent.opacity(0.14) : Color.clear)
                                .frame(width: 48, height: 48)
                            Image(systemName: isAllSelected ? "square.grid.2x2.fill" : "square.grid.2x2")
                                .font(.system(size: 20))
                                .foregroundColor(isAllSelected ? ReportPalette.accent : Colors.textSecondary)
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
                            selectedTrendPoint = nil
                        }
                        Task { await viewModel.refresh() }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? ReportPalette.accent.opacity(0.14) : Color.clear)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? ReportPalette.accent.opacity(0.3) : Colors.cardStroke, lineWidth: 1)
                                    )
                                
                                if item.icon.allSatisfy({ !$0.isASCII }) {
                                    Text(item.icon)
                                        .font(.system(size: 20))
                                } else {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(isSelected ? ReportPalette.accent : Colors.textSecondary)
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
                        selectedTrendPoint = nil
                        withAnimation { isPickerExpanded = false }
                        Task { await viewModel.refresh() }
                    } label: {
                        Text("Overall View")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
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
                                    selectedTrendPoint = nil
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
                                            .foregroundColor(Colors.textPrimary)
                                        
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

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trend")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(viewModel.availableTrendGroupings) { grouping in
                        let isSelected = viewModel.trendGrouping == grouping
                        Button {
                            Task { await viewModel.updateTrendGrouping(grouping) }
                        } label: {
                            Text(grouping.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? ReportPalette.accent.opacity(0.22) : Colors.bgSecondary.opacity(0.5))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(trendValueText(from: selectedTrendPoint ?? viewModel.trends.last))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Average")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                    Text(String(format: "%.1f %@", trendAverageValue, trendUnitLabel))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }

                Spacer()
            }

            if let selectedTrendPoint {
                Text(trendDateLabel(for: selectedTrendPoint.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                reportTrendYAxis
                    .frame(width: reportTrendAxisWidth, height: reportTrendChartHeight)
                    .padding(.bottom, reportTrendBottomInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .bottomLeading) {
                        reportTrendGrid(width: reportTrendContentWidth)
                            .frame(width: reportTrendContentWidth, height: reportTrendChartHeight)
                            .padding(.bottom, reportTrendBottomInset)

                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(viewModel.trends) { point in
                                let isSelected = selectedTrendPoint?.id == point.id
                                VStack(spacing: reportTrendVerticalSpacing) {
                                    if isSelected {
                                        Text(String(format: "%.0f", point.value))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Colors.textPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(ReportPalette.accent.opacity(0.22))
                                            )
                                    } else {
                                        Color.clear.frame(height: reportTrendBubbleHeight)
                                    }

                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(ReportPalette.accent.opacity(0.14))
                                            .frame(width: 22, height: reportTrendChartHeight)
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    colors: isSelected
                                                        ? [ReportPalette.accent, ReportPalette.accentDark]
                                                        : [ReportPalette.accent.opacity(0.62), ReportPalette.accentDark.opacity(0.42)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 22, height: trendBarHeight(for: point))
                                    }

                                    Text(point.label)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                                        .frame(height: reportTrendLabelHeight)
                                }
                                .frame(width: 30, height: reportTrendTotalHeight, alignment: .bottom)
                                .overlay {
                                    if isSelected {
                                        Path { path in
                                            let x = reportTrendSlotWidth / 2
                                            let yStart = reportTrendBubbleHeight + (reportTrendVerticalSpacing * 0.4)
                                            let yEnd = reportTrendBubbleHeight + reportTrendVerticalSpacing + reportTrendChartHeight
                                            path.move(to: CGPoint(x: x, y: yStart))
                                            path.addLine(to: CGPoint(x: x, y: yEnd))
                                        }
                                        .stroke(
                                            Colors.textSecondary.opacity(0.65),
                                            style: StrokeStyle(lineWidth: 1.1, dash: [4, 3])
                                        )
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTrendPoint = point
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelectedTrendPoint(at: value.location.x - 2)
                                }
                                .onEnded { value in
                                    updateSelectedTrendPoint(at: value.location.x - 2)
                                }
                        )
                    }
                    .frame(width: reportTrendContentWidth, height: reportTrendTotalHeight, alignment: .bottom)
                }
            }
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private var selectedDayMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Day")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text(selectedReportDateLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                switch viewModel.selectedDomain {
                case .alarms:
                    KPICard(icon: "bell.badge.fill", iconColor: .orange, value: "\(viewModel.dayMetrics.firedCount)", unit: "fires", label: "Triggered")
                    KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.dayMetrics.dismissedCount)", unit: "done", label: "Dismissed")
                    KPICard(icon: "zzz", iconColor: .purple, value: "\(viewModel.dayMetrics.snoozeCount)", unit: "times", label: "Snoozed")
                    KPICard(icon: "xmark.circle.fill", iconColor: .red, value: "\(viewModel.dayMetrics.missedCount)", unit: "missed", label: "Missed")
                case .habits:
                    KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.dayMetrics.totalDone)", unit: "done", label: "Completed")
                    KPICard(icon: "chart.pie.fill", iconColor: .blue, value: String(format: "%.0f", viewModel.dayMetrics.completionRate * 100), unit: "%", label: "Success")
                    KPICard(icon: "flame.fill", iconColor: .orange, value: "\(viewModel.dayMetrics.currentStreak)", unit: "days", label: "Streak")
                    KPICard(icon: "sparkles", iconColor: .purple, value: "\(viewModel.dayMetrics.perfectDays)", unit: "day", label: "Perfect")
                case .pomodoro:
                    KPICard(icon: "checkmark.circle.fill", iconColor: .green, value: "\(viewModel.dayMetrics.completedCount)", unit: "done", label: "Completed")
                    KPICard(icon: "play.circle.fill", iconColor: .blue, value: "\(viewModel.dayMetrics.startedCount)", unit: "start", label: "Started")
                    KPICard(icon: "pause.circle.fill", iconColor: .orange, value: "\(viewModel.dayMetrics.interruptedCount)", unit: "break", label: "Interrupted")
                    KPICard(icon: "clock.fill", iconColor: .purple, value: String(format: "%.0f", viewModel.dayMetrics.focusMinutes), unit: "min", label: "Focus Time")
                }
            }
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var selectedHabitOverviewSection: some View {
        if let selectedHabit = selectedHabitInfo {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ReportPalette.accent.opacity(0.15))
                            .frame(width: 46, height: 46)

                        if selectedHabit.icon.allSatisfy({ !$0.isASCII }) {
                            Text(selectedHabit.icon)
                                .font(.system(size: 22))
                        } else {
                            Image(systemName: selectedHabit.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(ReportPalette.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedHabit.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .lineLimit(1)
                        Text("Goal: \(formattedGoalValue(selectedHabit.goalValue)) \(normalizedGoalUnit(selectedHabit.goalUnit)) / day")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Consistency")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Text("\(Int((viewModel.metrics.completionRate * 100).rounded()))%")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(ReportPalette.accent)
                    }
                }

                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.24))
                        Text("\(viewModel.metrics.currentStreak) day streak!")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                        Text(streakMotivation(for: viewModel.metrics.currentStreak))
                            .font(.subheadline)
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(selectedHabitWeekSnapshots) { snapshot in
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(snapshot.hasLog ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                                        .frame(width: 38, height: 38)

                                    Circle()
                                        .trim(from: 0, to: max(0.03, snapshot.intensity))
                                        .stroke(
                                            snapshot.goalMet ? ReportPalette.accent : ReportPalette.accent.opacity(0.8),
                                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 38, height: 38)

                                    Text(streakDayLabel(for: snapshot))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                }

                                Text(shortDayLabel(for: snapshot.date))
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Colors.bgSecondary.opacity(0.45))
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    reportStatTile(
                        title: "SUCCESS",
                        value: "\(selectedHabitSuccessDays) days",
                        detail: "Goal met",
                        icon: "checkmark",
                        tint: .green
                    )

                    reportStatTile(
                        title: "FAILED",
                        value: "\(selectedHabitFailedDays) days",
                        detail: "Below goal",
                        icon: "xmark",
                        tint: .red
                    )

                    reportStatTile(
                        title: "SKIPPED",
                        value: "\(selectedHabitSkippedDays) days",
                        detail: "No activity",
                        icon: "arrow.right",
                        tint: .orange
                    )

                    reportStatTile(
                        title: "CURRENT STREAK",
                        value: "\(viewModel.metrics.currentStreak) days",
                        detail: "Consecutive success",
                        icon: "flame.fill",
                        tint: ReportPalette.accent
                    )
                }
            }
            .padding(16)
            .background(Colors.cardSurface)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
        }
    }

    private var allHabitsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ReportPalette.accent.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ReportPalette.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("All Habits")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text("Goals + streak snapshot")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Avg Consistency")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Text("\(Int((viewModel.metrics.completionRate * 100).rounded()))%")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(ReportPalette.accent)
                }
            }

            HStack(spacing: 10) {
                reportPillMetric(title: "Habits", value: "\(viewModel.availableItems.count)")
                reportPillMetric(title: "Perfect Days", value: "\(viewModel.metrics.perfectDays)")
                reportPillMetric(title: "Done", value: "\(viewModel.metrics.totalDone)")
            }

            if !allHabitStreakLeaders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Streaks")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textSecondary)

                    ForEach(Array(allHabitStreakLeaders.prefix(3).enumerated()), id: \.element.id) { index, leader in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 16)

                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 28, height: 28)
                                if leader.icon.allSatisfy({ !$0.isASCII }) {
                                    Text(leader.icon)
                                        .font(.system(size: 15))
                                } else {
                                    Image(systemName: leader.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(ReportPalette.accent)
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(leader.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                    .lineLimit(1)
                                Text("Goal \(formattedGoalValue(leader.goalValue)) \(normalizedGoalUnit(leader.goalUnit))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("\(leader.streakDays)d")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Colors.bgSecondary.opacity(0.45))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private var selectedHabitInfo: ReportViewModel.ReportItemInfo? {
        guard let selectedId = viewModel.selectedItemId else { return nil }
        return viewModel.availableItems.first(where: { $0.id == selectedId })
    }

    private var reportPeriodTrackedDays: Int {
        let range = calculateRange()
        let endExclusive = min(range.end, Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? range.end)
        let dayCount = Calendar.current.dateComponents([.day], from: range.start, to: endExclusive).day ?? 0
        return max(dayCount, 1)
    }

    private var selectedHabitSuccessDays: Int {
        viewModel.metrics.perfectDays
    }

    private var selectedHabitFailedDays: Int {
        max(viewModel.metrics.habitActiveDays - selectedHabitSuccessDays, 0)
    }

    private var selectedHabitSkippedDays: Int {
        max(reportPeriodTrackedDays - viewModel.metrics.habitActiveDays, 0)
    }

    private var habitSignalMetrics: [HabitSignalMetric] {
        let trackedDays = max(reportPeriodTrackedDays, 1)
        let activeRate = min(max(Double(viewModel.metrics.habitActiveDays) / Double(trackedDays), 0), 1)
        let perfectRate = min(max(Double(viewModel.metrics.perfectDays) / Double(trackedDays), 0), 1)
        let streakRate: Double = {
            let denominator = max(viewModel.metrics.bestStreak, viewModel.metrics.currentStreak, 1)
            return min(max(Double(viewModel.metrics.currentStreak) / Double(denominator), 0), 1)
        }()

        return [
            HabitSignalMetric(
                label: "Completion",
                valueText: "\(Int((viewModel.metrics.completionRate * 100).rounded()))%",
                normalizedValue: viewModel.metrics.completionRate
            ),
            HabitSignalMetric(
                label: "Month",
                valueText: "\(Int((viewModel.metrics.monthRate * 100).rounded()))%",
                normalizedValue: viewModel.metrics.monthRate
            ),
            HabitSignalMetric(
                label: "Today",
                valueText: "\(Int((viewModel.metrics.todayRate * 100).rounded()))%",
                normalizedValue: viewModel.metrics.todayRate
            ),
            HabitSignalMetric(
                label: "Active",
                valueText: "\(viewModel.metrics.habitActiveDays)d",
                normalizedValue: activeRate
            ),
            HabitSignalMetric(
                label: "Perfect",
                valueText: "\(viewModel.metrics.perfectDays)d",
                normalizedValue: perfectRate
            ),
            HabitSignalMetric(
                label: "Streak",
                valueText: "\(viewModel.metrics.currentStreak)d",
                normalizedValue: streakRate
            )
        ]
    }

    private var selectedHabitWeekSnapshots: [HabitWeekSnapshot] {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: viewModel.referenceDate)
        return (0..<7).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: -(6 - index), to: anchorDay) else {
                return nil
            }
            let key = calendar.startOfDay(for: day)
            let value = viewModel.heatmap[key] ?? 0
            return HabitWeekSnapshot(date: key, value: value)
        }
    }

    private var allHabitStreakLeaders: [HabitStreakLeader] {
        let descriptor = FetchDescriptor<PlanItem>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        let activeHabits = items.filter { $0.type == .habit && $0.parentTask == nil && !$0.isArchived }

        return activeHabits
            .map { item in
                HabitStreakLeader(
                    id: item.id,
                    title: item.title,
                    icon: item.iconName,
                    goalValue: item.goalValue,
                    goalUnit: item.goalUnit,
                    streakDays: habitCurrentStreak(for: item)
                )
            }
            .sorted {
                if $0.streakDays == $1.streakDays {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.streakDays > $1.streakDays
            }
    }

    private func habitCurrentStreak(for item: PlanItem) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            if item.isGoalMet(on: day) {
                streak += 1
            } else if !calendar.isDateInToday(day) {
                break
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previous
        }

        return streak
    }

    private func streakMotivation(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start today and build your first streak."
        case 1...2:
            return "Good start. Keep momentum going."
        case 3...6:
            return "Nice consistency. You are building rhythm."
        default:
            return "Strong streak. Keep compounding it."
        }
    }

    private func shortDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let index = calendar.component(.weekday, from: date) - 1
        let labels = calendar.veryShortStandaloneWeekdaySymbols
        guard index >= 0 && index < labels.count else { return "-" }
        return labels[index]
    }

    private func streakDayLabel(for snapshot: HabitWeekSnapshot) -> String {
        guard snapshot.hasLog else { return "—" }
        return "\(Int((snapshot.intensity * 100).rounded()))%"
    }

    private func formattedGoalValue(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func normalizedGoalUnit(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "times" : trimmed
    }

    private func reportPillMetric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Colors.bgSecondary.opacity(0.45))
        )
    }

    private func reportStatTile(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(tint)

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Colors.bgSecondary.opacity(0.42))
        )
    }

    private var trendAverageValue: Double {
        guard !viewModel.trends.isEmpty else { return 0 }
        return viewModel.trends.map(\.value).reduce(0, +) / Double(viewModel.trends.count)
    }

    private var trendUnitLabel: String {
        switch viewModel.selectedDomain {
        case .alarms:
            return "alarms"
        case .habits:
            return "done"
        case .pomodoro:
            return "sessions"
        }
    }

    private var selectedReportDateLabel: String {
        guard let selectedReportDate else { return "No day selected" }
        return selectedReportDate.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func trendValueText(from point: TrendPoint?) -> String {
        let value = point?.value ?? 0
        let unit = trendUnitLabel
        return "\(Int(value.rounded())) \(unit)"
    }

    private func trendDateLabel(for date: Date) -> String {
        switch viewModel.trendGrouping {
        case .day:
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        case .week:
            return "Week \(Calendar.current.component(.weekOfYear, from: date))"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func trendBarHeight(for point: TrendPoint) -> CGFloat {
        let normalized = min(max(point.value / reportTrendMaxValue, 0), 1)
        return max(10, CGFloat(normalized) * reportTrendChartHeight)
    }

    private var reportTrendAxisWidth: CGFloat { 56 }

    private var reportTrendChartHeight: CGFloat { 92 }

    private var reportTrendBubbleHeight: CGFloat { 21 }

    private var reportTrendLabelHeight: CGFloat { 14 }

    private var reportTrendVerticalSpacing: CGFloat { 6 }

    private var reportTrendBottomInset: CGFloat {
        reportTrendLabelHeight + reportTrendVerticalSpacing
    }

    private var reportTrendTotalHeight: CGFloat {
        reportTrendBubbleHeight + reportTrendVerticalSpacing + reportTrendChartHeight + reportTrendVerticalSpacing + reportTrendLabelHeight
    }

    private var reportTrendContentWidth: CGFloat {
        guard !viewModel.trends.isEmpty else { return 0 }
        let barCount = viewModel.trends.count
        let totalBarWidth = barCount * Int(reportTrendSlotWidth)
        let totalSpacing = max(barCount - 1, 0) * Int(reportTrendSlotSpacing)
        let total = totalBarWidth + totalSpacing + 4
        return CGFloat(total)
    }

    private var reportTrendSlotWidth: CGFloat { 30 }

    private var reportTrendSlotSpacing: CGFloat { 10 }

    private var reportTrendMaxValue: Double {
        let maxValue = max(viewModel.trends.map(\.value).max() ?? 0, 1)
        let rounded = roundedAxisCeiling(maxValue * 1.12)
        if usesKilometerTrendScale {
            return max(10, rounded)
        }
        return rounded
    }

    private var reportTrendTickValues: [Double] {
        let steps = 4
        return (0...steps).map { index in
            (reportTrendMaxValue / Double(steps)) * Double(index)
        }
    }

    private var usesKilometerTrendScale: Bool {
        guard viewModel.selectedDomain == .habits,
              let selectedId = viewModel.selectedItemId,
              let selectedItem = viewModel.availableItems.first(where: { $0.id == selectedId })
        else {
            return false
        }
        let unit = selectedItem.goalUnit.lowercased()
        return unit == "km" || unit.contains("kilometer") || unit.contains("kilometre")
    }

    private var reportTrendYAxis: some View {
        GeometryReader { proxy in
            let values = reportTrendTickValues
            let steps = max(values.count - 1, 1)

            ZStack(alignment: .topTrailing) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let progress = CGFloat(index) / CGFloat(steps)
                    let y = proxy.size.height - (progress * proxy.size.height)
                    Text(reportTrendAxisLabel(for: value))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .position(x: proxy.size.width - 2, y: y)
                }
            }
        }
    }

    private func reportTrendGrid(width: CGFloat) -> some View {
        Canvas { context, size in
            let steps = max(reportTrendTickValues.count - 1, 1)
            for index in 0...steps {
                let progress = CGFloat(index) / CGFloat(steps)
                let y = size.height - (progress * size.height)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))

                let isBaseline = index == 0
                context.stroke(
                    path,
                    with: .color(Colors.cardStroke.opacity(isBaseline ? 0.95 : 0.65)),
                    style: StrokeStyle(lineWidth: isBaseline ? 1.2 : 1, dash: isBaseline ? [] : [4, 3])
                )
            }
        }
    }

    private func reportTrendAxisLabel(for value: Double) -> String {
        if usesKilometerTrendScale {
            return "\(Int(value.rounded())) km"
        }
        if value >= 10 || abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func updateSelectedTrendPoint(at localX: CGFloat) {
        guard !viewModel.trends.isEmpty else {
            selectedTrendPoint = nil
            return
        }

        let stride = reportTrendSlotWidth + reportTrendSlotSpacing
        let normalizedX = max(0, localX)
        let rawIndex = Int(((normalizedX + (reportTrendSlotSpacing / 2)) / stride).rounded(.down))
        let index = min(max(rawIndex, 0), viewModel.trends.count - 1)
        let candidate = viewModel.trends[index]
        if selectedTrendPoint?.id != candidate.id {
            selectedTrendPoint = candidate
        }
    }

    private func roundedAxisCeiling(_ value: Double) -> Double {
        guard value > 0 else { return 1 }

        let exponent = floor(log10(value))
        let magnitude = pow(10, exponent)
        let normalized = value / magnitude

        let roundedNormalized: Double
        switch normalized {
        case ...1: roundedNormalized = 1
        case ...2: roundedNormalized = 2
        case ...2.5: roundedNormalized = 2.5
        case ...5: roundedNormalized = 5
        default: roundedNormalized = 10
        }

        return roundedNormalized * magnitude
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
            let normalizedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "count" : unit
            let isStepBased = unit.lowercased().contains("step")
            let isTimeBased = ["min", "minutes", "hr", "hours", "h"].contains(unit.lowercased())
            let isVolumeBased = ["ml", "oz", "l", "liters"].contains(unit.lowercased())
            let periodTotal = viewModel.metrics.habitValueTotal
            let activeDays = viewModel.metrics.habitActiveDays
            let dailyValueAverage = viewModel.metrics.habitValueDailyAverage
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // Row 1: Period completion summary
                KPICard(
                    icon: "calendar.badge.checkmark",
                    iconColor: .blue,
                    value: "\(viewModel.metrics.perfectDays)",
                    unit: "days",
                    label: "Perfect \(periodSummaryLabel)"
                )
                
                KPICard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    value: "\(viewModel.metrics.totalDone)",
                    unit: "done",
                    label: "Done \(periodSummaryLabel)"
                )
                
                // Row 2: Current Streak, Best Streak
                KPICard(
                    icon: "layers.fill",
                    iconColor: .purple,
                    value: "\(viewModel.metrics.currentStreak)",
                    unit: "days",
                    label: "Current Streak"
                )
                
                KPICard(
                    icon: "medal.fill",
                    iconColor: .orange,
                    value: "\(viewModel.metrics.bestStreak)",
                    unit: "days",
                    label: "Best Streak"
                )
                
                // Row 3: Period quantity + active days
                if isStepBased {
                    KPICard(
                        icon: "chart.bar.fill",
                        iconColor: .green,
                        value: String(format: "%.0f", periodTotal),
                        unit: "steps",
                        label: "Steps \(periodSummaryLabel)"
                    )
                    
                    KPICard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .pink,
                        value: "\(activeDays)",
                        unit: "days",
                        label: "Active Days"
                    )
                } else if isTimeBased {
                    KPICard(
                        icon: "clock.fill",
                        iconColor: .green,
                        value: String(format: "%.0f", periodTotal),
                        unit: normalizedUnit,
                        label: "Time \(periodSummaryLabel)"
                    )
                    
                    KPICard(
                        icon: "hourglass",
                        iconColor: .pink,
                        value: "\(activeDays)",
                        unit: "days",
                        label: "Active Days"
                    )
                } else if isVolumeBased {
                    KPICard(
                        icon: "drop.fill",
                        iconColor: .blue,
                        value: String(format: "%.0f", periodTotal),
                        unit: normalizedUnit,
                        label: "Volume \(periodSummaryLabel)"
                    )
                    
                    KPICard(
                        icon: "drop.triangle.fill",
                        iconColor: .cyan,
                        value: "\(activeDays)",
                        unit: "days",
                        label: "Active Days"
                    )
                } else {
                    KPICard(
                        icon: "number",
                        iconColor: .green,
                        value: String(format: "%.0f", periodTotal),
                        unit: normalizedUnit,
                        label: "Count \(periodSummaryLabel)"
                    )
                    
                    KPICard(
                        icon: "sum",
                        iconColor: .pink,
                        value: "\(activeDays)",
                        unit: "days",
                        label: "Active Days"
                    )
                }
                
                // Row 4: Daily average + completion rate
                KPICard(
                    icon: "chart.xyaxis.line",
                    iconColor: .purple,
                    value: String(format: "%.1f", dailyValueAverage),
                    unit: isStepBased ? "steps/day" : "\(normalizedUnit)/day",
                    label: "Daily Average"
                )
                
                KPICard(
                    icon: "chart.pie.fill",
                    iconColor: .blue,
                    value: String(format: "%.2f", viewModel.metrics.completionRate * 100),
                    unit: "%",
                    label: "Completion Rate"
                )
            }
        }
    }

    private var periodSummaryLabel: String {
        switch viewModel.selectedPeriod {
        case .week:
            return "this week"
        case .month:
            return "this month"
        case .year:
            return "this year"
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

    private var pomodoroSpecificKPIs: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pomodoro Performance")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                KPICard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    value: "\(viewModel.metrics.completedCount)",
                    unit: "done",
                    label: "Completed Sessions"
                )

                KPICard(
                    icon: "play.circle.fill",
                    iconColor: .blue,
                    value: "\(viewModel.metrics.startedCount)",
                    unit: "start",
                    label: "Started Sessions"
                )

                KPICard(
                    icon: "pause.circle.fill",
                    iconColor: .orange,
                    value: "\(viewModel.metrics.interruptedCount)",
                    unit: "break",
                    label: "Interrupted"
                )

                KPICard(
                    icon: "clock.fill",
                    iconColor: .purple,
                    value: String(format: "%.0f", viewModel.metrics.focusMinutes),
                    unit: "min",
                    label: "Focus Time"
                )

                KPICard(
                    icon: "chart.pie.fill",
                    iconColor: .teal,
                    value: String(format: "%.1f", viewModel.metrics.completionRate * 100),
                    unit: "%",
                    label: "Completion Rate"
                )

                KPICard(
                    icon: "flame.fill",
                    iconColor: .pink,
                    value: "\(viewModel.metrics.currentStreak)",
                    unit: "days",
                    label: "Current Streak"
                )
            }
        }
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
