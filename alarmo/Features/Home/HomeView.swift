import SwiftUI

struct HomeView: View {
    @EnvironmentObject var ringCoordinator: AlarmRingCoordinator
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var navStore: NavigationStore
    @State private var showProPaywall = false
    @State private var proPaywallStartStep: ProPaywallStep = .intro
    @State private var showAddMenu = false
    @State private var showCreateAlarm = false
    @State private var showQuickAlarm = false
    @State private var showCreateHabit = false
    @State private var showTimer = false
    @State private var selectedAlarm: Alarm?
    @State private var selectedHabitAlarm: Alarm?
    @State private var openAlarmActionsId: UUID? = nil
    @State private var showQuickSettings = false
    @AppStorage("qs_sortOrder") private var sortOrder = 0
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
                        Button(action: {
                            proPaywallStartStep = .intro
                            showProPaywall = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
                                Text("PRO Free Trial")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Colors.accentTeal.opacity(0.12),
                                                Colors.accentBlue.opacity(0.12)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Colors.accentTeal.opacity(0.55), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressedScaleButtonStyle())

                        Spacer()
                        
                        Button(action: { showQuickSettings = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("Quick Settings"))
                    }
                    .padding(.top, Spacing.s)


                    DailyInsightCard()

                    if !alarmStore.alarms.isEmpty {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(nextRingHeaderText(now: context.date))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                        }

                        LazyVStack(spacing: Spacing.m) {
                            ForEach(alarmStore.sortedAlarms(by: sortOrder)) { alarm in
                                SwipeableAlarmRow(
                                    onDelete: {
                                        scheduler.cancel(alarmId: alarm.id)
                                        alarmStore.remove(id: alarm.id) 
                                    }
                                ) {
                                    AlarmCardView(
                                        alarm: alarm,
                                        openActionsAlarmId: $openAlarmActionsId,
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
                                        switch alarm.type {
                                        case .wakeUp:
                                            selectedAlarm = alarm
                                        case .habit:
                                            selectedHabitAlarm = alarm
                                        case .quick:
                                            break
                                        }
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
                            .background(Colors.accentTeal)
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

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
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
                        .padding(.trailing, Spacing.l)
                        .padding(.bottom, AppConstants.tabBarHeight + Spacing.l + 74) // 62 (FAB) + 12 (gap)
                    }
                }
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
        .onAppear { 
            viewModel.onAppear() 
        }
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
        .fullScreenCover(item: $selectedHabitAlarm) { alarm in
            CreateHabitAlarmView(
                alarmStore: alarmStore,
                existingAlarm: alarm,
                onClose: { selectedHabitAlarm = nil }
            )
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerRootView(onClose: { showTimer = false })
        }
        .sheet(isPresented: $showQuickSettings) {
            QuickSettingsPanel(alarmStore: alarmStore)
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

    private func nextRingHeaderText(now: Date) -> String {
        let enabledAlarms = alarmStore.alarms.filter(\.enabled)
        guard !enabledAlarms.isEmpty else { return "No enabled alarm  >" }

        let nextFire = enabledAlarms
            .compactMap { AlarmStore.nextFireDate(for: $0, from: now) }
            .min()

        guard let target = nextFire else { return "No upcoming ring  >" }
        return "\(formatCountdownRelative(to: target, from: now, includePrefix: true))  >"
    }

    private func formatCountdownRelative(to target: Date, from now: Date, includePrefix: Bool) -> String {
        let diff = max(0, Int(target.timeIntervalSince(now)))
        let days = diff / 86_400
        let hours = (diff % 86_400) / 3_600
        let minutes = (diff % 3_600) / 60
        let seconds = diff % 60

        let base: String
        if days > 0 {
            base = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            base = "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            base = "\(minutes)m \(seconds)s"
        } else {
            base = "\(seconds)s"
        }

        return includePrefix ? "Ring in \(base)" : base
    }
}

private struct AlarmCardView: View {
    let alarm: Alarm
    @Binding var openActionsAlarmId: UUID?
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onSkipOnce: () -> Void
    let onPreview: () -> Void

    private let weekdays: [String] = ["S", "M", "T", "W", "T", "F", "S"]
    private var showActionsMenu: Bool { openActionsAlarmId == alarm.id }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            cardContent(now: context.date)
        }
    }

    @ViewBuilder
    private func cardContent(now: Date) -> some View {
        HStack(spacing: 16) {
            // LEFT: Time & Relative Status
            VStack(alignment: .leading, spacing: 0) {
                Text(alarm.timeString)
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundColor(alarm.enabled ? Colors.textPrimary : Colors.textTertiary)
                    .fixedSize(horizontal: true, vertical: false)
                
                if alarm.enabled {
                    if alarm.type == .quick || alarm.type == .habit {
                        if let nextDate = AlarmStore.nextFireDate(for: alarm, from: now) {
                            HStack(spacing: 5) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10, weight: .bold))
                                Text(compactCountdown(to: nextDate, now: now))
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .monospacedDigit()
                            }
                            .foregroundColor(Colors.accentTeal)
                            .padding(.top, 2)
                        }
                    } else {
                        Text(ringsInRelativeText(now: now))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(Colors.accentTeal)
                            .padding(.top, -2)
                    }
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
                
                if alarm.type == .quick || alarm.type == .habit {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(alarm.type == .quick ? "QUICK ALARM" : "HABIT ALARM")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Colors.accentTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Colors.accentTeal.opacity(0.1))
                            .cornerRadius(6)
                    }
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
                
                Button(action: toggleActionsMenu) {
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
        .overlay(alignment: .topTrailing) {
            if showActionsMenu {
                ZStack(alignment: .topTrailing) {
                    // Dismissal Layer
                    Color.black.opacity(0.001)
                        .frame(width: 3000, height: 3000)
                        .offset(x: 1000, y: -1000)
                        .onTapGesture {
                            withTransaction(Transaction(animation: nil)) {
                                openActionsAlarmId = nil
                            }
                        }

                    // Menu Actions
                    VStack(spacing: 0) {
                        actionRow(icon: "doc.on.doc", title: "Duplicate") {
                            withTransaction(Transaction(animation: nil)) { openActionsAlarmId = nil }
                            onDuplicate()
                        }
                        Divider().background(Colors.cardStroke)
                        actionRow(icon: "play.fill", title: "Preview") {
                            withTransaction(Transaction(animation: nil)) { openActionsAlarmId = nil }
                            onPreview()
                        }
                        Divider().background(Colors.cardStroke)
                        actionRow(icon: "arrow.uturn.forward", title: alarm.isSkippedOnce ? "Undo skip" : "Skip once") {
                            withTransaction(Transaction(animation: nil)) { openActionsAlarmId = nil }
                            onSkipOnce()
                        }
                        Divider().background(Colors.cardStroke)
                        actionRow(icon: "trash", title: "Delete", isDestructive: true) {
                            withTransaction(Transaction(animation: nil)) { openActionsAlarmId = nil }
                            onDelete()
                        }
                    }
                    .background(Colors.promoCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Colors.cardStroke.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .frame(width: 220)
                    .padding(.trailing, 8)
                    .padding(.top, 54)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .zIndex(showActionsMenu ? 10 : 0)
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

    private func ringsInRelativeText(now: Date) -> String {
        guard let nextDate = AlarmStore.nextFireDate(for: alarm, from: now) else { return "" }
        let diff = max(0, Int(nextDate.timeIntervalSince(now)))
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

    private func compactCountdown(to nextDate: Date, now: Date) -> String {
        let diff = max(0, Int(nextDate.timeIntervalSince(now)))
        let days = diff / 86_400
        let hours = (diff % 86_400) / 3_600
        let minutes = (diff % 3_600) / 60
        let seconds = diff % 60

        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func toggleActionsMenu() {
        withTransaction(Transaction(animation: nil)) {
            openActionsAlarmId = showActionsMenu ? nil : alarm.id
        }
    }

    @ViewBuilder
    private func actionRow(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withTransaction(Transaction(animation: nil)) {
                openActionsAlarmId = nil
            }
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDestructive ? Colors.accentRed : Colors.textPrimary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? Colors.accentRed : Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
        }
        .buttonStyle(.plain)
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
