import SwiftUI
import SwiftData

private enum HabitDetailTab: String, CaseIterable, Identifiable {
    case overview
    case statistics
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .statistics: return "Statistics"
        case .notes: return "Notes"
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "gauge.with.needle"
        case .statistics: return "chart.bar.xaxis"
        case .notes: return "note.text"
        }
    }
}

struct PlanItemDetailView: View {
    @Bindable var item: PlanItem
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navStore: NavigationStore
    @EnvironmentObject var pomodoroEngine: PomodoroEngine
    
    @State private var showingEditSheet = false
    @State private var showingAddProgress = false
    @State private var showCelebration = false
    @State private var celebrationHideTask: Task<Void, Never>?
    @State private var activeTab: HabitDetailTab = .overview
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(8, geometry.safeAreaInsets.top + 4))

                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .planGlassCircle(size: 40, fillOpacity: 0.18)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                HabitDetailTabPicker(activeTab: $activeTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                switch activeTab {
                case .overview:
                    overviewContent(bottomInset: geometry.safeAreaInsets.bottom)
                case .statistics:
                    HabitStatisticsTabView(item: item, itemColor: itemColor)
                case .notes:
                    HabitNotesTabView(item: item, itemColor: itemColor)
                }
            }
        }
        }
        .sheet(isPresented: $showingAddProgress) {
             AddHabitProgressSheet(item: item)
        }
        .sheet(isPresented: $showingEditSheet) {
            CreatePlanItemView(editingItem: item)
        }
        .overlay {
            if showCelebration {
                HabitGoalCelebrationOverlay(habitTitle: item.title)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PlanViewModel.habitGoalReachedNotification)) { output in
            guard let habitId = output.userInfo?["habitId"] as? String,
                  habitId == item.id.uuidString else { return }
            triggerCelebration()
        }
        .onDisappear {
            celebrationHideTask?.cancel()
        }
    }
    
    private func startFocus() {
        pomodoroEngine.stop(reset: true)
        pomodoroEngine.apply(planItem: item)
        if item.type != .habit {
            pomodoroEngine.start()
        }
        
        navStore.selectedTab = .timer
        dismiss()
    }
    
    private var isWaterHabit: Bool {
        item.title.lowercased().contains("water") || item.iconName == "drop" || item.iconName == "drop.fill"
    }

    private var isMindfulHabit: Bool {
        let t = item.title.lowercased()
        let icons = ["figure.mind.and.body", "lungs.fill", "figure.yoga", "graduationcap.fill"]
        return t.contains("meditation") || t.contains("yoga") || t.contains("breathe") || t.contains("learning") || icons.contains(item.iconName)
    }

    private var itemColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        case "mint": return .mint
        default: return .blue
        }
    }

    private func triggerCelebration() {
        celebrationHideTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            showCelebration = true
        }
        celebrationHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.55)) {
                    showCelebration = false
                }
            }
        }
    }

    @ViewBuilder
    private func overviewContent(bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if isWaterHabit {
                    WaterProgressView(item: item)
                } else if isMindfulHabit {
                    MindfulHabitProgressView(item: item)
                } else {
                    GenericHabitProgressView(item: item)
                }

                // Bottom Actions
                VStack(spacing: 10) {
                    if let duration = item.defaultDurationSeconds, duration > 0 {
                        Button(action: startFocus) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Start Focus")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [itemColor.opacity(0.78), itemColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(itemColor.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: itemColor.opacity(0.35), radius: 12, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }

                    Button(action: {
                        showingAddProgress = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                            Text("Add Progress")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [itemColor.opacity(0.78), itemColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(itemColor.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: itemColor.opacity(0.35), radius: 12, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Button(action: { showingEditSheet = true }) {
                        Text("Edit Habit")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, max(10, bottomInset + 4))
            }
        }
    }
}

// MARK: - Subviews

struct MindfulHabitProgressView: View {
    @Bindable var item: PlanItem
    @State private var pulse = false
    @Environment(\.modelContext) var modelContext
    private let progressUpdater = PlanViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 6)
            
            ZStack {
                // Breathing Pulse
                Circle()
                    .fill(itemColor.opacity(0.1))
                    .frame(width: pulse ? 240 : 176, height: pulse ? 240 : 176)
                
                Circle()
                    .stroke(itemColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 208, height: 208)
                
                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(itemColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 176, height: 176)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 8) {
                    Image(systemName: item.iconName)
                        .font(.largeTitle)
                        .foregroundColor(itemColor)
                    
                    Text("\(formattedCurrentValue)/\(formattedGoalValue) \(displayUnit)")
                        .font(.system(size: 20, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: 148)
                }
                
                // Plus and Minus buttons inside the circle
                VStack {
                    Spacer()
                    HStack(spacing: 80) {
                        // Minus Button
                        Button(action: decrementProgress) {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .disabled(currentValue <= 0)
                        .opacity(currentValue <= 0 ? 0.3 : 1.0)
                        
                        // Plus Button
                        Button(action: incrementProgress) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(itemColor))
                        }
                    }
                    .padding(.bottom, 20)
                }
                .frame(width: 176, height: 176)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
            
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(item.subtitle ?? "Take a moment for yourself")
                    .font(.body)
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer(minLength: 6)
        }
    }
    
    private var currentValue: Double {
        item.currentValue(on: Date())
    }
    
    private var progress: Double {
        item.progressFraction(on: Date())
    }

    private var displayUnit: String {
        item.goalUnit.lowercased() == "ml" ? "L" : item.goalUnit
    }

    private var formattedCurrentValue: String {
        formatDisplayMetric(currentValue)
    }

    private var formattedGoalValue: String {
        formatDisplayMetric(item.goalValue)
    }
    
    private func incrementProgress() {
        progressUpdater.updateHabitValue(item, delta: incrementAmount, context: modelContext)
    }
    
    private func decrementProgress() {
        progressUpdater.updateHabitValue(item, delta: -incrementAmount, context: modelContext)
    }
    
    private var incrementAmount: Double {
        let unit = item.goalUnit.lowercased()
        if unit.contains("min") { return 5 }
        if unit.contains("hr") || unit.contains("hour") { return 0.25 }
        return 1
    }

    private func formatDisplayMetric(_ value: Double) -> String {
        if item.goalUnit.lowercased() == "ml" {
            return (value / 1000).formatted(.number.precision(.fractionLength(0...2)))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
    
    private var itemColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        default: return .blue
        }
    }
}

