import SwiftUI

struct HomeView: View {
    @EnvironmentObject var ringCoordinator: AlarmRingCoordinator
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var alarmStore: AlarmStore
    @State private var showProPaywall = false
    @State private var proPaywallStartStep: ProPaywallStep = .intro
    @State private var showAddMenu = false
    @State private var showCreateAlarm = false
    @State private var showQuickAlarm = false
    @State private var showCreateHabit = false
    @State private var showTimer = false
    @State private var selectedAlarm: Alarm?

    init(viewModel: HomeViewModel, alarmStore: AlarmStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.alarmStore = alarmStore
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("More options"))
                    }
                    .padding(.top, Spacing.s)

                    HStack {
                        Button(action: {
                            proPaywallStartStep = .intro
                            showProPaywall = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentRed)
                                Text("PRO Free Trial")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Colors.accentRed.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressedScaleButtonStyle())

                        Spacer()
                    }


                    PromoCard(
                        iconSystemName: "moon.zzz.fill",
                        title: "Track your snoring",
                        subtitle: "Half of people snored last night"
                    ) {}

                    if !alarmStore.alarms.isEmpty {
                        Text("Ring in 19hrs 9min  >")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)

                        LazyVStack(spacing: Spacing.m) {
                            ForEach(alarmStore.alarms) { alarm in
                                SwipeableAlarmRow(
                                    onDelete: { alarmStore.remove(id: alarm.id) }
                                ) {
                                    AlarmCardView(
                                        alarm: alarm,
                                        onToggle: { alarmStore.toggleEnabled(id: alarm.id, enabled: $0) },
                                        onDelete: { alarmStore.remove(id: alarm.id) },
                                        onDuplicate: {
                                            alarmStore.add(alarm.duplicate())
                                        },
                                        onSkipOnce: {
                                            var updated = alarm
                                            updated.isSkippedOnce.toggle()
                                            alarmStore.update(updated)
                                        },
                                        onPreview: {
                                            ringCoordinator.startPreview(alarm: alarm)
                                        }
                                    )
                                    .onTapGesture(count: 2) {
                                        guard alarm.type == .wakeUp else { return }
                                        selectedAlarm = alarm
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No upcoming alarms")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.top, Spacing.s)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, AppConstants.tabBarHeight + Spacing.xl)
                }

                if alarmStore.alarms.isEmpty {
                    Text("No alarm set")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textTertiary)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                VStack {
                    Spacer()
                    Button(action: viewModel.tapRemoveAds) {
                        HStack(spacing: 8) {
                            Image(systemName: "nosign")
                                .foregroundColor(Colors.textSecondary)
                            Text("Remove all ads")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .accessibilityLabel(Text("Remove all ads"))
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.s)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddMenu.toggle()
                        }
                    }) {
                        Image(systemName: showAddMenu ? "xmark" : "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 62, height: 62)
                            .background(Colors.accentRed)
                            .clipShape(Circle())
                            .appShadow(Shadows.card)
                    }
                    .accessibilityLabel(Text("Add alarm"))
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.l)
                }
            }

            if showAddMenu {
                Colors.bgPrimary.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAddMenu = false
                        }
                    }

                FloatingAddMenu(
                    onSelectTimer: {
                        openTimer()
                    },
                    onSelectHabit: {
                        openCreateHabit()
                    },
                    onSelectQuick: {
                        openQuickAlarm()
                    },
                    onSelectAlarm: {
                        openCreateAlarm()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.showCelebration {
                CelebrationOverlayView {
                    viewModel.celebrationDidFinish()
                }
            }

            if viewModel.showDiscountPaywall {
                DiscountPaywallView(
                    preferences: viewModel.preferences,
                    onClose: viewModel.dismissPaywall,
                    onApply: viewModel.dismissPaywall,
                    onGetOffer: {
                        viewModel.dismissPaywall()
                        proPaywallStartStep = .planSelection
                        showProPaywall = true
                    }
                )
            }

            if showProPaywall {
                ProPaywallFlowView(startStep: proPaywallStartStep) {
                    showProPaywall = false
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear { viewModel.onAppear() }
        .onReceive(alarmStore.$alarms) { alarms in
            viewModel.preferences.hasAnyAlarm = !alarms.isEmpty
        }
        .fullScreenCover(isPresented: $showCreateAlarm) {
            CreateWakeUpAlarmView(
                alarmStore: alarmStore,
                onClose: { showCreateAlarm = false }
            )
        }
        .fullScreenCover(item: $selectedAlarm) { alarm in
            CreateWakeUpAlarmView(
                alarmStore: alarmStore,
                existingAlarm: alarm,
                onClose: { selectedAlarm = nil }
            )
        }
        .fullScreenCover(isPresented: $showQuickAlarm) {
            QuickAlarmView(
                alarmStore: alarmStore,
                onClose: { showQuickAlarm = false }
            )
            .background(ClearBackgroundView()) // Helper needed for transparency in fullScreenCover
        }
        .fullScreenCover(isPresented: $showCreateHabit) {
            CreateHabitAlarmView(
                alarmStore: alarmStore,
                onClose: { showCreateHabit = false }
            )
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerRootView(onClose: { showTimer = false })
        }
    }

    private func openCreateAlarm() {
        showAddMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCreateAlarm = true
        }
    }
    
    private func openQuickAlarm() {
        showAddMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showQuickAlarm = true
        }
    }

    private func openCreateHabit() {
        showAddMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCreateHabit = true
        }
    }

    private func openTimer() {
        showAddMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showTimer = true
        }
    }
}

private struct AlarmCardView: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onSkipOnce: () -> Void
    let onPreview: () -> Void

    private let weekdays: [String] = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text(alarm.emoji)
                            .font(.system(size: 16))
                        Text(alarm.name.isEmpty ? "Alarm" : alarm.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    if alarm.isSkippedOnce {
                        Text("alarm rings on \(nextDayText)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { alarm.enabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
            }
            
            HStack {
                if alarm.type == .quick {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                        Text("Quick Alarm")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Colors.accentTeal)
                } else {
                    HStack(spacing: 8) {
                        ForEach(0..<weekdays.count, id: \.self) { index in
                            Text(weekdays[index])
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isDayEnabled(index: index) ? Colors.textPrimary : Colors.textTertiary)
                                .opacity(isDayEnabled(index: index) ? 1.0 : 0.3)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(action: onPreview) {
                        Label("Preview alarm", systemImage: "eye")
                    }
                    Button(action: onSkipOnce) {
                        Label(alarm.isSkippedOnce ? "Undo skip" : "Skip once", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .padding(4)
                }
            }
        }
        .padding(Spacing.l)
        .background(Colors.cardSurface)
        .cornerRadius(24)
    }

    private func isDayEnabled(index: Int) -> Bool {
        let bit = 1 << index
        return (alarm.repeatMask & bit) != 0
    }
    
    private var nextDayText: String {
        let calendar = Calendar.current
        let nextDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: nextDate)
    }
}

private struct SwipeableAlarmRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let maxOffset: CGFloat = -86
    private let revealThreshold: CGFloat = -50

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.trailing, 4)

            content()
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.width < 0 || offset < 0 {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let total = offset + value.translation.width
                            if total < revealThreshold {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        offset = 0
                    }
                }
        }
        .animation(.easeInOut(duration: 0.18), value: offset)
    }
}
