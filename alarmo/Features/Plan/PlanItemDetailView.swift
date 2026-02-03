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
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Colors.bgSecondary)
                            .clipShape(Circle())
                    }
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
                }
                .padding()
                
                if isWaterHabit {
                    WaterProgressView(item: item)
                } else if isMindfulHabit {
                    MindfulHabitProgressView(item: item)
                } else {
                    GenericHabitProgressView(item: item)
                }
                
                Spacer()
                
                // Bottom Actions
                VStack(spacing: 16) {
                    if let duration = item.defaultDurationSeconds, duration > 0 {
                        Button(action: startFocus) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Focus")
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.accentRed)
                            .cornerRadius(30)
                            .appShadow(Shadows.button)
                        }
                        .padding(.horizontal, 24)
                    }

                    Button(action: { showingAddProgress = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Progress")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(itemColor)
                        .cornerRadius(30)
                        .appShadow(Shadows.button)
                    }
                    .padding(.horizontal, 24)
                    
                    Button(action: { showingEditSheet = true }) {
                        Text("Edit Habit")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .stroke(Colors.textSecondary.opacity(0.3), lineWidth: 1)
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
    }
    
    private func startFocus() {
        pomodoroEngine.stop(reset: true)
        pomodoroEngine.apply(planItem: item)
        pomodoroEngine.start()
        
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
}

// MARK: - Subviews

struct MindfulHabitProgressView: View {
    @Bindable var item: PlanItem
    @State private var pulse = false
    
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
                    
                    Text("\(Int(currentValue))/\(Int(item.goalValue)) \(item.goalUnit)")
                        .font(.system(size: 24, weight: .bold))
                }
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
        min(max(currentValue / item.goalValue, 0), 1)
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
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                // Liquid Animations would go here
                AnimatedWaveView(progress: progress)
                    .frame(height: 300)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 2))
                    .padding(40)
                
                VStack(spacing: 8) {
                    Text("\(Int(currentValue))/\(Int(item.goalValue))\(item.goalUnit)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("Water intake & your goal")
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var currentValue: Double {
        item.completionLogs
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + ($1.value ?? ($1.completed ? item.goalValue : 0)) }
    }
    
    private var progress: Double {
        let p = currentValue / item.goalValue
        return min(max(p, 0), 1)
    }
}

struct GenericHabitProgressView: View {
    @Bindable var item: PlanItem
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .stroke(Colors.bgSecondary, lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(itemColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(progressValue.formatted())")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("\(item.goalUnit)")
                        .font(.headline)
                        .foregroundColor(Colors.textSecondary)
                    
                    Text("of \(item.goalValue.formatted()) goal")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            
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
        min(max(progressValue / item.goalValue, 0), 1)
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
    
    @State private var value: Double = 0
    @State private var stringValue: String = "0"
    
    private let presets: [Double] = [150, 300, 500, 800, 1000] // Common for water, but can adapt
    
    var body: some View {
        ZStack {
            itemBgColor.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                    Spacer()
                    Text("Add \(item.goalUnit)")
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: saveProgress) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black)
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
                .foregroundColor(.black)
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
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.black)
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
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .foregroundColor(.black)
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
        
        let calendar = Calendar.current
        if let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
            if item.metricKind == .time {
                // val is in minutes, convert to seconds
                existingLog.durationSeconds = (existingLog.durationSeconds ?? 0) + Int(val * 60)
            } else {
                existingLog.value = (existingLog.value ?? 0) + val
            }
            existingLog.completed = item.isGoalMet()
        } else {
            let log = CompletionLog(date: Date(), completed: false)
            if item.metricKind == .time {
                log.durationSeconds = Int(val * 60)
            } else {
                log.value = val
            }
            item.completionLogs.append(log)
            log.completed = item.isGoalMet()
        }
        
        try? modelContext.save()
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

