import SwiftUI
import Charts

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
                    LinearGradient(colors: [Colors.accentBlue, .purple], startPoint: .top, endPoint: .bottom),
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
        .background(Colors.cardSurface)
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
                    .foregroundStyle(Colors.accentBlue.gradient)
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
                            .foregroundColor(Colors.accentBlue)
                            .padding(6)
                            .background(Colors.accentBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button { onMove(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Colors.accentBlue)
                            .padding(6)
                            .background(Colors.accentBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // Summary Text
                let activeDays = heatmap.values.filter { $0 > 0 }.count
                Text("\(activeDays) Active Days")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.accentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Colors.accentBlue.opacity(0.1))
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
                                        .foregroundColor(calendar.isDateInToday(date) ? Colors.accentBlue : Colors.textPrimary)
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
                                    .stroke(Colors.accentBlue.opacity(0.6), lineWidth: 1.5)
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
        if value < 1 { return Colors.accentBlue.opacity(0.3) }
        if value < 2 { return Colors.accentBlue.opacity(0.6) }
        return Colors.accentBlue
    }
}

// MARK: - New Premium Consistency Components

struct OverallMonthCalendarView: View {
    let heatmap: [Date: Double]
    let referenceDate: Date
    let onMove: (Int) -> Void
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 20) {
            // Week Navigation Header
            HStack {
                Button { onMove(-1) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Colors.textPrimary)
                        .padding(8)
                }
                
                Spacer()
                
                Text(weekRangeText)
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
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Week Days with Progress Rings
            HStack(spacing: 4) {
                ForEach(generateWeekDays(), id: \.self) { date in
                    let isToday = calendar.isDateInToday(date)
                    let value = heatmap[calendar.startOfDay(for: date)] ?? 0
                    let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                    let progress = min(value, 1.0) // Normalize to 0-1 range
                    
                    VStack(spacing: 4) {
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Colors.textTertiary.opacity(0.2), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            
                            // Progress ring
                            if progress > 0 {
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        Colors.accentBlue,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 44, height: 44)
                                    .rotationEffect(.degrees(-90))
                            }
                            
                            // Selection indicator
                            if isSelected {
                                Circle()
                                    .fill(Colors.accentBlue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Day number
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
            .padding(.horizontal, 8)
        }
        .padding(24)
        .background(Colors.cardSurface)
        .cornerRadius(32)
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Colors.cardStroke, lineWidth: 1))
    }
    
    private var weekRangeText: String {
        let weekDays = generateWeekDays()
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.yyyy"
        return formatter.string(from: first)
    }
    
    private func generateWeekDays() -> [Date] {
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        comps.weekday = calendar.firstWeekday
        guard let weekStart = calendar.date(from: comps) else { return [] }
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
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
                                    .fill(isSelected ? Colors.accentBlue.opacity(0.15) : Color.clear)
                                    .frame(width: 50, height: 50)
                                
                                if value > 0 {
                                    Circle()
                                        .trim(from: 0, to: min(value, 1.0))
                                        .stroke(Colors.accentBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .frame(width: 50, height: 50)
                                        .rotationEffect(.degrees(-90))
                                } else if isToday {
                                    Circle()
                                        .stroke(Colors.accentBlue.opacity(0.3), lineWidth: 2)
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
                                    .fill(Colors.accentBlue)
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
                                .stroke(Colors.accentBlue.opacity(i == 0 ? 0.1 : i), lineWidth: 1.5)
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
    @Namespace private var modeNamespace
    
    enum ViewMode: String, CaseIterable {
        case yearly = "Yearly"
        case monthly = "Monthly"
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(0..<53, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { day in
                            if let d = dateFor(week: week, day: day), calendar.component(.year, from: d) == year {
                                let value = heatmap[calendar.startOfDay(for: d)] ?? 0
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForValue(value))
                                    .frame(width: 10, height: 10)
                            } else {
                                Color.clear.frame(width: 10, height: 10)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
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
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                // Padding for first day
                let weekday = calendar.component(.weekday, from: monthStart)
                // Adjust for calendar.firstWeekday (typically 1 for Sunday or 2 for Monday)
                let padding = (weekday - calendar.firstWeekday + 7) % 7
                
                ForEach(0..<padding, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                        let value = heatmap[calendar.startOfDay(for: d)] ?? 0
                        let isToday = calendar.isDateInToday(d)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorForValue(value))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isToday ? Colors.accentBlue : Colors.cardStroke.opacity(0.3), lineWidth: isToday ? 2 : 1)
                                )
                            
                            Text("\(day)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(value > 0.4 ? .white : (isToday ? Colors.accentBlue : Colors.textPrimary))
                        }
                    }
                }
            }
        }
    }
    
    private func dateFor(week: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.weekOfYear = week + 1
        comps.weekday = (calendar.firstWeekday + day - 1) % 7 + 1
        return calendar.date(from: comps)
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value <= 0 { return Color.white.opacity(0.05) }
        if value < 1 { return Colors.accentBlue.opacity(0.3) }
        if value < 2 { return Colors.accentBlue.opacity(0.6) }
        return Colors.accentBlue
    }
}
