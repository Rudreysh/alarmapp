import SwiftUI

struct IntervalTimerSettingsView: View {
    @ObservedObject var engine: PomodoroEngine
    @Environment(\.dismiss) var dismiss
    
    // Pro Entitlement
    let isPro = true // Replace with entitlementProvider or similar
    
    // Available options
    let focusDurations = [1, 5, 10, 15, 20, 25, 30, 45, 50, 60, 90, 120]
    let sessionsOptions = Array(2...10)
    let shortBreaks = [1, 2, 3, 5, 10, 15]
    let longBreaks = [5, 10, 15, 20, 25, 30, 45, 60]
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
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
                                          value: "\(engine.config.focusSeconds / 60) min") {
                                    PickerSelectionView(
                                        title: "Focus Duration",
                                        options: focusDurations,
                                        selection: Binding(
                                            get: { engine.config.focusSeconds / 60 },
                                            set: { 
                                                var c = engine.config
                                                c.focusSeconds = $0 * 60
                                                engine.updateConfig(c)
                                            }
                                        )
                                    )
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
                                          value: "\(engine.config.shortBreakSeconds / 60) min") {
                                    PickerSelectionView(
                                        title: "Short Break",
                                        options: shortBreaks,
                                        selection: Binding(
                                            get: { engine.config.shortBreakSeconds / 60 },
                                            set: {
                                                var c = engine.config
                                                c.shortBreakSeconds = $0 * 60
                                                engine.updateConfig(c)
                                            }
                                        )
                                    )
                                }
                                
                                Divider().background(Colors.cardStroke)
                                
                                PickerRow(title: "Long Break Duration", 
                                          value: "\(engine.config.longBreakSeconds / 60) min") {
                                    PickerSelectionView(
                                        title: "Long Break",
                                        options: longBreaks,
                                        selection: Binding(
                                            get: { engine.config.longBreakSeconds / 60 },
                                            set: {
                                                var c = engine.config
                                                c.longBreakSeconds = $0 * 60
                                                engine.updateConfig(c)
                                            }
                                        )
                                    )
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
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}

// MARK: - Components

struct PickerRow<Content: View>: View {
    let title: String
    let value: String
    var isPro: Bool = false
    let destination: () -> Content
    
    var body: some View {
        NavigationLink(destination: destination) {
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
    }
}

struct PickerSelectionView: View {
    let title: String
    let options: [Int]
    @Binding var selection: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
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
                                    .foregroundColor(Colors.accentTeal)
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
