import SwiftUI

struct IntervalTimerSettingsView: View {
    @ObservedObject var engine: PomodoroEngine
    @Environment(\.dismiss) var dismiss
    
    // Pro Entitlement
    let isPro = true // Replace with entitlementProvider or similar
    
    // Available options
    let sessionsOptions = Array(2...10)
    
    enum DurationPickerTarget: String, Identifiable {
        case focus
        case shortBreak
        case longBreak
        
        var id: String { rawValue }
        var title: String {
            switch self {
            case .focus: return "Focus Session Duration"
            case .shortBreak: return "Short Break Duration"
            case .longBreak: return "Long Break Duration"
            }
        }
    }
    
    @State private var activeDurationPicker: DurationPickerTarget?
    
    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        
                        // Header / Enabled Toggle
                        VStack(spacing: 0) {
                            ToggleRow(title: "Interval Timer", isOn: Binding(
                                get: { engine.config.isEnabled },
                                set: { newValue in
                                    if !isPro && newValue {
                                        // Show paywall (Stub)
                                        print("Show Paywall")
                                    } else {
                                        var newConfig = engine.config
                                        newConfig.isEnabled = newValue
                                        engine.updateConfig(newConfig)
                                    }
                                }
                            ))
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                        if engine.config.isEnabled {
                            // Section: Durations
                            VStack(spacing: 0) {
                                PickerRow(title: "Focus Session Duration", 
                                          value: formattedDuration(engine.config.focusSeconds)) {
                                    activeDurationPicker = .focus
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                PickerRow(title: "Focus Sessions per Cycle", 
                                          value: "\(engine.config.sessionsPerCycle)") {
                                    PickerSelectionView(
                                        title: "Sessions per Cycle",
                                        options: sessionsOptions,
                                        selection: Binding(
                                            get: { engine.config.sessionsPerCycle },
                                            set: {
                                                var c = engine.config
                                                c.sessionsPerCycle = $0
                                                engine.updateConfig(c)
                                            }
                                        )
                                    )
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                PickerRow(title: "Short Break Duration", 
                                          value: formattedDuration(engine.config.shortBreakSeconds)) {
                                    activeDurationPicker = .shortBreak
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                PickerRow(title: "Long Break Duration", 
                                          value: formattedDuration(engine.config.longBreakSeconds)) {
                                    activeDurationPicker = .longBreak
                                }
                            }
                            .padding(.horizontal)
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                            
                            // Section: Automation
                            VStack(spacing: 0) {
                                ToggleRow(title: "Auto-Start Next Session", 
                                         isOn: Binding(
                                            get: { engine.config.autoStartNextSession },
                                            set: {
                                                var c = engine.config
                                                c.autoStartNextSession = $0
                                                engine.updateConfig(c)
                                            }
                                         ))
                                
                                Divider().background(Colors.cardStroke)
                                
                                ToggleRow(title: "Auto-Start Next Cycle", 
                                         isOn: Binding(
                                            get: { engine.config.autoStartNextCycle },
                                            set: {
                                                var c = engine.config
                                                c.autoStartNextCycle = $0
                                                engine.updateConfig(c)
                                            }
                                         ))
                            }
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                            
                            // Section: Focus Difficulty
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Session Difficulty")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                    .padding(.horizontal, 4)
                                
                                ForEach(FocusDifficultyMode.allCases, id: \.self) { mode in
                                    Button(action: {
                                        var c = engine.config
                                        c.difficultyMode = mode
                                        engine.updateConfig(c)
                                    }) {
                                        HStack(spacing: 14) {
                                            Image(systemName: mode.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(mode == .deepFocus ? .red : TimerPalette.accent)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(mode.title)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(Colors.textPrimary)
                                                Text(mode.description)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Colors.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if engine.config.difficultyMode == mode {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(mode == .deepFocus ? .red : TimerPalette.accent)
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(engine.config.difficultyMode == mode
                                                    ? (mode == .deepFocus ? Color.red.opacity(0.12) : TimerPalette.accent.opacity(0.12))
                                                    : Colors.cardSurface
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(TimerPalette.accent)
                }
            }
            .sheet(item: $activeDurationPicker) { target in
                DurationSelectionSheet(
                    title: target.title,
                    initialSeconds: durationSeconds(for: target),
                    onSave: { newSeconds in
                        updateDuration(newSeconds, for: target)
                    }
                )
                .presentationDetents([.fraction(0.48)])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func durationSeconds(for target: DurationPickerTarget) -> Int {
        switch target {
        case .focus: return engine.config.focusSeconds
        case .shortBreak: return engine.config.shortBreakSeconds
        case .longBreak: return engine.config.longBreakSeconds
        }
    }
    
    private func updateDuration(_ seconds: Int, for target: DurationPickerTarget) {
        var c = engine.config
        let safeSeconds = min(120 * 60, max(1, seconds))
        switch target {
        case .focus:
            c.focusSeconds = safeSeconds
        case .shortBreak:
            c.shortBreakSeconds = safeSeconds
        case .longBreak:
            c.longBreakSeconds = safeSeconds
        }
        engine.updateConfig(c)
    }
    
    private func formattedDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Components

struct PickerRow: View {
    let title: String
    let value: String
    var isPro: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textPrimary)
                    
                    if isPro {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 12))
                    }
                }
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textTertiary)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

struct DurationSelectionSheet: View {
    let title: String
    let onSave: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int
    
    init(title: String, initialSeconds: Int, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.onSave = onSave
        _minutes = State(initialValue: max(0, initialSeconds / 60))
        _seconds = State(initialValue: max(0, initialSeconds % 60))
    }
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Colors.textTertiary)
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Text(previewText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(TimerPalette.accent)
                
                HStack(spacing: 0) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...120, id: \.self) { value in
                            Text("\(value) min").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0...59, id: \.self) { value in
                            Text("\(value) sec").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(height: 180)
                
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    Button("Done") {
                        let total = max(1, (minutes * 60) + seconds)
                        onSave(total)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var previewText: String {
        "\(minutes) min \(seconds) sec"
    }
}

struct PickerSelectionView: View {
    let title: String
    let options: [Int]
    @Binding var selection: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            List {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        selection = option
                        dismiss()
                    }) {
                        HStack {
                            Text("\(option) \(title.contains("Cycle") ? "" : "min")")
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(TimerPalette.accent)
                            }
                        }
                    }
                    .listRowBackground(Colors.cardSurface)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(title)
    }
}
