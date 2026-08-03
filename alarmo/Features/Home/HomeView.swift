import SwiftUI
import UIKit

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
    @State private var showAlarmExpandedPanel = false
    @State private var selectedAlarm: Alarm?
    @State private var selectedQuickAlarm: Alarm?
    @State private var selectedHabitAlarm: Alarm?
    @State private var openAlarmActionsId: UUID? = nil
    @State private var showQuickSettings = false
    @State private var isReorderingAlarms = false
    @AppStorage("qs_sortOrder") private var sortOrder = 0
    private let scheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    let appPreferences: AppPreferences

    init(viewModel: HomeViewModel, alarmStore: AlarmStore, appPreferences: AppPreferences = AppPreferences()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.alarmStore = alarmStore
        self.appPreferences = appPreferences
    }

    var body: some View {
        ZStack {
            homeBackground
            
            mainContent
            
            fabOverlay
            
            addMenuOverlay
            
            if viewModel.showCelebration {
                CelebrationOverlayView {
                    viewModel.celebrationDidFinish()
                }
            }

            if viewModel.showDiscountPaywall {
                DiscountPaywallView(
                    preferences: viewModel.preferences,
                    onSkip: {
                        viewModel.dismissPaywall()
                        proPaywallStartStep = .planSelection
                        showProPaywall = true
                    },
                    onApply: {
                        viewModel.dismissPaywall()
                    },
                    onGetOffer: {
                        viewModel.dismissPaywall()
                        proPaywallStartStep = .planSelection
                        showProPaywall = true
                    },
                    onSuccess: {
                        viewModel.dismissPaywall()
                    }
                )
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
        .fullScreenCover(item: $selectedQuickAlarm) { alarm in
            QuickAlarmView(
                alarmStore: alarmStore,
                onClose: { selectedQuickAlarm = nil },
                existingAlarm: alarm
            )
            .background(ClearBackgroundView())
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
            TimerRootView(onClose: {
                navStore.selectedTab = .alarm
                showTimer = false
            })
        }
        .sheet(isPresented: $showQuickSettings) {
            QuickSettingsPanel(alarmStore: alarmStore)
        }
        .fullScreenCover(isPresented: $showProPaywall) {
            ProPaywallFlowView(startStep: proPaywallStartStep) {
                showProPaywall = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var homeBackground: some View {
        Colors.bgPrimary
            .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                headerRow
                
                DailyInsightCard()
                
                if !alarmStore.alarms.isEmpty {
                    alarmList
                } else {
                    noAlarmsView
                }
                
                Spacer(minLength: 120)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, AppConstants.tabBarHeight + Spacing.xl)
        }
    }
    
    private var headerRow: some View {
        HStack {
            Spacer()

            quickSettingsButton
        }
        .padding(.top, Spacing.s)
    }
    
    private var proTrialButton: some View {
        Button(action: {
            proPaywallStartStep = .intro
            showProPaywall = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Colors.accentTeal, Colors.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
    }
    
    private var quickSettingsButton: some View {
        Button(action: { 
            showQuickSettings = true 
        }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text("Quick Settings"))
    }
    
    private var alarmList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            let baseAlarms = (isReorderingAlarms || sortOrder == 3)
                ? alarmStore.alarms
                : alarmStore.sortedAlarms(by: sortOrder)
            let displayedAlarms = baseAlarms

            HStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(nextRingHeaderText(now: context.date, alarms: displayedAlarms))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
                Spacer()
                if displayedAlarms.count > 1 {
                    Button(isReorderingAlarms ? "Done" : "Edit") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            if !isReorderingAlarms {
                                sortOrder = 3
                                openAlarmActionsId = nil
                            }
                            isReorderingAlarms.toggle()
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.accentTeal)
                }
            }
            
            VStack(spacing: Spacing.m) {
                ForEach(Array(displayedAlarms.enumerated()), id: \.element.id) { index, alarm in
                    if isReorderingAlarms {
                        AlarmCardView(
                            alarm: alarm,
                            openActionsAlarmId: $openAlarmActionsId,
                            onToggle: { _ in },
                            onDelete: {},
                            onDuplicate: {},
                            onSkipOnce: {},
                            onPreview: {},
                            isReorderMode: true
                        )
                        .draggable(alarm.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let payload = items.first else { return false }
                            return handleDrop(on: alarm.id, payload: payload)
                        }
                        .zIndex(openAlarmActionsId == alarm.id ? 100_000 : (openAlarmActionsId == nil ? 0 : -100))
                    } else {
                        SwipeableAlarmRow(
                            isForcedRevealed: .constant(false),
                            rowAlarmId: alarm.id,
                            activeMenuAlarmId: openAlarmActionsId,
                            onEdit: {
                                switch alarm.type {
                                case .wakeUp: selectedAlarm = alarm
                                case .habit: selectedHabitAlarm = alarm
                                case .quick: selectedQuickAlarm = alarm
                                }
                            },
                            onDoubleTap: {
                                switch alarm.type {
                                case .wakeUp: selectedAlarm = alarm
                                case .habit: selectedHabitAlarm = alarm
                                case .quick: selectedQuickAlarm = alarm
                                }
                            },
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
                                },
                                isReorderMode: false
                            )
                        }
                        .zIndex(openAlarmActionsId == alarm.id ? 100_000 : (openAlarmActionsId == nil ? 0 : -100))
                    }
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let payload = items.first,
                      let draggedId = UUID(uuidString: payload),
                      let source = alarmStore.alarms.firstIndex(where: { $0.id == draggedId }) else { return false }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                    alarmStore.moveAlarm(from: source, to: alarmStore.alarms.count)
                    sortOrder = 3
                }
                return true
            }
        }
    }
    
    private var noAlarmsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No upcoming alarms")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .padding(.top, Spacing.s)
        }
    }
    
    private var fabOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(spacing: 10) {
                        launcherCircleButton(icon: "plus", tint: Colors.accentRed) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showAddMenu.toggle()
                                showAlarmExpandedPanel = false
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Colors.accentTeal)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Colors.cardStroke.opacity(0.35), lineWidth: 1)
                    )
                    .appShadow(alarmLauncherShadow)
                }
                .padding(.trailing, Spacing.l)
                .padding(.bottom, AppConstants.tabBarHeight + Spacing.l)
            }
        }
    }
    
    private var addMenuOverlay: some View {
        Group {
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
                            onSelectQuick: {
                                openQuickAlarm()
                            },
                            onSelectAlarm: {
                                openCreateAlarm()
                            }
                        )
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func openCreateAlarm() {
        showAddMenu = false
        sortOrder = 3
        withAnimation(.easeInOut(duration: 0.2)) {
            showAlarmExpandedPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCreateAlarm = true
        }
    }

    private func openEditAlarmFromLauncher() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.2)) {
            showAlarmExpandedPanel = false
        }
        if let existing = alarmStore.alarms.sorted(by: { lhs, rhs in
            (lhs.hour * 60 + lhs.minute) < (rhs.hour * 60 + rhs.minute)
        }).first {
            selectedAlarm = existing
        } else {
            openCreateAlarm()
        }
    }
    
    private func openQuickAlarm() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
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

    private func nextRingHeaderText(now: Date, alarms: [Alarm]) -> String {
        let enabledAlarms = alarms.filter(\.enabled)
        guard !enabledAlarms.isEmpty else {
            return "No enabled alarm  >"
        }

        let nextFire = enabledAlarms
            .compactMap { AlarmStore.nextFireDate(for: $0, from: now) }
            .min()

        guard let target = nextFire else {
            return "No upcoming ring  >"
        }
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

    private func handleDrop(on targetID: UUID, payload: String) -> Bool {
        guard let draggedID = UUID(uuidString: payload),
              draggedID != targetID,
              let source = alarmStore.alarms.firstIndex(where: { $0.id == draggedID }),
              let target = alarmStore.alarms.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            alarmStore.moveAlarm(from: source, to: target > source ? target + 1 : target)
            sortOrder = 3
        }
        return true
    }
}

