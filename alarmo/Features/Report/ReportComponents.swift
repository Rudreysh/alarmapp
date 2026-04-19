import SwiftUI
import Charts

enum ReportPalette {
    static let accent = Color(red: 0.08, green: 0.78, blue: 0.92)
    static let accentDark = Color(red: 0.05, green: 0.34, blue: 0.52)
    static let glow = Color(red: 0.28, green: 0.88, blue: 0.98)
    static let cardStart = Colors.cardSurface
    static let cardEnd = Colors.bgSecondary.opacity(0.9)
    static let accentGradient = LinearGradient(
        colors: [accent, glow.opacity(0.82), accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct RingProgressView: View {
    let progress: Double
    let subtitle: String
    
    var body: some View {
        let clampedProgress = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .stroke(Colors.cardStroke, lineWidth: 20)
            
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    ReportPalette.accentGradient,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: clampedProgress)
            
            VStack(spacing: 4) {
                Text("\(Int(clampedProgress * 100))%")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .frame(width: 200, height: 200)
    }
}

struct KPICard: View {
    let title: String?
    let value: String
    let icon: String
    let color: Color
    let unit: String?
    let label: String?
    
    // Old initializer for backward compatibility
    init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.unit = nil
        self.label = nil
    }
    
    // New initializer matching the image design
    init(icon: String, iconColor: Color, value: String, unit: String, label: String) {
        self.title = nil
        self.value = value
        self.icon = icon
        self.color = iconColor
        self.unit = unit
        self.label = label
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if let unit = unit, let label = label {
                    // New format: Large value with unit
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textSecondary)
                } else {
                    // Old format
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    if let title = title {
                        Text(title)
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Colors.cardSurface, Colors.bgSecondary.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
}

struct ActivityTrendChart: View {
    let points: [TrendPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Trend")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Date", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(ReportPalette.accentGradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(20)
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
}

struct HeatmapGridView: View {
    let domain: ReportDomain
    let heatmap: [Date: Double]
    let startDate: Date
    let endDate: Date
    let period: ReportPeriod
    let onMove: (Int) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    @State private var selectedDate: Date? = nil
    
    private var weekLabels: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols // ["Sun", "Mon", ...]
        var labels: [String] = []
        for i in 0..<7 {
            let index = (calendar.firstWeekday - 1 + i) % 7
            labels.append(String(symbols[index].first ?? " "))
        }
        return labels
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Consistency")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                // Card Navigation
                HStack(spacing: 8) {
                    Button { onMove(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ReportPalette.accent)
                            .padding(6)
                            .background(ReportPalette.accent.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Button { onMove(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ReportPalette.accent)
                            .padding(6)
                            .background(ReportPalette.accent.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                
                // Summary Text
                let activeDays = heatmap.values.filter { $0 > 0 }.count
                Text("\(activeDays) Active Days")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ReportPalette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ReportPalette.accent.opacity(0.12))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                // Weekday Labels
                HStack(spacing: 0) {
                    ForEach(0..<7) { index in
                        VStack(spacing: 4) {
                            Text(weekLabels[index])
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                            
                            if period == .week {
                                if let date = calendar.date(byAdding: .day, value: index, to: startDate) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(calendar.isDateInToday(date) ? ReportPalette.accent : Colors.textPrimary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                LazyVGrid(columns: columns, spacing: 5) {
                    // Padding for first week alignment
                    ForEach(0..<calculatePadding(), id: \.self) { _ in
                        Rectangle().fill(Color.clear).aspectRatio(1, contentMode: .fit)
                    }
                    
                    ForEach(generateHistoryDays(), id: \.self) { date in
                        let value = heatmap[calendar.startOfDay(for: date)] ?? 0
                        let isFuture = date > Date()
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                        
                        ZStack {
                            Rectangle()
                                .fill(colorForValue(value))
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(4)
                                .opacity(isFuture ? 0.1 : 1.0)
                            
                            if isToday {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(ReportPalette.accent.opacity(0.6), lineWidth: 1.5)
                            }
                            
                            if isSelected {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                    }
                }
            }
            
            // Selection Detail & Legend
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if let selected = selectedDate {
                        let val = heatmap[calendar.startOfDay(for: selected)] ?? 0
                        Text("\(val == 0 ? "No" : String(format: "%.0f", val)) activity")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Text(selected.formatted(.dateTime.day().month().year()))
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textTertiary)
                    } else {
                        Text("Select a day")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Legend
                HStack(spacing: 4) {
                    Text("Less").font(.system(size: 10)).foregroundColor(Colors.textTertiary)
                    ForEach([0, 0.5, 1, 2], id: \.self) { i in
                        Rectangle()
                            .fill(colorForValue(Double(i)))
                            .frame(width: 12, height: 12)
                            .cornerRadius(3)
                    }
                    Text("More").font(.system(size: 10)).foregroundColor(Colors.textTertiary)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .onAppear {
            if selectedDate == nil {
                selectedDate = calendar.startOfDay(for: Date())
            }
        }
    }
    
    private func generateHistoryDays() -> [Date] {
        // Show at least 5 weeks total to give a sense of consistency
        let historyStart = calendar.date(byAdding: .weekOfYear, value: -4, to: startDate)!
        var days: [Date] = []
        var current = historyStart
        while current < endDate {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
    
    private func calculatePadding() -> Int {
        let historyStart = calendar.date(byAdding: .weekOfYear, value: -4, to: startDate)!
        let firstDay = calendar.component(.weekday, from: historyStart)
        let shift = (firstDay - calendar.firstWeekday + 7) % 7
        return shift
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value <= 0 { return Color.white.opacity(0.05) }
        if value < 1 { return ReportPalette.accent.opacity(0.30) }
        if value < 2 { return ReportPalette.accent.opacity(0.62) }
        return ReportPalette.accent
    }
}

// MARK: - New Premium Consistency Components

struct OverallMonthCalendarView: View {
    let heatmap: [Date: Double]
    let period: ReportPeriod
    let referenceDate: Date
    let onMove: (Int) -> Void
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.current
    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let yearColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    
    var body: some View {
        VStack(spacing: 20) {
            // Period Navigation Header
            HStack {
                Button { onMove(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Colors.textPrimary)
                        .padding(8)
                }
                
                Spacer()
                
                Text(periodTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                Button { onMove(1) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textPrimary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 10)
            
            switch period {
            case .week:
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(spacing: 4) {
                        ForEach(generateWeekDays(), id: \.self) { date in
                            let isToday = calendar.isDateInToday(date)
                            let value = heatmap[calendar.startOfDay(for: date)] ?? 0
                            let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                            let progress = min(max(value, 0), 1.0)

                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(Colors.textTertiary.opacity(0.2), lineWidth: 2)
                                        .frame(width: 44, height: 44)

                                    if progress > 0 {
                                        Circle()
                                            .trim(from: 0, to: progress)
                                            .stroke(
                                                ReportPalette.accent,
                                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                            )
                                            .frame(width: 44, height: 44)
                                            .rotationEffect(.degrees(-90))
                                    }

                                    if isSelected {
                                        Circle()
                                            .fill(ReportPalette.accent.opacity(0.14))
                                            .frame(width: 44, height: 44)
                                    }

                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 16, weight: isToday ? .bold : .medium))
                                        .foregroundColor(Colors.textPrimary)
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = date
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            case .month:
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: monthColumns, spacing: 6) {
                        ForEach(monthCells.indices, id: \.self) { index in
                            if let date = monthCells[index] {
                                let isToday = calendar.isDateInToday(date)
                                let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                                let value = heatmap[calendar.startOfDay(for: date)] ?? 0

                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorForValue(value))
                                        .frame(height: 36)

                                    if isToday {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(ReportPalette.accent.opacity(0.65), lineWidth: 1.2)
                                            .frame(height: 36)
                                    }

                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.85), lineWidth: 1.6)
                                            .frame(height: 36)
                                    }

                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                                        .foregroundColor(Colors.textPrimary)
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = date
                                    }
                                }
                            } else {
                                Color.clear
                                    .frame(height: 36)
                            }
                        }
                    }
                }
            case .year:
                LazyVGrid(columns: yearColumns, spacing: 12) {
                    ForEach(yearMonths, id: \.self) { monthStart in
                        let rate = monthAverage(for: monthStart)
                        let activeDays = monthActiveDays(for: monthStart)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(monthTitle(for: monthStart))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text("\(Int(rate * 100))%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Colors.textTertiary.opacity(0.18))
                                    Capsule()
                                        .fill(ReportPalette.accentGradient)
                                        .frame(width: proxy.size.width * min(max(rate, 0), 1))
                                }
                            }
                            .frame(height: 8)

                            Text("\(activeDays) active day\(activeDays == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(12)
                        .background(Colors.bgPrimary.opacity(0.45))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(24)
        .background(Colors.cardSurface)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Colors.cardStroke, lineWidth: 1))
    }
    
    private var periodTitle: String {
        let formatter = DateFormatter()
        switch period {
        case .week:
            let weekDays = generateWeekDays()
            guard let first = weekDays.first, let last = weekDays.last else { return "" }
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: referenceDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: referenceDate)
        }
    }
    
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return (0..<7).map { index in
            let actual = (calendar.firstWeekday - 1 + index) % 7
            return String(symbols[actual].prefix(1))
        }
    }

    private func generateWeekDays() -> [Date] {
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        comps.weekday = calendar.firstWeekday
        guard let weekStart = calendar.date(from: comps) else { return [] }
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var monthCells: [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2

        var cells = Array<Date?>(repeating: nil, count: leadingPadding)
        for dayOffset in 0..<dayRange.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var yearMonths: [Date] {
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: referenceDate))!
        return (0..<12).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: yearStart)
        }
    }

    private func monthAverage(for monthStart: Date) -> Double {
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }
        var cursor = monthStart
        var values: [Double] = []
        while cursor < monthEnd {
            let value = heatmap[calendar.startOfDay(for: cursor)] ?? 0
            values.append(min(max(value, 0), 1))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func monthActiveDays(for monthStart: Date) -> Int {
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }
        var cursor = monthStart
        var active = 0
        while cursor < monthEnd {
            if (heatmap[calendar.startOfDay(for: cursor)] ?? 0) > 0 {
                active += 1
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return active
    }

    private func monthTitle(for monthStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthStart)
    }

    private func colorForValue(_ value: Double) -> Color {
        if value <= 0 { return Color.white.opacity(0.06) }
        if value < 0.34 { return ReportPalette.accent.opacity(0.28) }
        if value < 0.67 { return ReportPalette.accent.opacity(0.55) }
        return ReportPalette.accent.opacity(0.85)
    }
}

struct HabitCalendarView: View {
    let heatmap: [Date: Double]
    let referenceDate: Date
    let onMove: (Int) -> Void
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.current
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 24) {
                // Week Navigation Header
                HStack {
                    Button { onMove(-1) } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Colors.textTertiary)
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    Text(weekRangeText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    Button { onMove(1) } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(Colors.textTertiary)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 10)
                
                // Week Days Grid
                HStack(spacing: 4) {
                    ForEach(generateWeekDays(), id: \.self) { date in
                        let isToday = calendar.isDateInToday(date)
                        let value = heatmap[calendar.startOfDay(for: date)] ?? 0
                        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                        let dayLetter = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1].prefix(1)
                        
                        VStack(spacing: 8) {
                            Text(String(dayLetter))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                            
                            ZStack {
                                Circle()
                                    .fill(isSelected ? ReportPalette.accent.opacity(0.14) : Color.clear)
                                    .frame(width: 50, height: 50)
                                
                                if value > 0 {
                                    Circle()
                                        .trim(from: 0, to: min(value, 1.0))
                                        .stroke(ReportPalette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .frame(width: 50, height: 50)
                                        .rotationEffect(.degrees(-90))
                                } else if isToday {
                                    Circle()
                                        .stroke(ReportPalette.accent.opacity(0.3), lineWidth: 2)
                                        .frame(width: 50, height: 50)
                                }
                                
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 18, weight: isToday ? .bold : .medium))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                }
                            }
                            
                            if value > 1.1 {
                                Circle()
                                    .fill(ReportPalette.accent)
                                    .frame(width: 4, height: 4)
                            } else {
                                Color.clear.frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                
                Divider().background(Colors.cardStroke)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let selected = selectedDate {
                            let val = heatmap[calendar.startOfDay(for: selected)] ?? 0
                            Text("\(val == 0 ? "No" : String(format: "%.0f", val)) activity")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                            Text(selected.formatted(.dateTime.day().month().year()))
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        } else {
                            Text("Select a day")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Less").font(.system(size: 10)).foregroundColor(Colors.textTertiary)
                        ForEach([0, 0.3, 0.6, 1.0], id: \.self) { i in
                            Circle()
                                .stroke(ReportPalette.accent.opacity(i == 0 ? 0.1 : i), lineWidth: 1.5)
                                .frame(width: 10, height: 10)
                        }
                        Text("More").font(.system(size: 10)).foregroundColor(Colors.textTertiary)
                    }
                }
            }
            .frame(width: geo.size.width)
            .padding(24)
            .background(Colors.cardSurface)
            .cornerRadius(32)
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Colors.cardStroke, lineWidth: 1))
        }
        .frame(height: 280)
    }
    
    private var weekRangeText: String {
        let weekDays = generateWeekDays()
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
    
    private func generateWeekDays() -> [Date] {
        // Get the start of the week for the reference date
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return []
        }
        
        // Generate 7 days starting from the week start
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }
}

struct YearlyStatusView: View {
    let heatmap: [Date: Double]
    let year: Int
    let referenceDate: Date
    
    @State private var viewMode: ViewMode = .yearly
    @State private var isYearlyExpanded = false
    @Namespace private var modeNamespace
    
    enum ViewMode: String, CaseIterable {
        case yearly = "Yearly"
        case monthly = "Monthly"
    }

    private struct MonthStat: Identifiable {
        let month: Int
        let monthDate: Date
        let availableDays: Int
        let activeDays: Int
        let completionRate: Double
        let totalIntensity: Double
        let isCurrentMonth: Bool

        var id: Int { month }
    }
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewMode == .yearly ? "Yearly Status" : "Monthly Status")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text(labelString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                // Segmented Toggle
                HStack(spacing: 0) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        let isSelected = viewMode == mode
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewMode = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Colors.cardSurface)
                                                .matchedGeometryEffect(id: "mode_bg", in: modeNamespace)
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
                .cornerRadius(10)
            }
            
            if viewMode == .yearly {
                yearlyGrid
            } else {
                monthlyGrid
            }
        }
        .padding(24)
        .background(Colors.cardSurface)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Colors.cardStroke, lineWidth: 1))
    }
    
