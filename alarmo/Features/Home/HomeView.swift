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
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()

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
                                    onDelete: {
                                        scheduler.cancel(alarmId: alarm.id)
                                        alarmStore.remove(id: alarm.id) 
                                    }
                                ) {
                                    AlarmCardView(
                                        alarm: alarm,
                                        onToggle: { isEnabled in
                                            alarmStore.toggleEnabled(id: alarm.id, enabled: isEnabled)
                                            // Update scheduling
                                            var updated = alarm
                                            updated.enabled = isEnabled
                                            scheduler.schedule(alarm: updated)
                                        },
                                        onDelete: {
                                            scheduler.cancel(alarmId: alarm.id)
                                            alarmStore.remove(id: alarm.id)
                                        },
                                        onDuplicate: {
                                            let newAlarm = alarm.duplicate()
                                            alarmStore.add(newAlarm)
                                            if newAlarm.enabled {
                                                scheduler.schedule(alarm: newAlarm)
                                            }
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
        HStack(spacing: 16) {
            // LEFT: Time & Relative Status
            VStack(alignment: .leading, spacing: 0) {
                Text(alarm.timeString)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(alarm.enabled ? Colors.textPrimary : Colors.textTertiary)
                    .fixedSize(horizontal: true, vertical: false)
                
                if alarm.enabled {
                    Text(ringsInRelativeText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .padding(.top, -2)
                }
            }
            .layoutPriority(1)
            
            // MIDDLE: Identity & Schedule
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(alarm.emoji)
                        .font(.system(size: 14))
                    Text(alarm.name.isEmpty ? "Alarm" : alarm.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                }
                
                if alarm.type == .quick {
                    Text("QUICK ALARM")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Colors.accentTeal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Colors.accentTeal.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<weekdays.count, id: \.self) { index in
                            let isEnabled = isDayEnabled(index: index)
                            Text(weekdays[index])
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(isEnabled ? Colors.accentTeal : Colors.textTertiary.opacity(0.3))
                        }
                    }
                }
                
                if let city = alarm.timeZoneCity, alarm.timeZoneMode == .custom {
                    HStack(spacing: 4) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 9))
                        Text(city.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundColor(Colors.textSecondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            // RIGHT: Toggle & Actions
            VStack(alignment: .trailing, spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { alarm.enabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .scaleEffect(0.85)
                .frame(width: 48, height: 28)
                
                Menu {
                    Button(action: onDuplicate) { Label("Duplicate", systemImage: "doc.on.doc") }
                    Button(action: onPreview) { Label("Preview", systemImage: "eye") }
                    Button(action: onSkipOnce) { Label(alarm.isSkippedOnce ? "Undo skip" : "Skip once", systemImage: "arrow.clockwise") }
                    Divider()
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Colors.bgPrimary.opacity(0.4))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Colors.cardSurface
                if alarm.enabled {
                    LinearGradient(
                        colors: [Colors.accentTeal.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(alarm.enabled ? Colors.accentTeal.opacity(0.15) : Color.white.opacity(0.06), lineWidth: 1)
        )
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

    private var ringsInRelativeText: String {
        guard let nextDate = AlarmStore.nextFireDate(for: alarm, from: Date()) else { return "" }
        let diff = Int(nextDate.timeIntervalSince(Date()))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        let seconds = diff % 60
        
        if days > 0 {
            return "In \(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "In \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "In \(minutes)m \(seconds)s"
        } else {
            return "In \(seconds)s"
        }
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
