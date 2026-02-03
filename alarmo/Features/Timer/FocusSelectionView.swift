import SwiftUI

struct FocusSelectionView: View {
    @Bindable var item: PlanItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pomodoroEngine: PomodoroEngine
    @EnvironmentObject var navStore: NavigationStore
    
    @State private var mode: String = "timer" // timer, stopwatch
    @State private var durationMinutes: Int = 25
    @State private var isStopwatchRunning = false
     
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding()
                
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Colors.textPrimary)
                
                // Toggle
                HStack(spacing: 0) {
                    Button(action: { mode = "timer" }) {
                        Text("Timer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(mode == "timer" ? Colors.bgPrimary : Colors.textPrimary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(mode == "timer" ? Colors.textPrimary : Color.clear)
                            .cornerRadius(20)
                    }
                    Button(action: { mode = "stopwatch" }) {
                        Text("Stopwatch")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(mode == "stopwatch" ? Colors.bgPrimary : Colors.textPrimary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(mode == "stopwatch" ? Colors.textPrimary : Color.clear)
                            .cornerRadius(20)
                    }
                }
                .padding(4)
                .background(Colors.cardSurface)
                .cornerRadius(24)
                .frame(maxWidth: 240)
                
                if mode == "timer" {
                    VStack(spacing: 20) {
                        Text("\(durationMinutes) min")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(Colors.textPrimary)
                        
                        Stepper("", value: $durationMinutes, in: 1...180, step: 5)
                            .labelsHidden()
                            .transformEffect(.init(scaleX: 1.5, y: 1.5))
                        
                        Button(action: startTimer) {
                            Text("Start Focus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Colors.accentTeal)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("00:00:00")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(Colors.textPrimary)
                            .monospacedDigit()
                        
                        Button(action: startStopwatch) {
                            Text("Start Stopwatch")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Colors.accentBlue)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func startTimer() {
        // Update item duration
        item.defaultDurationSeconds = durationMinutes * 60
        
        pomodoroEngine.stop(reset: true)
        pomodoroEngine.apply(planItem: item)
        navStore.selectedTab = .timer
        dismiss()
    }
    
    private func startStopwatch() {
        // Navigate to timer tab but maybe set a stopwatch mode?
        // For now, assuming engine handles Pomo only, we might just start a simplified timer
        // or just placeholder log
        print("Start Stopwatch")
        // Implementation depend on engine capabilities
        dismiss()
    }
}
