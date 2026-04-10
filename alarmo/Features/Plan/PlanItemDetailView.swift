import SwiftUI
import SwiftData

struct PlanItemDetailView: View {
    @Bindable var item: PlanItem
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navStore: NavigationStore
    @EnvironmentObject var pomodoroEngine: PomodoroEngine
    
    @State private var showingEditSheet = false
    @State private var showingAddProgress = false
    @State private var tempProgressValue: Double = 0
    @State private var showCelebration = false
    @State private var celebrationHideTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
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
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                if isWaterHabit {
                    WaterProgressView(item: item)
                } else if isMindfulHabit {
                    MindfulHabitProgressView(item: item)
                } else {
                    GenericHabitProgressView(item: item)
                }
                
                Spacer()
                
                // Bottom Actions
                VStack(spacing: 12) {
                    if let duration = item.defaultDurationSeconds, duration > 0 {
                        PrimaryButton(title: "Start Focus", iconName: "play.fill", style: .blueGlass) {
                            startFocus()
                        }
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
                        .padding(.vertical, 16)
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
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
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
}

// MARK: - Subviews

struct MindfulHabitProgressView: View {
    @Bindable var item: PlanItem
    @State private var pulse = false
    @Environment(\.modelContext) var modelContext
    private let progressUpdater = PlanViewModel()
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                // Breathing Pulse
                Circle()
                    .fill(itemColor.opacity(0.1))
                    .frame(width: pulse ? 280 : 200, height: pulse ? 280 : 200)
                
                Circle()
                    .stroke(itemColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 240, height: 240)
                
                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(itemColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 8) {
                    Image(systemName: item.iconName)
                        .font(.largeTitle)
                        .foregroundColor(itemColor)
                    
                    Text("\(currentValue.formatted(.number.precision(.fractionLength(0...2))))/\(item.goalValue.formatted(.number.precision(.fractionLength(0...2)))) \(item.goalUnit)")
                        .font(.system(size: 24, weight: .regular, design: .monospaced))
                        .kerning(1.2)
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
                .frame(width: 200, height: 200)
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
            
            Spacer()
        }
    }
    
    private var currentValue: Double {
        item.currentValue(on: Date())
    }
    
    private var progress: Double {
        item.progressFraction(on: Date())
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
    private let circleSize: CGFloat = 300
    
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
                    Text("\(formatMetric(displayedValue))/\(formatMetric(item.goalValue)) \(item.goalUnit)")
                        .font(.system(size: 32, weight: .regular, design: .monospaced))
                        .kerning(1.5)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("Slide on circle to adjust")
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)
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
        if unit == "ml" || unit.contains("step") {
            return Int(value.rounded()).formatted(.number.grouping(.automatic))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct GenericHabitProgressView: View {
    @Bindable var item: PlanItem
    @Environment(\.modelContext) var modelContext
    private let progressUpdater = PlanViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 18)

            ZStack {
                Circle()
                    .stroke(itemColor.opacity(0.18), lineWidth: 18)
                    .frame(width: 222, height: 222)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [itemColor.opacity(0.55), itemColor, itemColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 222, height: 222)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: itemColor.opacity(0.28), radius: 16, x: 0, y: 8)

                VStack(spacing: 6) {
                    Image(systemName: ringSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(itemColor)

                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)

                    Text("completed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
            }

            VStack(spacing: 8) {
                Text(formattedProgressValue)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(item.goalUnit) • of \(formattedGoalValue) goal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                Text(progressStatusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(progress >= 1 ? itemColor : Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
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
                        .padding(.vertical, 14)
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
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(itemColor)
                        )
                }
            }
            .padding(.horizontal, 26)

            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            
            Spacer()
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
        return "\(formattedRemainingValue) \(item.goalUnit) remaining"
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
        if item.goalUnit.lowercased().contains("step") {
            return Int(value.rounded()).formatted(.number.grouping(.automatic))
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
        default: return .blue
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