private extension HomeView {
    var alarmLauncherShadow: AppShadow {
        SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch
            ? AppShadow(
                color: Colors.shadow.opacity(0.5),
                radius: Shadows.card.radius * 0.5,
                x: Shadows.card.x,
                y: Shadows.card.y * 0.5
            )
            : Shadows.card
    }

    func launcherCircleButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PressedScaleButtonStyle())
    }

    var alarmExpandedPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                alarmExpandedRow(
                    icon: "alarm.fill",
                    title: "New Alarm",
                    tint: Colors.accentRed,
                    action: { openCreateAlarm() }
                )

                alarmExpandedRow(
                    icon: "bolt.fill",
                    title: "Quick Alarm",
                    tint: Colors.accentBlue,
                    action: { openQuickAlarm() }
                )
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Colors.cardStroke, lineWidth: 1.2)
            )
            .appShadow(Shadows.card)

            AlarmPanelPointer()
                .fill(Colors.cardSurface)
                .frame(width: 14, height: 18)
                .overlay(
                    AlarmPanelPointer()
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
                .rotationEffect(.degrees(-90))
                .offset(x: 18, y: 56)
        }
    }

    func alarmExpandedRow(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}

private struct AlarmPanelPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
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
    let isReorderMode: Bool

    @ObservedObject private var pauseStore = QuickAlarmPauseStore.shared

    private let weekdays: [String] = ["S", "M", "T", "W", "T", "F", "S"]
    private var showActionsMenu: Bool { openActionsAlarmId == alarm.id }
    private var isPausedQuick: Bool { alarm.type == .quick && pauseStore.isPaused(alarm.id) }

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
                    .foregroundColor((alarm.enabled || isPausedQuick) ? Colors.textPrimary : Colors.textTertiary)
                    .fixedSize(horizontal: true, vertical: false)

                if isPausedQuick {
                    HStack(spacing: 5) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(frozenCountdown(seconds: pauseStore.remaining(alarm.id) ?? 0))
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundColor(Colors.textSecondary)
                    .padding(.top, 2)
                } else if alarm.enabled {
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
                    // Keep the badge on a single line so a Quick/Habit alarm card
                    // matches the height & shape of a regular alarm's weekday row
                    // (otherwise "QUICK ALARM" wraps to two lines and the card
                    // becomes taller than the standard alarm card).
                    Text(alarm.type == .quick ? "QUICK ALARM" : "HABIT ALARM")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Colors.accentTeal)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Colors.accentTeal.opacity(0.1))
                        .cornerRadius(6)
                        .frame(height: 18)
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<weekdays.count, id: \.self) { index in
                            let isEnabled = isDayEnabled(index: index)
                            Text(weekdays[index])
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(isEnabled ? Colors.accentTeal : Colors.textTertiary.opacity(0.3))
                                .frame(width: 12, alignment: .center)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(height: 18)
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
                if isReorderMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Colors.bgPrimary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    if alarm.type == .quick {
                        // A quick alarm is a one-shot countdown, so a pause/resume
                        // control (like a timer) is more useful than an on/off
                        // toggle. Small, circular — the widely-used timer pattern.
                        quickAlarmPauseResumeButton
                    } else {
                        Toggle("", isOn: Binding(
                            get: { alarm.enabled },
                            set: { onToggle($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                        .scaleEffect(0.85)
                        .frame(width: 48, height: 28)
                    }

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
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 18)
        // Fill the available width so every alarm card is identical in size
        // regardless of its content (a Quick/Habit badge is narrower than the
        // weekday row, which previously let the card hug its content and render
        // narrower than a standard alarm). The width proposal flows down to the
        // HStack so its Spacer expands and the toggle stays pinned to the right.
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .zIndex(showActionsMenu ? 100_000 : 0)
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

    /// Frozen "HH:MM:SS" shown while a quick alarm is paused.
    private func frozenCountdown(seconds: Int) -> String {
        let diff = max(0, seconds)
        let hours = diff / 3_600
        let minutes = (diff % 3_600) / 60
        let secs = diff % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    /// Small circular pause/resume control for a running or paused quick alarm.
    private var quickAlarmPauseResumeButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            QuickAlarmPauseCoordinator.toggle(alarm)
        }) {
            Image(systemName: isPausedQuick ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 32)
                .background(
                    Capsule().fill(isPausedQuick ? Colors.accentGreen : Colors.accentTeal)
                )
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(isPausedQuick ? "Resume quick alarm" : "Pause quick alarm"))
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
    @Binding var isForcedRevealed: Bool
    let rowAlarmId: UUID
    let activeMenuAlarmId: UUID?
    let onEdit: () -> Void
    let onDoubleTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let maxOffset: CGFloat = -166
    private let revealThreshold: CGFloat = -84

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) { offset = 0 }
                    onEdit()
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Colors.accentTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) { offset = 0 }
                    onDelete()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.trailing, 4)

            content()
                // Force a definite full-width proposal so the card fills the row
                // regardless of its intrinsic content (otherwise the ZStack hands
                // the card its content-hugging ideal width — wide for a weekday
                // row, narrow for a Quick/Habit badge — making cards different
                // widths). Must be applied before `.offset` so the frame sizes to
                // the row, not the shifted content.
                .frame(maxWidth: .infinity)
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
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        onDoubleTap()
                    }
                )
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.18), value: offset)
        .onChange(of: isForcedRevealed) { _, revealed in
            if revealed {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    offset = maxOffset
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    offset = 0
                }
            }
        }
        .onChange(of: activeMenuAlarmId) { _, newValue in
            guard let openId = newValue, openId != rowAlarmId else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                offset = 0
            }
        }
    }
}
