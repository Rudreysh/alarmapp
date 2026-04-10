import SwiftUI

struct StopwatchView: View {
    @ObservedObject var viewModel: TimerViewModel
    let preferences: AppPreferences
    @ObservedObject var swEngine: StopwatchEngine
    @ObservedObject var multiStore: MultiTimerStore
    @ObservedObject var countdownStore: CountdownPresetStore
    @ObservedObject var countdownEngine: CountdownEngine
    
    @State private var subMode: StopwatchSubMode = .standard
    
    enum StopwatchSubMode: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case parallel = "Parallel"
        case countdown = "Presets"
        case history = "History"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation
            HStack(spacing: 12) {
                ForEach(StopwatchSubMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            subMode = mode
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: subMode == mode ? .bold : .medium))
                                .foregroundColor(subMode == mode ? TimerPalette.accent : Colors.textSecondary)
                            
                            // Indicator dot
                            Circle()
                                .fill(subMode == mode ? TimerPalette.accent : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            
            // Content
            ZStack {
                switch subMode {
                case .standard:
                    LapStopwatchView(engine: swEngine)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                case .parallel:
                    MultiTimerView(store: multiStore)
                        .transition(.move(edge: .trailing))
                case .countdown:
                    CountdownPresetView(store: countdownStore, engine: countdownEngine)
                        .transition(.move(edge: .trailing))
                case .history:
                    StopwatchHistoryView(engine: swEngine)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            swEngine.loadSessions()
        }
    }
}