// MARK: - Subviews

struct WaterProgressView: View {
    @Bindable var item: PlanItem
    @Environment(\.modelContext) var modelContext
    @State private var dragValue: Double?
    private let progressUpdater = PlanViewModel()
    private let circleSize: CGFloat = 252
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 14)
                    .frame(width: circleSize + 18, height: circleSize + 18)

                AnimatedWaveView(progress: displayedProgress)
                    .frame(width: circleSize, height: circleSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 2))
                    .overlay {
                        GeometryReader { geo in
                            let radius = min(geo.size.width, geo.size.height) / 2 - 10
                            let centerX = geo.size.width / 2
                            let centerY = geo.size.height / 2
                            let angle = (displayedProgress * 360) - 90
                            let radians = angle * .pi / 180
                            let x = centerX + cos(radians) * radius
                            let y = centerY + sin(radians) * radius

                            Circle()
                                .fill(Colors.accentBlue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                )
                                .shadow(color: Colors.accentBlue.opacity(0.6), radius: 6, x: 0, y: 0)
                                .position(x: x, y: y)
                        }
                    }
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragValue = valueFor(location: value.location, in: circleSize)
                            }
                            .onEnded { _ in
                                commitDraggedValue()
                            }
                    )
                    .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.82), value: displayedProgress)
                
                VStack(spacing: 8) {
                    Text("\(formatMetric(displayedValue))/\(formatMetric(item.goalValue))")
                        .font(.system(size: 30, weight: .regular, design: .monospaced))
                        .kerning(1.5)
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(width: circleSize * 0.74)

                    Text(displayUnit)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("Slide on circle to adjust")
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                Button(action: decrementProgress) {
                    Label("Subtract", systemImage: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .disabled(currentValue <= 0)
                .opacity(currentValue <= 0 ? 0.32 : 1.0)

                Button(action: incrementProgress) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Colors.accentBlue)
                        )
                }
            }
            .padding(.horizontal, 26)
            
            Spacer()
        }
    }
    
    private var currentValue: Double {
        item.currentValue(on: Date())
    }
    
    private var displayedValue: Double {
        max(0, min(dragValue ?? currentValue, item.goalValue))
    }

    private var displayedProgress: Double {
        guard item.goalValue > 0 else { return 0 }
        return max(0, min(displayedValue / item.goalValue, 1))
    }

    private var incrementAmount: Double {
        let unit = item.goalUnit.lowercased()
        if unit == "ml" { return 250 }
        if unit == "oz" { return 8 }
        if unit.contains("cup") { return 1 }
        return 1
    }

    private func incrementProgress() {
        progressUpdater.updateHabitValue(item, delta: incrementAmount, context: modelContext)
    }

    private func decrementProgress() {
        progressUpdater.updateHabitValue(item, delta: -incrementAmount, context: modelContext)
    }

    private func valueFor(location: CGPoint, in size: CGFloat) -> Double {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        guard dx != 0 || dy != 0 else { return currentValue }

        var angle = atan2(dy, dx) + (.pi / 2)
        if angle < 0 {
            angle += .pi * 2
        }

        let progress = max(0, min(1, angle / (.pi * 2)))
        return roundForDisplay(progress * item.goalValue)
    }

    private func commitDraggedValue() {
        guard let dragValue else { return }
        defer { self.dragValue = nil }

        let delta = dragValue - currentValue
        guard abs(delta) > 0.0001 else { return }
        progressUpdater.updateHabitValue(item, delta: delta, context: modelContext)
    }

    private func roundForDisplay(_ value: Double) -> Double {
        let unit = item.goalUnit.lowercased()
        if unit == "ml" {
            return (value / 10).rounded() * 10
        }
        if unit == "oz" {
            return (value * 2).rounded() / 2
        }
        return value.rounded()
    }

    private func formatMetric(_ value: Double) -> String {
        let unit = item.goalUnit.lowercased()
        if unit == "ml" {
            return (value / 1000).formatted(.number.precision(.fractionLength(0...2)))
        }
        if unit.contains("step") {
            return Int(value.rounded()).formatted(.number.grouping(.automatic))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayUnit: String {
        item.goalUnit.lowercased() == "ml" ? "L" : item.goalUnit
    }
}

struct GenericHabitProgressView: View {
    @Bindable var item: PlanItem
    @Environment(\.modelContext) var modelContext
    private let progressUpdater = PlanViewModel()
    
    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 6)

            ZStack {
                Circle()
                    .stroke(itemColor.opacity(0.18), lineWidth: 18)
                    .frame(width: 194, height: 194)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [itemColor.opacity(0.55), itemColor, itemColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 194, height: 194)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: itemColor.opacity(0.28), radius: 16, x: 0, y: 8)

                VStack(spacing: 6) {
                    Image(systemName: ringSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(itemColor)

                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: 132)

                    Text("completed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 132)
                }
            }

            VStack(spacing: 6) {
                Text(formattedProgressValue)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(displayUnit) • of \(formattedGoalValue) goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                Text(progressStatusText)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(progress >= 1 ? itemColor : Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 26)

            HStack(spacing: 16) {
                Button(action: decrementProgress) {
                    Label("Subtract", systemImage: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .disabled(progressValue <= 0)
                .opacity(progressValue <= 0 ? 0.32 : 1.0)

                Button(action: incrementProgress) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(itemColor)
                        )
                }
            }
            .padding(.horizontal, 26)

            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            Spacer(minLength: 4)
        }
    }
    
    private var progressValue: Double {
        item.completionLogs
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + ($1.value ?? ($1.completed ? item.goalValue : 0)) }
    }
    
    private var progress: Double {
        item.progressFraction(on: Date())
    }

    private var ringSymbol: String {
        let unit = item.goalUnit.lowercased()
        if unit.contains("step") { return "figure.walk" }
        if unit.contains("min") || unit.contains("hour") || item.metricKind == .time { return "clock.fill" }
        return item.iconName
    }

    private var progressStatusText: String {
        if progress >= 1 {
            return "Goal reached today"
        }
        return "\(formattedRemainingValue) \(displayUnit) remaining"
    }

    private var formattedProgressValue: String {
        formatMetric(progressValue)
    }

    private var formattedGoalValue: String {
        formatMetric(item.goalValue)
    }

    private var formattedRemainingValue: String {
        formatMetric(max(item.goalValue - progressValue, 0))
    }
    
    private func incrementProgress() {
        progressUpdater.updateHabitValue(item, delta: incrementAmount, context: modelContext)
    }
    
    private func decrementProgress() {
        progressUpdater.updateHabitValue(item, delta: -incrementAmount, context: modelContext)
    }
    
    private var incrementAmount: Double {
        let unit = item.goalUnit.lowercased()
        if unit == "ml" { return 250 }
        if unit == "oz" { return 8 }
        if unit == "steps" { return 1000 }
        if unit.contains("min") { return 5 }
        if unit.contains("hr") || unit.contains("hour") { return 0.25 }
        return 1
    }

    private func formatMetric(_ value: Double) -> String {
        if item.goalUnit.lowercased() == "ml" {
            return (value / 1000).formatted(.number.precision(.fractionLength(0...2)))
        }
        if item.goalUnit.lowercased().contains("step") {
            return Int(value.rounded()).formatted(.number.grouping(.automatic))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var displayUnit: String {
        item.goalUnit.lowercased() == "ml" ? "L" : item.goalUnit
    }
    
    private var itemColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
}

private struct HabitDetailTabPicker: View {
    @Binding var activeTab: HabitDetailTab

    var body: some View {
        Picker("Habit Tab", selection: $activeTab) {
            ForEach(HabitDetailTab.allCases) { tab in
                Label(tab.title, systemImage: tab.iconName)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(Color.white.opacity(0.28))
        .padding(8)
        .planGlassPanel(cornerRadius: 16, fillOpacity: 0.09)
    }
}

private struct HabitDailySnapshot: Identifiable {
    let date: Date
    let value: Double
    let hasLog: Bool
    let goalMet: Bool
    let intensity: Double

    var id: Date { date }
}

private enum HabitTrendGranularity: String, CaseIterable, Identifiable {
    case week = "W"
    case month = "M"
    case year = "Y"

    var id: String { rawValue }
}

private struct HabitTrendPoint: Identifiable {
    let startDate: Date
    let endDate: Date
    let value: Double
    let hasLog: Bool
    let goalMet: Bool
    let intensity: Double
    let label: String

    var id: Date { startDate }
}

private extension View {
    func habitStatisticsSurface(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
}

struct HabitStatisticsTabView: View {
    @Bindable var item: PlanItem
    let itemColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var selectedGranularity: HabitTrendGranularity = .week
    @State private var selectedTrendPoint: HabitTrendPoint?
    @State private var cachedValueByDay: [Date: Double] = [:]
    private let calendar = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                topSummaryCard
                streakHeroCard
                metricGrid
                trendChartCard
                consistencyTrendCard
                heatMapCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onAppear {
            rebuildValueByDayCache()
        }
        .onChange(of: item.completionLogs.count) { _, _ in
            rebuildValueByDayCache()
        }
        .onChange(of: item.updatedAt) { _, _ in
            rebuildValueByDayCache()
        }
    }

    private var topSummaryCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                Text("Goal: \(formatMetric(item.goalValue)) \(item.goalUnit) / day")
                    .font(.subheadline)
                    .foregroundColor(Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Consistency")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
                Text("\(Int((consistency * 100).rounded()))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(itemColor)
            }
        }
        .padding(16)
        .habitStatisticsSurface(cornerRadius: 20)
    }

    private var streakHeroCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color(red: 0.98, green: 0.58, blue: 0.24))
                Text("\(currentStreak) day streak!")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                Text(streakMotivation)
                    .font(.subheadline)
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(recentWeekSnapshots) { day in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(day.hasLog ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                                .frame(width: 38, height: 38)
                            Circle()
                                .trim(from: 0, to: max(0.03, day.intensity))
                                .stroke(
                                    day.goalMet ? trendPrimaryBlue : itemColor.opacity(0.8),
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 38, height: 38)
                            Text(dayLabelText(day))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                        }
                        Text(shortDayLabel(day.date))
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .habitStatisticsSurface(cornerRadius: 18)
    }

    private var consistencyTrendCard: some View {
        ConsistencyTrendCard(
            title: "Consistency",
            dailyRates: consistencyRateByDay,
            maxReferenceDate: Date(),
            accentColor: trendAccentColor
        )
    }

    private var metricGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            metricCard(title: "Success", value: "\(successDays) days", detail: "Goal met", icon: "checkmark", tint: .green)
            metricCard(title: "Failed", value: "\(failedDays) days", detail: "Tracked below goal", icon: "xmark", tint: .red)
            metricCard(title: "Skipped", value: "\(skippedDays) days", detail: "No log", icon: "arrow.right", tint: .orange)
            metricCard(title: "Current Streak", value: "\(currentStreak) days", detail: "Consecutive success", icon: "flame.fill", tint: itemColor)
        }
    }

    private func metricCard(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(tint)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .habitStatisticsSurface(cornerRadius: 16)
    }

    private var trendChartCard: some View {
        let points = trendPoints
        let selectedPoint = activeTrendPoint(from: points)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(trendIconBackground)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: trendMetricSymbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(trendAccentColor)
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Trend")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Menu {
                    ForEach(HabitTrendGranularity.allCases) { granularity in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGranularity = granularity
                                selectedTrendPoint = trendPoints.last
                            }
                        } label: {
                            if selectedGranularity == granularity {
                                Label(granularityDisplayName(granularity), systemImage: "checkmark")
                            } else {
                                Text(granularityDisplayName(granularity))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(granularityDisplayName(selectedGranularity))
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(trendMenuBackground)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .lastTextBaseline, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trendMetricText(selectedPoint?.value ?? 0, lowercasedUnit: true))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Average")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                    Text(trendMetricText(trendAverageValue))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }

                Spacer(minLength: 0)
            }

            if let selectedPoint {
                Text(trendDateLabel(for: selectedPoint))
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                trendYAxisReference
                    .frame(width: 52, height: chartDrawingHeight)
                    .padding(.bottom, trendPlotBottomInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .bottomLeading) {
                        trendReferenceGrid(width: chartContentWidth)
                            .frame(width: chartContentWidth, height: chartDrawingHeight)
                            .padding(.bottom, trendPlotBottomInset)

                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(points) { point in
                                let isSelected = selectedPoint?.id == point.id

                                VStack(spacing: trendBarVerticalSpacing) {
                                    if isSelected {
                                        Text(trendBubbleText(for: point.value))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(trendBubbleTextColor)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                            .fixedSize(horizontal: true, vertical: false)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(trendBubbleBackground)
                                            )
                                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                                    } else {
                                        Color.clear.frame(height: trendBubbleHeight)
                                    }

                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(trendTrackColor)
                                            .frame(width: barWidth, height: chartDrawingHeight)

                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(trendBarGradient(for: point, isSelected: isSelected))
                                            .frame(width: barWidth, height: barHeight(for: point))
                                            .shadow(
                                                color: isSelected ? trendAccentColor.opacity(isLightTheme ? 0.18 : 0.30) : .clear,
                                                radius: 8,
                                                x: 0,
                                                y: 4
                                            )
                                    }

                                    Text(point.label)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                        .foregroundColor(isSelected ? Colors.textPrimary : trendAxisLabelColor)
                                        .frame(height: trendLabelHeight)
                                }
                                .frame(width: barWidth + 8, height: trendBarsTotalHeight, alignment: .bottom)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                        selectedTrendPoint = point
                                    }
                                }
                                .onLongPressGesture(minimumDuration: 0.06) {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        selectedTrendPoint = point
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(width: chartContentWidth, height: trendBarsTotalHeight, alignment: .bottom)
                }
            }
        }
        .padding(16)
        .habitStatisticsSurface(cornerRadius: 24)
        .onAppear {
            if selectedTrendPoint == nil {
                selectedTrendPoint = trendPoints.last
            }
        }
        .onChange(of: selectedGranularity) { _, _ in
            selectedTrendPoint = trendPoints.last
        }
    }

    private var heatMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency Heatmap")
                .font(.headline)
                .foregroundColor(Colors.textPrimary)
            HabitHeatMapGrid(
                endDate: Date(),
                valueByDay: valueByDay,
                goalValue: item.goalValue,
                habitIntent: item.habitIntent ?? .build,
                goalUnit: item.goalUnit
            )
            Text("Each square is one day from the last 12 weeks.")
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
        }
        .padding(14)
        .habitStatisticsSurface(cornerRadius: 18)
    }

    private var dailySnapshots: [HabitDailySnapshot] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { dayOffset -> HabitDailySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: -(30 - 1 - dayOffset), to: today) else { return nil }
            let dayKey = calendar.startOfDay(for: date)
            let value = valueByDay[dayKey] ?? 0
            let hasLog = valueByDay.keys.contains(dayKey)
            let goalMet = didMeetGoal(value: value, hasLog: hasLog)
            return HabitDailySnapshot(
                date: dayKey,
                value: value,
                hasLog: hasLog,
                goalMet: goalMet,
                intensity: intensity(value: value, hasLog: hasLog)
            )
        }
    }

    private var trendPoints: [HabitTrendPoint] {
        switch selectedGranularity {
        case .week:
            return weeklyTrendPoints()
        case .month:
            return monthlyTrendPoints()
        case .year:
            return yearlyTrendPoints()
        }
    }

    private var recentWeekSnapshots: [HabitDailySnapshot] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset -> HabitDailySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let dayKey = calendar.startOfDay(for: date)
            let value = valueByDay[dayKey] ?? 0
            let hasLog = valueByDay.keys.contains(dayKey)
            let goalMet = didMeetGoal(value: value, hasLog: hasLog)
            return HabitDailySnapshot(
                date: dayKey,
                value: value,
                hasLog: hasLog,
                goalMet: goalMet,
                intensity: intensity(value: value, hasLog: hasLog)
            )
        }
    }

    private var valueByDay: [Date: Double] {
        cachedValueByDay
    }

    private var consistencyRateByDay: [Date: Double] {
        let today = calendar.startOfDay(for: Date())
        let fallbackStart = calendar.date(byAdding: .day, value: -540, to: today) ?? today
        let createdDay = calendar.startOfDay(for: item.createdAt)
        let startDay = max(createdDay, fallbackStart)
        guard startDay <= today else { return [:] }

        let loggedDays = Set(valueByDay.keys.map { calendar.startOfDay(for: $0) })
        var rates: [Date: Double] = [:]
        var cursor = startDay

        while cursor <= today {
            let day = calendar.startOfDay(for: cursor)
            let value = valueByDay[day] ?? 0
            let hasLog = loggedDays.contains(day)
            rates[day] = didMeetGoal(value: value, hasLog: hasLog) ? 1 : 0

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDay
        }

        return rates
    }

    private var successDays: Int {
        dailySnapshots.filter(\.goalMet).count
    }

    private var failedDays: Int {
        dailySnapshots.filter { $0.hasLog && !$0.goalMet }.count
    }

    private var skippedDays: Int {
        dailySnapshots.filter { !$0.hasLog }.count
    }

    private var averageValue: Double {
        let values = dailySnapshots.map(\.value)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var latestValue: Double {
        dailySnapshots.last?.value ?? 0
    }

    private var deltaFromAverageText: String {
        let delta = latestValue - averageValue
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(formatMetric(delta)) vs avg"
    }

    private var deltaFromAverageColor: Color {
        let delta = latestValue - averageValue
        if abs(delta) < 0.0001 { return Colors.textSecondary }
        return delta > 0 ? .green : .red
    }

    private var isLightTheme: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }

    private var trendAccentColor: Color {
        trendPrimaryBlue
    }

    private var trendPrimaryBlue: Color {
        Color(red: 0.08, green: 0.78, blue: 0.92)
    }

    private var trendSecondaryBlue: Color {
        Color(red: 0.05, green: 0.66, blue: 0.84)
    }

    private var trendAverageValue: Double {
        let points = trendPoints
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private var trendMenuBackground: Color {
        trendPrimaryBlue.opacity(isLightTheme ? 0.20 : 0.30)
    }

    private var trendIconBackground: Color {
        trendPrimaryBlue.opacity(isLightTheme ? 0.22 : 0.30)
    }

    private var trendTrackColor: Color {
        trendSecondaryBlue.opacity(isLightTheme ? 0.20 : 0.30)
    }

    private var trendAxisLabelColor: Color {
        isLightTheme ? Colors.textPrimary.opacity(0.72) : Colors.textPrimary.opacity(0.84)
    }

    private var trendBubbleBackground: Color {
        isLightTheme ? Color.black.opacity(0.82) : Color.white.opacity(0.88)
    }

    private var trendBubbleTextColor: Color {
        isLightTheme ? .white : Color.black.opacity(0.92)
    }

    private var trendMetricSymbol: String {
        if item.goalUnit.lowercased().contains("step") {
            return "figure.walk"
        }
        if item.metricKind == .time {
            return "timer"
        }
        return "chart.bar.fill"
    }

    private func granularityDisplayName(_ granularity: HabitTrendGranularity) -> String {
        switch granularity {
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        }
    }

    private func activeTrendPoint(from points: [HabitTrendPoint]) -> HabitTrendPoint? {
        guard !points.isEmpty else { return nil }
        if let selectedTrendPoint,
           let matching = points.first(where: { $0.id == selectedTrendPoint.id }) {
            return matching
        }
        return points.last
    }

    private func trendBarGradient(for point: HabitTrendPoint, isSelected: Bool) -> LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    trendPrimaryBlue.opacity(0.95),
                    trendSecondaryBlue.opacity(0.78)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        if point.hasLog {
            return LinearGradient(
                colors: [
                    trendAccentColor.opacity(isLightTheme ? 0.38 : 0.42),
                    trendAccentColor.opacity(isLightTheme ? 0.22 : 0.26)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        return LinearGradient(
            colors: [
                trendAccentColor.opacity(isLightTheme ? 0.18 : 0.22),
                trendAccentColor.opacity(isLightTheme ? 0.08 : 0.12)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var streakMotivation: String {
        switch currentStreak {
        case 0:
            return "Start today and build your first streak."
        case 1...2:
            return "Great start. Keep going and lock in momentum."
        case 3...6:
            return "Nice consistency. You are building a strong rhythm."
        default:
            return "Excellent streak. Protect it and keep compounding."
        }
    }

    private var consistency: Double {
        let activeDays = max(successDays + failedDays, 1)
        return Double(successDays) / Double(activeDays)
    }

    private var currentStreak: Int {
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let value = valueByDay[date] ?? 0
            let hasLog = valueByDay.keys.contains(date)
            if didMeetGoal(value: value, hasLog: hasLog) {
                streak += 1
            } else if offset > 0 || hasLog {
                break
            }
        }
        return streak
    }

    private func didMeetGoal(value: Double, hasLog: Bool) -> Bool {
        guard hasLog else { return false }
        switch item.habitIntent ?? .build {
        case .build:
            return value >= item.goalValue
        case .quit:
            return value <= item.goalValue
        }
    }

    private func intensity(value: Double, hasLog: Bool) -> Double {
        guard hasLog else { return 0 }
        switch item.habitIntent ?? .build {
        case .build:
            guard item.goalValue > 0 else { return value > 0 ? 1 : 0 }
            return min(max(value / item.goalValue, 0), 1)
        case .quit:
            guard item.goalValue > 0 else { return value <= 0 ? 1 : 0.2 }
            let normalized = 1 - min(max(value / item.goalValue, 0), 1)
            return max(0.1, normalized)
        }
    }

    private func barHeight(for day: HabitTrendPoint) -> CGFloat {
        // Keep a little headroom so tallest bars do not look abruptly clipped.
        let normalized = min(max(day.value / chartMaxValue, 0), 0.985)
        return max(10, normalized * chartDrawingHeight)
    }

    private func barColor(for day: HabitTrendPoint) -> Color {
        if selectedTrendPoint?.id == day.id {
            return itemColor
        }
        if day.goalMet { return itemColor }
        if day.hasLog { return Color(red: 0.96, green: 0.42, blue: 0.42) }
        return Color.white.opacity(0.14)
    }

    private func shortDayLabel(_ date: Date) -> String {
        // Use single-character weekday markers for compact readability.
        let weekday = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard weekday >= 0 && weekday < symbols.count else { return "-" }
        return symbols[weekday]
    }

    private var chartDrawingHeight: CGFloat { 92 }

    private var trendBubbleHeight: CGFloat { 24 }

    private var trendLabelHeight: CGFloat { 14 }

    private var trendBarVerticalSpacing: CGFloat { 6 }

    private var trendPlotBottomInset: CGFloat {
        trendLabelHeight + trendBarVerticalSpacing
    }

    private var trendBarsTotalHeight: CGFloat {
        trendBubbleHeight + trendBarVerticalSpacing + chartDrawingHeight + trendBarVerticalSpacing + trendLabelHeight
    }

    private var chartContentWidth: CGFloat {
        CGFloat(trendPoints.count) * (barWidth + 8)
    }

    private var chartMaxValue: Double {
        let base = max(trendPoints.map(\.value).max() ?? 0, item.goalValue, 1)
        let rounded = roundedAxisCeiling(base * 1.12)
        if trendDisplayUnit.lowercased() == "km" {
            return max(10, rounded)
        }
        return rounded
    }

    private var chartTickValues: [Double] {
        let steps = 4
        return (0...steps).map { index in
            (chartMaxValue / Double(steps)) * Double(index)
        }
    }

    private var trendYAxisReference: some View {
        GeometryReader { proxy in
            let values = chartTickValues
            let steps = max(values.count - 1, 1)

            ZStack(alignment: .topTrailing) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let progress = CGFloat(index) / CGFloat(steps)
                    let y = proxy.size.height - (progress * proxy.size.height)

                    Text(formatMetric(value))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .position(x: proxy.size.width - 2, y: y)
                }
            }
        }
    }

    private func trendReferenceGrid(width: CGFloat) -> some View {
        Canvas { context, size in
            let steps = max(chartTickValues.count - 1, 1)
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

    private var averageLineOffsetY: CGFloat {
        let sourceAverage = trendPoints.isEmpty ? 0 : trendPoints.map(\.value).reduce(0, +) / Double(trendPoints.count)
        return CGFloat(max(0, min(sourceAverage / chartMaxValue, 1))) * chartDrawingHeight
    }

    private var barWidth: CGFloat {
        switch selectedGranularity {
        case .week: return 26
        case .month: return 14
        case .year: return 22
        }
    }

    private func trendDateLabel(for point: HabitTrendPoint) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch selectedGranularity {
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            return formatter.string(from: point.startDate)
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            return formatter.string(from: point.startDate)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
            return formatter.string(from: point.startDate)
        }
    }

    private func weeklyTrendPoints() -> [HabitTrendPoint] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let key = calendar.startOfDay(for: date)
            let value = valueByDay[key] ?? 0
            let hasLog = valueByDay.keys.contains(key)
            let goalMet = didMeetGoal(value: value, hasLog: hasLog)
            return HabitTrendPoint(
                startDate: key,
                endDate: key,
                value: value,
                hasLog: hasLog,
                goalMet: goalMet,
                intensity: intensity(value: value, hasLog: hasLog),
                label: "\(calendar.component(.day, from: key))"
            )
        }
    }

    private func monthlyTrendPoints() -> [HabitTrendPoint] {
        let today = calendar.startOfDay(for: Date())
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let currentDayNumber = calendar.component(.day, from: today)

        return (0..<currentDayNumber).compactMap { dayOffset in
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: currentMonthStart) else { return nil }
            let key = calendar.startOfDay(for: dayDate)
            let value = valueByDay[key] ?? 0
            let hasLog = valueByDay.keys.contains(key)
            let goalMet = didMeetGoal(value: value, hasLog: hasLog)

            return HabitTrendPoint(
                startDate: key,
                endDate: key,
                value: value,
                hasLog: hasLog,
                goalMet: goalMet,
                intensity: intensity(value: value, hasLog: hasLog),
                label: "\(calendar.component(.day, from: key))"
            )
        }
    }

    private func yearlyTrendPoints() -> [HabitTrendPoint] {
        let today = calendar.startOfDay(for: Date())
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today

        return (0..<12).compactMap { index in
            guard let start = calendar.date(byAdding: .month, value: -(11 - index), to: currentMonthStart),
                  let monthRange = calendar.range(of: .day, in: .month, for: start) else { return nil }

            guard let monthEnd = calendar.date(byAdding: .day, value: monthRange.count - 1, to: start) else { return nil }
            let end = calendar.isDate(start, equalTo: today, toGranularity: .month) ? today : monthEnd
            let intervalDayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1

            let days = (0..<max(intervalDayCount, 0)).compactMap { day -> Date? in
                calendar.date(byAdding: .day, value: day, to: start).map { calendar.startOfDay(for: $0) }
            }
            let value = days.reduce(0.0) { $0 + (valueByDay[$1] ?? 0) }
            let hasLog = days.contains { valueByDay.keys.contains($0) }
            let dayCount = Double(max(days.count, 1))
            let goalMet = hasLog && didMeetGoal(value: value / dayCount, hasLog: true)
            let monthSymbol = calendar.shortMonthSymbols[calendar.component(.month, from: start) - 1]

            return HabitTrendPoint(
                startDate: start,
                endDate: end,
                value: value,
                hasLog: hasLog,
                goalMet: goalMet,
                intensity: intensity(value: value / dayCount, hasLog: hasLog),
                label: monthSymbol
            )
        }
    }

    private func formatMetric(_ value: Double) -> String {
        if item.goalUnit.lowercased().contains("step") || item.goalUnit == "ml" {
            return Int(value.rounded()).formatted(.number.grouping(.automatic))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var trendDisplayUnit: String {
        let raw = item.goalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()
        if lower == "km" || lower.contains("kilometer") || lower.contains("kilometre") { return "km" }
        if lower == "mi" || lower.contains("mile") { return "mi" }
        if lower == "m" || lower == "meter" || lower == "meters" || lower == "metre" || lower == "metres" { return "m" }
        if lower == "min" || lower == "mins" || lower == "minute" || lower == "minutes" { return "min" }
        if lower == "hr" || lower == "hrs" || lower == "hour" || lower == "hours" { return "hr" }
        return raw
    }

    private var isDistanceTrendUnit: Bool {
        let unit = trendDisplayUnit.lowercased()
        return unit == "km" || unit == "mi" || unit == "m"
    }

    private func trendMetricText(_ value: Double, lowercasedUnit: Bool = false) -> String {
        let unit = lowercasedUnit ? trendDisplayUnit.lowercased() : trendDisplayUnit
        return "\(formatMetric(value)) \(unit)"
    }

    private func trendBubbleText(for value: Double) -> String {
        if isDistanceTrendUnit {
            return trendMetricText(value, lowercasedUnit: true)
        }
        return formatMetric(value)
    }

    private func dayLabelText(_ day: HabitDailySnapshot) -> String {
        guard day.hasLog else { return "—" }
        return "\(Int((day.intensity * 100).rounded()))%"
    }

    private func rebuildValueByDayCache() {
        var dictionary: [Date: Double] = [:]
        for log in item.completionLogs {
            if log.note == CompletionLog.skippedMarker {
                continue
            }
            let key = calendar.startOfDay(for: log.date)
            if item.metricKind == .time {
                dictionary[key, default: 0] += Double(log.durationSeconds ?? 0) / 60.0
            } else {
                dictionary[key, default: 0] += log.value ?? (log.completed ? item.goalValue : 0)
            }
        }
        cachedValueByDay = dictionary
    }
}

struct HabitHeatMapGrid: View {
    let endDate: Date
    let valueByDay: [Date: Double]
    let goalValue: Double
    let habitIntent: HabitIntent
    let goalUnit: String
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = 12

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(Colors.textSecondary)
                            .frame(width: 12, height: 16, alignment: .leading)
                    }
                }

                VStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<columns, id: \.self) { column in
                                let cell = cellFor(row: row, column: column)
                                let isSelected = selectedDate != nil && calendar.isDate(cell.date, inSameDayAs: selectedDate!)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(cellColor(for: cell))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
                                    )
                                    .overlay {
                                        if isSelected {
                                            Text(cell.hasLog ? compactValueLabel(cell.rawValue) : "0")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundColor(Colors.textPrimary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                    .frame(width: 20, height: 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard cell.date <= calendar.startOfDay(for: endDate) else { return }
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedDate = cell.date
                                        }
                                    }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if let selectedDate {
                    let key = calendar.startOfDay(for: selectedDate)
                    let rawValue = valueByDay[key] ?? 0
                    let hasLog = valueByDay.keys.contains(key)

                    Text(selectedDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundColor(Colors.textPrimary)

                    Spacer()

                    if hasLog {
                        Text("\(formattedValue(rawValue)) \(goalUnit) • \(Int((heatIntensity(value: rawValue, hasLog: true) * 100).rounded()))%")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    } else {
                        Text("No log")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                } else {
                    Text("Tap a rectangle to view value")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                }
            }
        }
        .onAppear {
            if selectedDate == nil {
                selectedDate = calendar.startOfDay(for: endDate)
            }
        }
    }

    private func cellFor(row: Int, column: Int) -> (date: Date, intensity: Double, hasLog: Bool, rawValue: Double) {
        let baseStart = heatMapStartDate
        let dayIndex = (column * 7) + row
        let date = calendar.date(byAdding: .day, value: dayIndex, to: baseStart) ?? baseStart
        let key = calendar.startOfDay(for: date)
        let value = valueByDay[key] ?? 0
        let hasLog = valueByDay.keys.contains(key)
        return (key, heatIntensity(value: value, hasLog: hasLog), hasLog, value)
    }

    private var heatMapStartDate: Date {
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: -((columns - 1) * 7), to: currentWeekStart) ?? currentWeekStart
    }

    private func cellColor(for cell: (date: Date, intensity: Double, hasLog: Bool, rawValue: Double)) -> Color {
        if cell.date > calendar.startOfDay(for: endDate) {
            return Color.clear
        }
        if !cell.hasLog {
            return Color.white.opacity(0.08)
        }
        let shade: Color
        switch cell.intensity {
        case ..<0.34:
            shade = Color(red: 0.98, green: 0.82, blue: 0.32) // yellow
        case ..<0.67:
            shade = Color(red: 0.98, green: 0.58, blue: 0.24) // orange
        default:
            shade = Color(red: 0.93, green: 0.30, blue: 0.26) // red
        }
        return shade.opacity(0.25 + (cell.intensity * 0.70))
    }

    private func heatIntensity(value: Double, hasLog: Bool) -> Double {
        guard hasLog else { return 0 }
        switch habitIntent {
        case .build:
            guard goalValue > 0 else { return value > 0 ? 1 : 0 }
            return min(max(value / goalValue, 0), 1)
        case .quit:
            guard goalValue > 0 else { return value <= 0 ? 1 : 0.2 }
            let normalized = 1 - min(max(value / goalValue, 0), 1)
            return max(0.1, normalized)
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value >= 1000 {
            return value.formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func compactValueLabel(_ value: Double) -> String {
        if value >= 100 {
            return "\(Int(value.rounded()))"
        }
        if value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct HabitNotesTabView: View {
    @Bindable var item: PlanItem
    let itemColor: Color

    @Environment(\.modelContext) private var modelContext
    @State private var draftText = ""
    @State private var didInitialize = false
    @State private var saveStatus = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notes for \(item.title)")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)

                TextEditor(text: $draftText)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Colors.textPrimary)
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button {
                        draftText = item.habitNotes
                        saveStatus = "Reverted"
                    } label: {
                        Text("Reset")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveNotes()
                    } label: {
                        Text("Save Notes")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [itemColor.opacity(0.78), itemColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                if !saveStatus.isEmpty {
                    Text(saveStatus)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onAppear {
            guard !didInitialize else { return }
            draftText = item.habitNotes
            didInitialize = true
        }
    }

    private func saveNotes() {
        item.habitNotes = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updatedAt = Date()
        do {
            try modelContext.save()
            saveStatus = "Saved"
        } catch {
            saveStatus = "Could not save notes"
        }
    }
}

// MARK: - Help Views

struct AnimatedWaveView: View {
    var progress: Double
    @State private var phase: Double = 0
    
    var body: some View {
        ZStack {
            WaveShape(phase: phase, progress: progress)
                .fill(Color.blue.opacity(0.3))
                .offset(y: 10)
            
            WaveShape(phase: phase + 1.5, progress: progress)
                .fill(Color.blue.opacity(0.5))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct WaveShape: Shape {
    var phase: Double
    var progress: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let progressHeight = height * (1 - CGFloat(progress))
        let waveHeight: CGFloat = 10
        
        path.move(to: CGPoint(x: 0, y: progressHeight))
        
        for x in stride(from: CGFloat(0), to: width, by: 1) {
            let relativeX = x / width
            let sine = sin(Double(relativeX) * .pi * 2 + phase)
            let y = progressHeight + CGFloat(sine) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct AddHabitProgressSheet: View {
    @Bindable var item: PlanItem
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    private let progressUpdater = PlanViewModel()
    
    @State private var value: Double = 0
    @State private var stringValue: String = "0"
    
    private let presets: [Double] = [150, 300, 500, 800, 1000] // Common for water, but can adapt
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                    Text("Add \(item.goalUnit)")
                        .font(.headline)
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                    Button(action: saveProgress) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color(red: 0.13, green: 0.74, blue: 0.84))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // Value Display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(stringValue)
                        .font(.system(size: 60, weight: .bold))
                    Text(item.goalUnit)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(PlanPalette.textPrimary)
                .padding(.top, 20)
                
                // Presets
                HStack(spacing: 12) {
                    ForEach(presetValues, id: \.self) { val in
                        Button(action: { stringValue = "\(Int(val))" }) {
                            VStack(spacing: 4) {
                                Image(systemName: presetIcon(for: val))
                                    .font(.title3)
                                Text(presetLabel(for: val))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .frame(width: 64, height: 64)
                            .background(Color.white.opacity(0.12))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            .clipShape(Circle())
                            .foregroundColor(PlanPalette.textPrimary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Keypad
                VStack(spacing: 12) {
                    let keys = [
                        ["7", "8", "9"],
                        ["4", "5", "6"],
                        ["1", "2", "3"],
                        ["", "0", "backspace"]
                    ]
                    
                    ForEach(keys, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { key in
                                Button(action: { handleKey(key) }) {
                                    ZStack {
                                        if key == "backspace" {
                                            Image(systemName: "delete.left")
                                                .font(.title2)
                                        } else {
                                            Text(key)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .planGlassPanel(cornerRadius: 12, fillOpacity: 0.11)
                                    .foregroundColor(Colors.textPrimary)
                                    .opacity(key.isEmpty ? 0 : 1)
                                }
                                .disabled(key.isEmpty)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.height(600)])
    }
    
    private var presetValues: [Double] {
        if item.goalUnit.lowercased() == "ml" {
            return [150, 300, 500, 800, 1000]
        } else if item.goalUnit.lowercased() == "glasses" || item.goalUnit.lowercased() == "times" {
            return [1, 2, 3, 5]
        }
        return [1, 5, 10, 20, 50]
    }
    
    private func presetIcon(for val: Double) -> String {
        if item.goalUnit.lowercased() == "ml" {
            if val < 200 { return "cup.and.saucer" }
            if val < 400 { return "plus.magnifyingglass" } // Just placeholders for icons
            if val < 600 { return "takeoutbag.and.cup.and.straw" }
            return "drop.fill"
        }
        return "plus"
    }
    
    private func presetLabel(for val: Double) -> String {
        if val >= 1000 && item.goalUnit.lowercased() == "ml" {
             return "\(Int(val/1000))L"
        }
        return "\(Int(val))\(item.goalUnit)"
    }
    
    private func handleKey(_ key: String) {
        if key == "backspace" {
            if stringValue.count > 1 {
                stringValue.removeLast()
            } else {
                stringValue = "0"
            }
        } else if !key.isEmpty {
            if stringValue == "0" {
                stringValue = key
            } else {
                stringValue += key
            }
        }
    }
    
    private func saveProgress() {
        guard let val = Double(stringValue), val > 0 else { return }
        progressUpdater.updateHabitValue(item, delta: val, context: modelContext)
        dismiss()
    }
    
    private var itemBgColor: Color {
        // Light version of tintKey
        switch item.tintKey {
        case "red": return Color(red: 1.0, green: 0.9, blue: 0.9)
        case "blue": return Color(red: 0.9, green: 0.95, blue: 1.0)
        case "green": return Color(red: 0.9, green: 1.0, blue: 0.9)
        case "orange": return Color(red: 1.0, green: 0.95, blue: 0.9)
        case "purple": return Color(red: 0.95, green: 0.9, blue: 1.0)
        default: return Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
}
