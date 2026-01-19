import SwiftUI

struct TimerRootView: View {
    @StateObject private var viewModel: TimerViewModel
    let preferences: AppPreferences
    let onClose: () -> Void
    
    init(preferences: AppPreferences = AppPreferences(), onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: TimerViewModel(preferences: preferences))
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Segmented Control
                    HStack(spacing: 0) {
                        ForEach(TimerMode.allCases) { mode in
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewModel.selectedMode == mode ? Colors.textPrimary : Colors.textSecondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(viewModel.selectedMode == mode ? Colors.cardSurface : Color.clear)
                                .clipShape(Capsule())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        viewModel.selectedMode = mode
                                        viewModel.stopTimer()
                                    }
                                }
                        }
                    }
                    .background(Colors.bgSecondary)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { print("History tapped") }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textPrimary)
                        }
                        
                        Menu {
                            Button(action: { viewModel.showFocusSettings = true }) {
                                Label("Focus Settings", systemImage: "slider.horizontal.3")
                            }
                            Button(action: { viewModel.showAddFocusRecord = true }) {
                                Label("Add Record", systemImage: "list.bullet.rectangle")
                            }
                            Button(action: { viewModel.showAddTimer = true }) {
                                Label("Add Timer", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                
                // Content
                if viewModel.selectedMode == .pomo {
                    PomoTimerView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                } else {
                    StopwatchView(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .padding(.bottom, AppConstants.tabBarHeight)
        }
        .sheet(isPresented: $viewModel.showPomoDurationPicker) {
            PomoDurationPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFocusSettings) {
            FocusSettingsView(preferences: preferences)
        }
        .sheet(isPresented: $viewModel.showAddFocusRecord) {
            AddFocusRecordView()
        }
        .sheet(isPresented: $viewModel.showAddTimer) {
            AddTimerView()
        }
        .sheet(isPresented: $viewModel.showFocusNoteSheet) {
            FocusNoteSheet(viewModel: viewModel)
        }
    }
}