    private var labelString: String {
        if viewMode == .yearly {
            return String(year) // No comma
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            return formatter.string(from: referenceDate)
        }
    }
    
    private var yearlyGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                summaryChip(
                    title: "Active Days",
                    value: "\(yearlyActiveDays)"
                )
                summaryChip(
                    title: "Consistency",
                    value: "\(Int(yearlyConsistency * 100))%"
                )
                summaryChip(
                    title: "Best Month",
                    value: bestMonthLabel
                )
            }

            HStack(spacing: 10) {
                Text(isYearlyExpanded ? "All months" : "Current month")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        isYearlyExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isYearlyExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(isYearlyExpanded ? "Collapse" : "Expand")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(ReportPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ReportPalette.accent.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(displayedMonthStats) { stat in
                    monthCard(for: stat)
                }
            }
        }
    }
    
    private var monthlyGrid: some View {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysInMonth = range.count
        
        let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]
        
        return VStack(spacing: 12) {
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                // Padding for first day
                let weekday = calendar.component(.weekday, from: monthStart)
                let padding = (weekday - calendar.firstWeekday + 7) % 7
                
                ForEach(0..<padding, id: \.self) { _ in
                    Color.clear.frame(width: 40, height: 40)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                        let value = heatmap[calendar.startOfDay(for: d)] ?? 0
                        let isToday = calendar.isDateInToday(d)
                        let isFuture = d > Date()
                        let progress = min(value, 1.0)
                        
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(
                                    isToday ? ReportPalette.accent.opacity(0.3) : Colors.textTertiary.opacity(0.15),
                                    lineWidth: 2
                                )
                                .frame(width: 38, height: 38)
                            
                            // Progress ring
                            if progress > 0 && !isFuture {
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        ReportPalette.accent,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                    )
                                    .frame(width: 38, height: 38)
                                    .rotationEffect(.degrees(-90))
                            }
                            
                            // Today highlight ring
                            if isToday {
                                Circle()
                                    .stroke(ReportPalette.accent, lineWidth: 2)
                                    .frame(width: 38, height: 38)
                            }
                            
                            // Day number
                            Text("\(day)")
                                .font(.system(size: 13, weight: isToday ? .bold : .medium))
                                .foregroundColor(
                                    isFuture ? Colors.textTertiary.opacity(0.5) :
                                    isToday ? ReportPalette.accent :
                                    Colors.textPrimary
                                )
                        }
                        .opacity(isFuture ? 0.5 : 1.0)
                    }
                }
            }
        }
    }
    
    private var monthStats: [MonthStat] {
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        return (1...12).compactMap { month in
            guard
                let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
            else {
                return nil
            }

            let availableEnd: Date
            if year < currentYear {
                availableEnd = monthInterval.end
            } else if year > currentYear {
                availableEnd = monthInterval.start
            } else {
                availableEnd = min(monthInterval.end, endOfToday)
            }

            let availableDays = max(
                0,
                calendar.dateComponents([.day], from: monthInterval.start, to: max(monthInterval.start, availableEnd)).day ?? 0
            )

            var activeDays = 0
            var totalIntensity = 0.0

            if availableDays > 0 {
                var cursor = monthInterval.start
                while cursor < availableEnd {
                    let value = heatmap[calendar.startOfDay(for: cursor)] ?? 0
                    if value > 0 {
                        activeDays += 1
                    }
                    totalIntensity += value
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                    cursor = nextDay
                }
            }

            let completionRate = availableDays > 0 ? Double(activeDays) / Double(availableDays) : 0
            let isCurrentMonth = (year == currentYear && month == currentMonth)

            return MonthStat(
                month: month,
                monthDate: monthStart,
                availableDays: availableDays,
                activeDays: activeDays,
                completionRate: completionRate,
                totalIntensity: totalIntensity,
                isCurrentMonth: isCurrentMonth
            )
        }
    }

    private var yearlyActiveDays: Int {
        monthStats.reduce(0) { $0 + $1.activeDays }
    }

    private var yearlyAvailableDays: Int {
        monthStats.reduce(0) { $0 + $1.availableDays }
    }

    private var yearlyConsistency: Double {
        guard yearlyAvailableDays > 0 else { return 0 }
        return Double(yearlyActiveDays) / Double(yearlyAvailableDays)
    }

    private var bestMonthLabel: String {
        guard let best = monthStats.max(by: { $0.completionRate < $1.completionRate }), best.activeDays > 0 else {
            return "--"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: best.monthDate)
    }

    private var displayedMonthStats: [MonthStat] {
        if isYearlyExpanded {
            return monthStats
        }

        guard let focused = focusedMonthStat else {
            return []
        }
        return [focused]
    }

    private var focusedMonthStat: MonthStat? {
        if let current = monthStats.first(where: { $0.isCurrentMonth }) {
            return current
        }

        let selectedMonth = calendar.component(.month, from: referenceDate)
        if let selected = monthStats.first(where: { $0.month == selectedMonth }) {
            return selected
        }

        return monthStats.first
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Colors.bgPrimary.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private func monthCard(for stat: MonthStat) -> some View {
        let isFuture = stat.availableDays == 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(monthLabel(for: stat.monthDate))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Colors.textPrimary)

                if stat.isCurrentMonth {
                    Text("Now")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ReportPalette.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ReportPalette.accent.opacity(0.16))
                        .clipShape(Capsule())
                }
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: stat.completionRate)
                    .stroke(
                        LinearGradient(
                            colors: [ReportPalette.accent, ReportPalette.glow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(isFuture ? "--" : "\(Int(stat.completionRate * 100))")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Colors.textPrimary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                if isFuture {
                    Text("Upcoming")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                } else {
                    Text("\(stat.activeDays)/\(stat.availableDays) days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Text(String(format: "%.0f total", stat.totalIntensity))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Colors.bgPrimary.opacity(0.90),
                            Colors.cardSurface.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    stat.isCurrentMonth ? ReportPalette.accent.opacity(0.45) : Colors.cardStroke,
                    lineWidth: stat.isCurrentMonth ? 1.2 : 1
                )
        )
        .opacity(isFuture ? 0.62 : 1)
    }
}
