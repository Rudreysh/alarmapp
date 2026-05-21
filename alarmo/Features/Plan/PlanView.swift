import SwiftUI
import SwiftUI
import Combine
import SwiftData

struct PlanView: View {
    let preferences: AppPreferences
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject var viewModel = PlanViewModel()
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCoachMark = false          // FAB
    @State private var showQuickLogCoachMark = false
    @State private var showPlanSwipeCoachMark = false        // Swipe-to-delete
    @State private var showPlanCalendarCoachMark = false     // Calendar navigation
    @State private var showHabitCelebration = false
    @State private var celebrationHabitTitle: String?
    @State private var celebrationHideTask: Task<Void, Never>?
    
    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
    }
    
    // Fetch all active items
    @Query(filter: #Predicate<PlanItem> { !$0.isArchived }, sort: \PlanItem.createdAt, order: .reverse)
    var allItems: [PlanItem]
    
    // Sheets
    @State private var showingHabitSheet = false
    @State private var showUpsell = false
    @State private var showShieldSettings = false
    @State private var showMoodSheet = false
    @State private var showMoodStatsFullScreen = false
    
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("plan_mood_records_v1") private var moodRecordsData = "{}"
    @AppStorage("plan_mood_banner_dismissed_v1") private var moodDismissedData = "{}"
    @AppStorage("plan_mood_notes_v1") private var moodNotesData = "{}" // date|segment -> context
    @AppStorage("plan_mood_factors_v1") private var moodFactorsData = "{}" // date|segment -> [String]
    @AppStorage("plan_usage_days_v1") private var usageDaysData = "{}" // yyyy-MM-dd -> true
    @AppStorage("plan_usage_banner_dismissed_day_v1") private var usageBannerDismissedDay = ""
    
    // Section Expansion State
    
    
    @State private var selectedItem: PlanItem? // For detail
    @State private var editingItem: PlanItem? // For edit
    @State private var editingNote: PlanItem? // For note editing
    @State private var habitEditMode: EditMode = .inactive
    @State private var selectedHabitIDsForDeletion: Set<UUID> = []
    
    // Timer State
    
    @EnvironmentObject var pomoEngine: PomodoroEngine
    @EnvironmentObject var navStore: NavigationStore
    // If pomoEngine is not in environment, I might need to check App entry point. 
    // Assuming PomoTimerView uses `PomodoroEngine`.
    // Let's assume we navigate to `PomoTimerView`.
    
    // Actually, PomoTimerView takes `viewModel` and `engine`.
    // I will use a fullScreenCover to show a wrapper for PomoTimerView.
    
    @State private var floatingBubbles: [FloatingBubble] = []
    private let floatingActionButtonBottomPadding: CGFloat = AppConstants.tabBarHeight + Spacing.l
    private let floatingActionButtonSize: CGFloat = 62
    private var listBottomClearance: CGFloat {
        // Keep bottom rows clearly above the floating + button and tab bar.
        floatingActionButtonBottomPadding + (floatingActionButtonSize * 0.5) + 22
    }
    
    struct FloatingBubble: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let value: String
    }
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                // Unified Header is now inside CalendarHeaderView
                // PlanHeaderView() removed
                
                // Calendar Header
                CalendarHeaderView(
                    selectedDate: $viewModel.selectedDate,
                    isListView: $viewModel.isListView,
                    showCalendarCoachMark: $showPlanCalendarCoachMark,
                    moodEmoji: selectedMoodForCurrentSegment?.emoji,
                    hasMoodNoteOnDate: hasMoodNoteOnDate,
                    onMoodTap: {
                        showMoodSheet = true
                    }
                )

                // Content
                if viewModel.isListView {
                    // Timeline List View
                    List {
                        let filtered = viewModel.items(from: allItems)
                        let habits = filtered.filter { $0.type == .habit }
                            .sorted { ($0.scheduledTime ?? Date.distantPast) < ($1.scheduledTime ?? Date.distantPast) }
                        let firstVisibleItemId = habits.first?.id

                        if !habits.isEmpty {
                            Section(header: timelineSectionHeader(title: "Habits", count: habits.count, icon: "heart.fill")) {
                                ForEach(Array(habits.enumerated()), id: \.element.id) { index, item in
                                    let timeStr = item.anytime ? "" : formatTime(item.scheduledTime)
                                    PlanItemTimelineRow(item: item, timeString: timeStr, selectedDate: viewModel.selectedDate, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                        viewModel.toggleComplete(item, context: modelContext)
                                    } onPlay: {
                                        startTimer(for: item)
                                    } onQuickAdd: { _, position in
                                        if index == 0 && !preferences.hasSeenQuickLogTooltip {
                                            preferences.hasSeenQuickLogTooltip = true
                                            showQuickLogCoachMark = false
                                        }
                                        let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                        addFloatingBubble(value: "+\(Int(amount))", at: position)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    } onAdjust: { delta in
                                        viewModel.updateHabitValue(item, delta: delta, context: modelContext)
                                    }
                                    .coachMark(
                                        title: "Manage",
                                        subtitle: "Swipe to edit or delete.",
                                        isVisible: Binding(get: { item.id == firstVisibleItemId ? showPlanSwipeCoachMark : false }, set: { showPlanSwipeCoachMark = $0 }),
                                        alignment: .top,
                                        pointDirection: .bottom,
                                        arrowAlignment: .center,
                                        arrowOffsetX: 0,
                                        bubbleOffsetX: 0,
                                        bubbleOffsetY: -60,
                                        color: .red
                                    )
                                    .coachMark(
                                        title: "Quick Log",
                                        subtitle: "Tap + to log progress.",
                                        isVisible: Binding(get: { index == 0 ? showQuickLogCoachMark : false }, set: { showQuickLogCoachMark = $0 }),
                                        alignment: .bottomTrailing,
                                        pointDirection: .top,
                                        arrowAlignment: .trailing,
                                        arrowOffsetX: -50,
                                        bubbleOffsetX: -10,
                                        bubbleOffsetY: 12
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedItem = item
                                    }
                                    .id(item.updatedAt) // Force Refresh
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            dismissSwipeCoachMark()
                                            deleteItem(item)
                                        } label: { Label("Delete", systemImage: "trash") }
                                        Button {
                                            dismissSwipeCoachMark()
                                            startEditing(item)
                                        } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.visible, axes: .vertical)
                    .scrollIndicatorsFlash(onAppear: true)
                    .environment(\.defaultMinListHeaderHeight, 18)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: listBottomClearance)
                            .allowsHitTesting(false)

                    }
                } else {
                    // Standard Calendar Mode (Sections)
                    List {
                        // Items List
                        let filtered = viewModel.items(from: allItems)
                        let habits = filtered.filter { $0.type == .habit }
                            .sorted(by: habitDisplayOrder(lhs:rhs:))
                        let firstVisibleItemId = habits.first?.id
                        
                         // Habits Section
                        if !habits.isEmpty {
                            Section(header: 
                                HStack {
                                    Button(action: { withAnimation { viewModel.isHabitsExpanded.toggle() } }) {
                                        HStack {
                                            Text("Habits (\(habits.count))")
                                               .font(.system(size: 14, weight: .medium))
                                               .foregroundColor(PlanPalette.textSecondary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(PlanPalette.textSecondary)
                                                .rotationEffect(.degrees(viewModel.isHabitsExpanded ? 90 : 0))
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if viewModel.isHabitsExpanded {
                                        if habitEditMode == .active {
                                            Button("Delete Selected") {
                                                deleteSelectedHabits()
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(selectedHabitIDsForDeletion.isEmpty ? Colors.textSecondary : .red)
                                            .disabled(selectedHabitIDsForDeletion.isEmpty)
                                            .padding(.trailing, 4)
                                        }

                                        Button(habitEditMode == .active ? "Done" : "Edit") {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                let becomingActive = habitEditMode != .active
                                                habitEditMode = becomingActive ? .active : .inactive
                                                if !becomingActive {
                                                    selectedHabitIDsForDeletion.removeAll()
                                                }
                                            }
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Colors.accentTeal)
                                    }
                                }
                                .padding(.leading, -16)
                            ) {
                                if viewModel.isHabitsExpanded {
                                    ForEach(habits, id: \.id) { item in
                                        HStack(spacing: 10) {
                                            if habitEditMode == .active {
                                                Button {
                                                    toggleHabitSelection(item.id)
                                                } label: {
                                                    Image(systemName: selectedHabitIDsForDeletion.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                                        .font(.system(size: 20, weight: .semibold))
                                                        .foregroundColor(selectedHabitIDsForDeletion.contains(item.id) ? .red : Colors.textSecondary)
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            PlanItemRow(item: item, selectedDate: viewModel.selectedDate, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                                viewModel.toggleComplete(item, context: modelContext)
                                            } onPlay: {
                                                startTimer(for: item)
                                            } onQuickAdd: { _, position in
                                                if item.id == firstVisibleItemId && !preferences.hasSeenQuickLogTooltip {
                                                    preferences.hasSeenQuickLogTooltip = true
                                                    showQuickLogCoachMark = false
                                                }
                                                let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                                addFloatingBubble(value: "+\(Int(amount))", at: position)
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            } onAdjust: { delta in
                                                viewModel.updateHabitValue(item, delta: delta, context: modelContext)
                                            }
                                            .coachMark(
                                                title: "Manage",
                                                subtitle: "Swipe to edit or delete.",
                                                isVisible: Binding(get: { item.id == firstVisibleItemId ? showPlanSwipeCoachMark : false }, set: { showPlanSwipeCoachMark = $0 }),
                                                alignment: .top,
                                                pointDirection: .bottom,
                                                arrowAlignment: .center,
                                                arrowOffsetX: 0,
                                                bubbleOffsetX: 0,
                                                bubbleOffsetY: -60,
                                                color: .red
                                            )
                                            .coachMark(
                                                title: "Quick Log",
                                                subtitle: "Tap + to log progress.",
                                                isVisible: Binding(get: { item.id == firstVisibleItemId ? showQuickLogCoachMark : false }, set: { showQuickLogCoachMark = $0 }),
                                                alignment: .bottomTrailing,
                                                pointDirection: .top,
                                                arrowAlignment: .trailing,
                                                arrowOffsetX: -50,
                                                bubbleOffsetX: -10,
                                                bubbleOffsetY: 12
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                guard habitEditMode != .active else {
                                                    toggleHabitSelection(item.id)
                                                    return
                                                }
                                                // Tap on habit -> Open Detail View (Start Focus screen)
                                                selectedItem = item
                                            }
                                        }
                                        .id(item.updatedAt) // Force Refresh
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .id(item.updatedAt) // Force Refresh
                                        .contextMenu {
                                            Button {
                                                viewModel.skipHabitForSelectedDate(item, context: modelContext)
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            } label: {
                                                Label("Skip for This Day", systemImage: "forward.end.fill")
                                            }
                                            Button {
                                                startEditing(item)
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                deleteItem(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    habitEditMode = .active
                                                }
                                            } label: {
                                                Label("Rearrange", systemImage: "line.3.horizontal")
                                            }
                                        }
                                        .moveDisabled(habitEditMode != .active)
                                    }
                                    .onMove { source, destination in
                                        moveHabits(from: source, to: destination, visibleHabits: habits)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.visible, axes: .vertical)
                    .scrollIndicatorsFlash(onAppear: true)
                    .environment(\.editMode, $habitEditMode)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: listBottomClearance)
                            .allowsHitTesting(false)

                    }
                }
            }
            
            // Floating Bubbles Overlay
            Group {
                ForEach(floatingBubbles) { bubble in
                    Text(bubble.value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PlanPalette.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .planGlassPanel(cornerRadius: 10, fillOpacity: 0.14)
                        .position(x: bubble.x, y: bubble.y)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .offset(y: -100).combined(with: .opacity)))
                }
            }
            .allowsHitTesting(false)
            
            // FAB
            Button(action: {
                let habitCount = allItems.filter { $0.type == .habit }.count
                preferences.hasSeenPlanHabitVsTaskTooltip = true
                if preferences.hasSeenPlanTooltip == false {
                    preferences.hasSeenPlanTooltip = true
                    showCoachMark = false
                }
                if !subManager.isPro && habitCount >= 2 {
                    showUpsell = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    showingHabitSheet = true
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 62, height: 62)
                    .background(Colors.accentTeal)
                    .clipShape(Circle())
                    .appShadow(Shadows.card)
                    .coachMark(
                        title: "Create Habit",
                        subtitle: "Tap to add habit.",
                        isVisible: $showCoachMark,
                        alignment: .topTrailing,
                        pointDirection: .bottom,
                        arrowAlignment: .trailing,
                        arrowOffsetX: -24,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -80,
                        color: .red
                    )
            }
            .padding(.trailing, Spacing.l)
            .padding(.bottom, floatingActionButtonBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .zIndex(4)

            if showHabitCelebration {
                HabitGoalCelebrationOverlay(habitTitle: celebrationHabitTitle)
                    .zIndex(30)
            }
        }
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.allItems = allItems
            cleanupLegacyAnytimeDefaults()
            normalizeHabitSortOrderIfNeeded()
            registerUsageForToday()

            // Register HealthKit observer so the view re-syncs whenever the OS
            // delivers new health samples (e.g. steps accumulating in real-time).
            // Pass nil so syncHealthData uses viewModel.allItems (always current).
            HealthKitManager.shared.startObservingHealthData {
                Task { @MainActor in
                    await viewModel.syncHealthData()
                }
            }

            Task {
                await viewModel.syncHealthData(from: allItems)
            }
            if !preferences.hasSeenPlanTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showCoachMark = true }
                }
            } else if !preferences.hasSeenPlanSwipeTooltip && !allItems.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showPlanSwipeCoachMark = true }
                }
            } else if !preferences.hasSeenPlanCalendarTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showPlanCalendarCoachMark = true }
                }
            } else if !preferences.hasSeenQuickLogTooltip && allItems.contains(where: { $0.type == .habit }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showQuickLogCoachMark = true }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            registerUsageForToday()
            // Re-register observer in case iOS killed it while in background
            HealthKitManager.shared.startObservingHealthData {
                Task { @MainActor in
                    await viewModel.syncHealthData()
                }
            }
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
        }
        .sheet(item: $editingItem) { item in
             CreatePlanItemView(editingItem: item)
        }
        .sheet(item: $editingNote) { item in
             CreateNoteView(itemToEdit: item)
                 .presentationDetents([.height(140)])
                 .presentationDragIndicator(.hidden)
                 .presentationBackground(.clear)
        }
        .sheet(item: $selectedItem) { item in
             if item.type == .task || item.type == .note {
                 PlanItemTaskDetailView(item: item, onDismiss: { selectedItem = nil })
                     .presentationDetents([.medium, .large])
             } else {
                 PlanItemDetailView(item: item)
             }
        }
        .sheet(isPresented: $showingHabitSheet) {
            CreateHabitGalleryView()
        }
        .fullScreenCover(isPresented: $showUpsell) {
            ProUpsellFlowView()
        }
        .sheet(isPresented: $showShieldSettings) {
            AccountabilityShieldSettingsView()
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodPickerBottomSheet(
                segment: currentMoodSegment,
                selectedMood: selectedMoodForCurrentSegment,
                selectedDate: viewModel.selectedDate,
                moodRecordsData: $moodRecordsData,
                moodNotesData: $moodNotesData,
                moodFactorsData: $moodFactorsData
            ) {
                showMoodSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    showMoodStatsFullScreen = true
                }
            } onSelect: { mood in
                setMood(mood, for: currentMoodSegment, on: viewModel.selectedDate)
            }
            .presentationDetents([.height(360), .height(720), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showMoodStatsFullScreen) {
            MoodStatisticsFullScreenView(
                recordsData: moodRecordsData,
                notesData: $moodNotesData,
                referenceDate: viewModel.selectedDate
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            if showPlanCalendarCoachMark {
                showPlanCalendarCoachMark = false
                preferences.hasSeenPlanCalendarTooltip = true
            }
            // Refresh health data for the newly selected date
            Task {
                await viewModel.syncHealthDataForDate(newDate, from: allItems)
            }
        }
        .onChange(of: allItems.count) { _, _ in
            viewModel.allItems = allItems
            normalizeHabitSortOrderIfNeeded()
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
            // Retry after a short delay — HealthKit sometimes needs a moment after
            // first authorization before it returns data from a fresh query.
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await viewModel.syncHealthData(from: allItems)
            }
        }
        .onChange(of: showCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenPlanTooltip {
                preferences.hasSeenPlanTooltip = true
                if !allItems.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPlanSwipeCoachMark = true }
                }
            }
        }
        .onChange(of: showPlanSwipeCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenPlanSwipeTooltip {
                preferences.hasSeenPlanSwipeTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPlanCalendarCoachMark = true }
            }
        }
        .onChange(of: showPlanCalendarCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenPlanCalendarTooltip {
                preferences.hasSeenPlanCalendarTooltip = true
                if allItems.contains(where: { $0.type == .habit }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showQuickLogCoachMark = true }
                }
            }
        }
        .onChange(of: showQuickLogCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenQuickLogTooltip {
                preferences.hasSeenQuickLogTooltip = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PlanViewModel.habitGoalReachedNotification)) { output in
            triggerHabitCelebration(with: output.userInfo?["habitTitle"] as? String)
        }
        .onDisappear {
            celebrationHideTask?.cancel()
        }
    }
    
    private func dismissSwipeCoachMark() {
        if showPlanSwipeCoachMark {
            showPlanSwipeCoachMark = false
            preferences.hasSeenPlanSwipeTooltip = true
        }
    }

    private func triggerHabitCelebration(with title: String?) {
        guard settings.habitGoalCelebrationEnabled else { return }
        celebrationHideTask?.cancel()
        celebrationHabitTitle = title

        withAnimation(.easeOut(duration: 0.25)) {
            showHabitCelebration = true
        }

        celebrationHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.85)) {
                    showHabitCelebration = false
                }
            }
        }
    }
    
    private func addFloatingBubble(value: String, at position: CGPoint) {
        let newBubble = FloatingBubble(x: position.x, y: position.y, value: value)
        floatingBubbles.append(newBubble)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                floatingBubbles.removeAll { $0.id == newBubble.id }
            }
        }
    }
    
    private func startTimer(for item: PlanItem) {
        // Configure engine
        pomoEngine.apply(planItem: item)
        pomoEngine.start(taskId: item.id)
        
        // Navigate to Timer Tab
        navStore.requestedTimerMode = .pomo
        withAnimation {
            navStore.selectedTab = .timer
        }
        
        // Trigger impact
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func deleteItem(_ item: PlanItem) {
        item.isArchived = true
        item.archivedAt = Date()
        item.updatedAt = Date()
        try? modelContext.save()
    }

    private func toggleHabitSelection(_ id: UUID) {
        if selectedHabitIDsForDeletion.contains(id) {
            selectedHabitIDsForDeletion.remove(id)
        } else {
            selectedHabitIDsForDeletion.insert(id)
        }
    }

    private func deleteSelectedHabits() {
        guard !selectedHabitIDsForDeletion.isEmpty else { return }
        let now = Date()
        let targets = allItems.filter { selectedHabitIDsForDeletion.contains($0.id) && !$0.isArchived && $0.type == .habit }
        for item in targets {
            item.isArchived = true
            item.archivedAt = now
            item.updatedAt = now
        }
        selectedHabitIDsForDeletion.removeAll()
        habitEditMode = .inactive
        try? modelContext.save()
    }
    
    private func startEditing(_ item: PlanItem) {
        if item.type == .note {
            editingNote = item
        } else {
            editingItem = item
        }
    }
    
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
    
    private func cleanupLegacyAnytimeDefaults() {
        let defaultTitles: Set<String> = ["Study", "Working"]
        let legacyDefaults = allItems.filter {
            !$0.isArchived &&
            $0.type == .task &&
            $0.anytime &&
            defaultTitles.contains($0.title)
        }

        guard !legacyDefaults.isEmpty else { return }
        for item in legacyDefaults {
            item.isArchived = true
        }
        try? modelContext.save()
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func habitDisplayOrder(lhs: PlanItem, rhs: PlanItem) -> Bool {
        switch (lhs.habitSortOrder, rhs.habitSortOrder) {
        case let (l?, r?):
            if l != r { return l < r }
            return lhs.createdAt < rhs.createdAt
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func normalizeHabitSortOrderIfNeeded() {
        let activeHabits = allItems
            .filter { !$0.isArchived && $0.type == .habit }
            .sorted(by: habitDisplayOrder(lhs:rhs:))

        guard !activeHabits.isEmpty else { return }

        var needsNormalization = false
        for (index, habit) in activeHabits.enumerated() {
            if habit.habitSortOrder != index {
                needsNormalization = true
                break
            }
        }

        guard needsNormalization else { return }

        for (index, habit) in activeHabits.enumerated() {
            habit.habitSortOrder = index
        }
        try? modelContext.save()
    }

    private func moveHabits(from source: IndexSet, to destination: Int, visibleHabits: [PlanItem]) {
        var reorderedVisible = visibleHabits
        reorderedVisible.move(fromOffsets: source, toOffset: destination)

        let visibleIds = Set(reorderedVisible.map(\.id))
        let trailingHabits = allItems
            .filter { !$0.isArchived && $0.type == .habit && !visibleIds.contains($0.id) }
            .sorted(by: habitDisplayOrder(lhs:rhs:))

        let finalOrderedHabits = reorderedVisible + trailingHabits
        for (index, item) in finalOrderedHabits.enumerated() {
            item.habitSortOrder = index
            item.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private var currentMoodSegment: MoodSegment {
        MoodSegment.current(for: Date())
    }

    private var selectedMoodForCurrentSegment: MoodType? {
        let dict = decodeMoodRecords()
        let key = moodRecordKey(for: Date(), segment: currentMoodSegment)
        guard let raw = dict[key] else { return nil }
        return MoodType(rawValue: raw)
    }

    private var shouldShowMoodBanner: Bool {
        guard viewModel.isListView || !allItems.isEmpty else { return false }
        if selectedMoodForCurrentSegment != nil { return false }
        let dismissed = decodeDismissedBanners()
        let key = moodRecordKey(for: Date(), segment: currentMoodSegment)
        return dismissed[key] != true
    }

    private var shouldShowUsageMotivationBanner: Bool {
        let hasHabits = allItems.contains { !$0.isArchived && $0.type == .habit }
        guard hasHabits else { return false }
        return usageBannerDismissedDay != usageDateKey(for: Date())
    }

    private func dismissMoodBannerForCurrentSegment() {
        var dismissed = decodeDismissedBanners()
        dismissed[moodRecordKey(for: Date(), segment: currentMoodSegment)] = true
        moodDismissedData = encodeStringBoolMap(dismissed)
    }

    private func dismissUsageBannerForToday() {
        usageBannerDismissedDay = usageDateKey(for: Date())
    }

    private func setMood(_ mood: MoodType, for segment: MoodSegment, on date: Date) {
        let key = moodRecordKey(for: date, segment: segment)

        var moods = decodeMoodRecords()
        moods[key] = mood.rawValue
        moodRecordsData = encodeStringMap(moods)

        var dismissed = decodeDismissedBanners()
        dismissed[key] = false
        moodDismissedData = encodeStringBoolMap(dismissed)
    }

    private func moodRecordKey(for date: Date, segment: MoodSegment) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))|\(segment.rawValue)"
    }

    private func decodeMoodRecords() -> [String: String] {
        guard let data = moodRecordsData.data(using: .utf8),
              let decoded = (try? JSONDecoder().decode([String: String].self, from: data)) else {
            return [:]
        }
        return decoded
    }

    private var usageDayCount: Int {
        decodeUsageDays().count
    }

    private var usageStreakDays: Int {
        let usage = decodeUsageDays()
        let calendar = Calendar.current
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<3650 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let key = usageDateKey(for: day)
            if usage[key] == true {
                streak += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }

    private func registerUsageForToday() {
        let key = usageDateKey(for: Date())
        var usage = decodeUsageDays()
        if usage[key] != true {
            usage[key] = true
            usageDaysData = encodeStringBoolMap(usage)
        }
    }

    private func decodeUsageDays() -> [String: Bool] {
        guard let data = usageDaysData.data(using: .utf8),
              let decoded = (try? JSONDecoder().decode([String: Bool].self, from: data)) else {
            return [:]
        }
        return decoded
    }

    private func decodeDismissedBanners() -> [String: Bool] {
        guard let data = moodDismissedData.data(using: .utf8),
              let decoded = (try? JSONDecoder().decode([String: Bool].self, from: data)) else {
            return [:]
        }
        return decoded
    }

    private func encodeStringMap(_ value: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func encodeStringBoolMap(_ value: [String: Bool]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func decodeMoodNotes() -> [String: String] {
        guard let data = moodNotesData.data(using: .utf8),
              let decoded = (try? JSONDecoder().decode([String: String].self, from: data)) else {
            return [:]
        }
        return decoded
    }

    private func hasMoodNoteOnDate(_ date: Date) -> Bool {
        let dayKey = moodDateKey(for: date)
        let moods = decodeMoodRecords()
        let contexts = decodeMoodNotes()
        if moods.keys.contains(where: { $0.hasPrefix(dayKey + "|") }) {
            return true
        }
        if contexts.keys.contains(where: { $0.hasPrefix(dayKey + "|") }) {
            return true
        }
        return false
    }

    private func moodDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func usageDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func timelineSectionHeader(title: String, count: Int, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PlanPalette.accent.opacity(0.9))
            Text("\(title) (\(count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PlanPalette.textSecondary)
            Spacer()
        }
        .textCase(nil)
        .padding(.horizontal, 16)
    }
}

struct PlanItemTimelineRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Bindable var item: PlanItem
    let timeString: String
    let selectedDate: Date
    let isCompleted: Bool
    let onToggle: () -> Void
    var onPlay: (() -> Void)? = nil
    var onQuickAdd: ((Double, CGPoint) -> Void)? = nil
    var onAdjust: ((Double) -> Void)? = nil
    
    @State private var quickAddScale: CGFloat = 1.0
    @State private var isDragging: Bool = false
    @State private var dragPreviewValue: Double?
    @State private var dragStartValue: Double?
    @State private var rowWidth: CGFloat = 320
    @State private var rowHeight: CGFloat = 80
    @State private var lastHapticStep: Int = -1
    @State private var dragIntent: DragIntent?
    private let habitRowScale: CGFloat = 0.9

    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time Column (only reserve space when there is a scheduled time)
            if showsTimeColumn {
                Text(timeString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.top, 14)
            }
            
            // Content Card
            if item.type == .note {
                noteItemContent
            } else if item.type == .habit {
                habitItemContent
            } else {
                taskItemContent
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Note Item
    
    @ViewBuilder
    private var noteItemContent: some View {
        HStack(spacing: 12) {
            ZStack {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PlanPalette.accent)
                        .font(.system(size: 14))
                } else {
                    if item.iconName.allSatisfy({ !$0.isASCII }) {
                        Text(item.iconName)
                            .font(.system(size: 14))
                    } else if item.iconName != "circle" {
                        Image(systemName: item.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(noteTintColor)
                    } else {
                        Circle().stroke(noteTintColor, lineWidth: 1.5).frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                    .strikethrough(isCompleted)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .planGlassPanel(cornerRadius: 12, fillOpacity: 0.12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onToggle)
    }
    
    // MARK: - Habit Item (with slide-to-update + plus button)
    
    @ViewBuilder
    private var habitItemContent: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isLightMode ? Color.white.opacity(0.98) : Color(red: 0.04, green: 0.08, blue: 0.12).opacity(0.92),
                            isLightMode ? Color(red: 0.97, green: 0.97, blue: 0.97).opacity(0.98) : Color(red: 0.06, green: 0.11, blue: 0.17).opacity(0.86),
                            isLightMode ? Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.98) : Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Left tint strip
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                habitTintColor.opacity(isLightMode ? 0.24 : 0.38),
                                habitTintColor.opacity(isLightMode ? 0.12 : 0.18),
                                isLightMode ? Color.white.opacity(0.01) : Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86 * habitRowScale)
                    .padding(.leading, 6)
                    .padding(.vertical, 6 * habitRowScale)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Progress fill
            habitProgressBackground
            
            // Content
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    if isHabitSFIcon {
                        Image(systemName: item.iconName)
                            .font(.system(size: 22.8 * habitRowScale, weight: .bold))
                            .foregroundColor(habitTintColor)
                            .frame(width: 50.4 * habitRowScale, height: 50.4 * habitRowScale)
                            .background(habitTintColor.opacity(0.14))
                            .clipShape(Circle())
                    } else {
                        Text(item.iconName)
                            .font(.system(size: 28.8 * habitRowScale))
                            .frame(width: 50.4 * habitRowScale, height: 50.4 * habitRowScale)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isLightMode ? Colors.textPrimary : PlanPalette.textPrimary)
                        .strikethrough(isCompleted)
                    
                    if let goalText = habitGoalText {
                        Text(goalText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isLightMode ? Colors.textSecondary : PlanPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                if !isCompleted {
                    GeometryReader { geo in
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(habitTintColor)
                            .scaleEffect(quickAddScale)
                            .onTapGesture {
                                let frame = geo.frame(in: .global)
                                let center = CGPoint(x: frame.midX, y: frame.midY)
                                onQuickAdd?(1, center)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    quickAddScale = 1.2
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    quickAddScale = 1.0
                                }
                            }
                    }
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                }
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24 * habitRowScale))
                        .foregroundColor(PlanPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12 * habitRowScale)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isCompleted
                    ? PlanPalette.accent.opacity(0.32)
                    : (isDragging ? habitTintColor.opacity(0.5) : (isLightMode ? Colors.cardStroke : Color.white.opacity(0.20))),
                    lineWidth: isDragging ? 2 : 1
                )
        )
        .shadow(
            color: isCompleted
                ? PlanPalette.accent.opacity(0.20)
                : (isDragging ? habitTintColor.opacity(0.3) : (isLightMode ? Color.black.opacity(0.08) : Color.black.opacity(0.16))),
            radius: isDragging ? 15 : 10,
            x: 0,
            y: isDragging ? 6 : 4
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: PlanItemRowSizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(PlanItemRowSizePreferenceKey.self) { size in
            rowWidth = max(1, size.width)
            rowHeight = max(1, size.height)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            dragAdjustGesture,
            including: supportsInlineDragAdjust ? .gesture : .none
        )
    }
    
    private var dragAdjustGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                if dragIntent == nil {
                    guard horizontal > (vertical * 1.8) else { return }
                    dragIntent = .horizontal
                    isDragging = true
                    dragStartValue = item.currentValue(on: selectedDate)
                    let startRatio = item.goalValue > 0 ? max(0, min(1, (dragStartValue ?? 0) / item.goalValue)) : 0
                    lastHapticStep = Int((startRatio * 20).rounded(.down))
                }

                guard dragIntent == .horizontal, isDragging else { return }

                let startValue = dragStartValue ?? item.currentValue(on: selectedDate)
                let effectiveWidth = max(rowWidth - 56, 220)
                let deltaRatio = Double(value.translation.width / effectiveWidth)
                let rawValue = startValue + (deltaRatio * item.goalValue)
                let nextValue = max(0, min(item.goalValue, rawValue))
                dragPreviewValue = nextValue

                let progressRatio = item.goalValue > 0 ? max(0, min(1, nextValue / item.goalValue)) : 0
                let newStep = Int((progressRatio * 20).rounded(.down))
                if newStep != lastHapticStep {
                    UISelectionFeedbackGenerator().selectionChanged()
                    lastHapticStep = newStep
                }
            }
            .onEnded { _ in
                if dragIntent == .horizontal {
                    commitDraggedAdjustment()
                } else {
                    isDragging = false
                    dragPreviewValue = nil
                    dragStartValue = nil
                    lastHapticStep = -1
                }
                dragIntent = nil
            }
    }
    
    private func commitDraggedAdjustment() {
        defer {
            isDragging = false
            dragPreviewValue = nil
            dragStartValue = nil
            lastHapticStep = -1
        }
        
        guard isDragging else { return }
        
        let current = item.currentValue(on: selectedDate)
        let rawTarget = dragPreviewValue ?? current
        let forceGoalCompletion = item.goalValue > 0 && (rawTarget / item.goalValue) >= 0.995
        let target = snapDraggedValue(rawTarget, forceGoalCompletion: forceGoalCompletion)
        let delta = target - current
        guard abs(delta) > 0.0001 else { return }
        onAdjust?(delta)
    }
    
    private func snapDraggedValue(_ value: Double, forceGoalCompletion: Bool = false) -> Double {
        let unit = item.goalUnit.lowercased()
        let step: Double
        
        if unit == "ml" {
            step = 10
        } else if unit == "oz" {
            step = 0.5
        } else if unit.contains("cup") {
            step = 0.1
        } else if unit.contains("step") {
            step = 50
        } else if unit == "m" || unit.contains("meter") {
            step = 10
        } else if unit == "km" || unit.contains("kilometer") {
            step = 0.1
        } else if unit.contains("min") {
            step = 1
        } else if unit.contains("hr") || unit.contains("hour") {
            step = 0.05
        } else {
            step = 1
        }

        if forceGoalCompletion {
            return item.goalValue
        }

        let clamped = max(0, min(item.goalValue, value))
        let snapped = floor(clamped / step) * step
        return max(0, min(item.goalValue, snapped))
    }
    
    @ViewBuilder
    private var habitProgressBackground: some View {
        GeometryReader { geo in
            let p = habitDisplayedProgress
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (isWaterHabit ? Color.blue : habitTintColor).opacity(isDragging ? 0.35 : 0.24),
                            (isWaterHabit ? Color.cyan : habitTintColor).opacity(isDragging ? 0.20 : 0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, geo.size.width * p))
                .animation(isDragging ? .none : .spring(), value: p)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    private var supportsInlineDragAdjust: Bool {
        item.type == .habit && !isCompleted
    }
    
    private var isHabitSFIcon: Bool {
        item.iconName.allSatisfy { $0.isASCII }
    }
    
    private var isWaterHabit: Bool {
        item.title.lowercased().contains("water") || item.iconName.contains("drop")
    }
    
    private var habitProgress: Double {
        item.progressFraction(on: selectedDate)
    }
    
    private var habitDisplayedProgress: Double {
        guard item.goalValue > 0 else { return 0 }
        if isDragging, let dragPreviewValue {
            return max(0, min(1, dragPreviewValue / item.goalValue))
        }
        return habitProgress
    }
    
    private var habitGoalText: String? {
        let current = (isDragging ? dragPreviewValue : nil) ?? item.currentValue(on: selectedDate)
        let total = item.goalValue
        let unit = item.goalUnit
        let currentStr = current.formatted(.number.precision(.fractionLength(0...2)))
        let totalStr = total.formatted(.number.precision(.fractionLength(0...2)))
        return "\(currentStr)/\(totalStr)\(unit)"
    }
    
    private var habitTintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "gray": return .gray
        default: return .blue
        }
    }
    
    // MARK: - Task Item
    
    @ViewBuilder
    private var taskItemContent: some View {
        HStack(spacing: 12) {
            // Checkbox Button
            Button(action: onToggle) {
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(taskTintColor)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        let isSF = item.iconName.allSatisfy { $0.isASCII }
                        
                        if isSF {
                            Circle()
                                .stroke(taskTintColor, lineWidth: 2)
                                .frame(width: 18, height: 18)
                            
                            if item.iconName == "circle" {
                                Circle().fill(taskTintColor).frame(width: 6, height: 6)
                            } else {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 9))
                                    .foregroundColor(taskTintColor)
                            }
                        } else {
                            Text(item.iconName)
                                .font(.system(size: 18))
                        }
                    }
                }
                .contentShape(Rectangle())
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                    .strikethrough(isCompleted)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            Spacer()
            
            if let duration = item.defaultDurationSeconds, duration > 0, !isCompleted {
                Button(action: { onPlay?() }) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .planGlassPanel(cornerRadius: 12, fillOpacity: 0.12)
    }
    
    private var showsTimeColumn: Bool {
        !timeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var noteTintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray": return .gray
        default: return .blue
        }
    }
    
    var taskTintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray": return .gray
        default: return .blue
        }
    }
}



struct PlanHeaderView: View {
    var body: some View {
        HStack {

            
            Spacer()
            
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Penalty Off")
                        .font(.caption)
                        .foregroundColor(PlanPalette.textPrimary)
                    Image(systemName: "shield.slash.fill")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .planGlassPanel(cornerRadius: 16, fillOpacity: 0.12)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("1") 
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(PlanPalette.textPrimary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .planGlassPanel(cornerRadius: 16, fillOpacity: 0.12)
            }
        }
        .padding()
    }
}

enum MoodSegment: String, CaseIterable {
    case morning
    case afternoon
    case night

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .night: return "Night"
        }
    }

    static func current(for date: Date) -> MoodSegment {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<18: return .afternoon
        default: return .night
        }
    }
}

enum MoodType: String, CaseIterable, Identifiable {
    case bad
    case notGreat
    case okay
    case good
    case great

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .bad: return "😡"
        case .notGreat: return "☹️"
        case .okay: return "😐"
        case .good: return "😊"
        case .great: return "😍"
        }
    }

    var title: String {
        switch self {
        case .bad: return "Terrible"
        case .notGreat: return "Bad"
        case .okay: return "Okay"
        case .good: return "Good"
        case .great: return "Excellent"
        }
    }

    var tint: Color {
        switch self {
        case .bad: return Color(red: 0.95, green: 0.42, blue: 0.45)
        case .notGreat: return Color(red: 0.62, green: 0.59, blue: 0.90)
        case .okay: return Color(red: 0.54, green: 0.73, blue: 0.89)
        case .good: return Color(red: 0.67, green: 0.80, blue: 0.45)
        case .great: return Color(red: 0.94, green: 0.84, blue: 0.28)
        }
    }
}

struct MoodPromptBanner: View {
    let segment: MoodSegment
    let selectedMood: MoodType?
    let onTrackTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, how is your \(segment.title.lowercased())?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text("Track your mood in one tap.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }

                HStack(spacing: 6) {
                    ForEach(MoodType.allCases) { mood in
                        VStack(spacing: 2) {
                            Text(mood.emoji)
                                .font(.system(size: 19))
                                .frame(width: 32, height: 32)
                                .background(mood.tint.opacity(0.28))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(selectedMood == mood ? Colors.textPrimary.opacity(0.45) : Color.clear, lineWidth: 1.5)
                                )
                            Text(mood.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    Spacer()
                }

                Button(action: onTrackTap) {
                    Text("Track mood")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Colors.cardSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(11)
            .background(
                Colors.bgPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .shadow(color: Colors.shadow.opacity(0.14), radius: 12, x: 0, y: 6)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(Colors.cardSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}

private struct HabitUsageMotivationBanner: View {
    let usageDayCount: Int
    let streakDays: Int
    let onClose: () -> Void

    @State private var selectedTone: MotivationTone = .steady

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundColor(Colors.textPrimary)
                    Text(selectedTone.subtitle(forDay: usageDayCount))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("🪻")
                        .font(.system(size: 26))
                    Text("\(max(streakDays, 1))")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("DAY STREAK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                }
            }

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index < min(streakDays, 5) ? Color(red: 0.67, green: 0.58, blue: 0.96) : Color(red: 0.75, green: 0.72, blue: 0.92))
                            .frame(width: 40, height: 40)
                        if index < min(streakDays, 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black.opacity(0.85))
                        }
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                toneChip(.steady)
                toneChip(.momentum)
                toneChip(.discipline)
                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.24))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .planGlassPanel(cornerRadius: 26, fillOpacity: 0.14)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var titleText: String {
        switch usageDayCount {
        case 0, 1:
            return "Day 1 of planning"
        case 2:
            return "Another day of planning"
        case 3:
            return "3 days in a row"
        default:
            return "\(usageDayCount) days of planning"
        }
    }

    @ViewBuilder
    private func toneChip(_ tone: MotivationTone) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTone = tone
            }
        } label: {
            Text(tone.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selectedTone == tone ? Colors.textPrimary : Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selectedTone == tone ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(selectedTone == tone ? 0.26 : 0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum MotivationTone: String, CaseIterable {
    case steady
    case momentum
    case discipline

    var title: String {
        switch self {
        case .steady: return "Steady"
        case .momentum: return "Momentum"
        case .discipline: return "Discipline"
        }
    }

    func subtitle(forDay day: Int) -> String {
        switch self {
        case .steady:
            return day <= 2 ? "Small steps, steady progress" : "Consistency compounds every day"
        case .momentum:
            return day <= 2 ? "You started strong. Keep the pace." : "You are building real momentum"
        case .discipline:
            return day <= 2 ? "Show up today, results follow." : "Discipline beats motivation."
        }
    }
}

struct MoodPickerBottomSheet: View {
    let segment: MoodSegment
    let selectedMood: MoodType?
    let selectedDate: Date
    @Binding var moodRecordsData: String
    @Binding var moodNotesData: String // date|segment -> context
    @Binding var moodFactorsData: String // date|segment -> [String]
    let onOpenStats: () -> Void
    let onSelect: (MoodType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftMood: MoodType? = nil
    @State private var didInitialize = false
    @State private var moodFrames: [MoodType: CGRect] = [:]
    @State private var dropMood: MoodType?
    @State private var dropPosition: CGPoint = .zero
    @State private var dropOpacity: Double = 0
    @State private var dropScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("How are you feeling right now?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.09))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(segment.title) mood")
                        .font(.subheadline)
                        .foregroundColor(Colors.textSecondary)

                    HStack(spacing: 10) {
                        ForEach(MoodType.allCases) { mood in
                            MoodChoiceButton(mood: mood, isSelected: draftMood == mood) {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.68)) {
                                    draftMood = mood
                                }
                                handleMoodTap(mood, containerSize: proxy.size)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: MoodButtonFramePreferenceKey.self,
                                            value: [mood: geo.frame(in: .named("MoodSheetSpace"))]
                                        )
                                }
                            )
                        }
                    }

                    HStack {
                        Spacer()
                        moodStatsButton(icon: "chart.bar.xaxis")
                    }
                    .padding(.horizontal, 8)
                }
            }
            .coordinateSpace(name: "MoodSheetSpace")
            .onPreferenceChange(MoodButtonFramePreferenceKey.self) { frames in
                moodFrames = frames
            }
            .overlay {
                if let mood = dropMood {
                    VStack(spacing: 6) {
                        Text(mood.emoji)
                            .font(.system(size: 36))
                        Text(mood.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .position(dropPosition)
                    .scaleEffect(dropScale)
                    .opacity(dropOpacity)
                    .allowsHitTesting(false)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PlanGlassBackground())
        .onAppear {
            guard !didInitialize else { return }
            loadLog(for: selectedDate)
            didInitialize = true
        }
    }

    @ViewBuilder
    private func moodStatsButton(icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            onOpenStats()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.16))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func loadLog(for date: Date) {
        // Do not preselect any mood by default; user must explicitly tap.
        draftMood = nil
    }

    private func handleMoodTap(_ mood: MoodType, containerSize: CGSize) {
        let startFrame = moodFrames[mood]
        let startPoint = CGPoint(
            x: startFrame?.midX ?? (containerSize.width * 0.5),
            y: startFrame?.midY ?? 180
        )
        let endPoint = CGPoint(
            x: containerSize.width * 0.5,
            y: max(220, containerSize.height - 96)
        )

        dropMood = mood
        dropPosition = startPoint
        dropScale = 1.0
        dropOpacity = 1.0

        withAnimation(.easeIn(duration: 0.22)) {
            dropPosition = endPoint
            dropScale = 0.88
        }
        withAnimation(.easeOut(duration: 0.12).delay(0.10)) {
            dropOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dropMood = nil
        }

        logMood(mood)
    }

    private func logMood(_ mood: MoodType) {
        let key = moodRecordKey(for: selectedDate, segment: segment)

        var moods = decodeStringMap(moodRecordsData)
        moods[key] = mood.rawValue
        moodRecordsData = encodeStringMap(moods)

        onSelect(mood)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            dismiss()
        }
    }

    private func decodeStringMap(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func encodeStringMap(_ value: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func moodRecordKey(for date: Date, segment: MoodSegment) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))|\(segment.rawValue)"
    }

    private func decodeStringArrayMap(_ value: String) -> [String: [String]] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func encodeStringArrayMap(_ value: [String: [String]]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

}

private struct MoodButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [MoodType: CGRect] = [:]

    static func reduce(value: inout [MoodType: CGRect], nextValue: () -> [MoodType: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MoodStatsPanel: View {
    let records: [String: String]
    let referenceDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                moodStatCard(title: "Success", value: "\(successDays) Days", accent: Color(red: 0.32, green: 0.74, blue: 0.35))
                moodStatCard(title: "Failed", value: "\(failedDays) Days", accent: Color(red: 0.92, green: 0.30, blue: 0.26))
                moodStatCard(title: "Skipped", value: "\(skippedDays) Days", accent: Color.white.opacity(0.55))
                moodStatCard(title: "Total", value: "\(totalCheckIns) Entries", accent: Color(red: 0.98, green: 0.58, blue: 0.24))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Consistency")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text("\(Int((consistency * 100).rounded()))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                ProgressView(value: consistency)
                    .tint(Color(red: 0.98, green: 0.58, blue: 0.24))
                    .scaleEffect(x: 1, y: 1.15, anchor: .center)
                Text("Current streak: \(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            MoodHeatMap(records: records, endDate: referenceDate)
        }
    }

    private func moodStatCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
    }

    private var rangeStart: Date {
        calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: referenceDate)) ?? calendar.startOfDay(for: referenceDate)
    }

    private var dailyScores: [(date: Date, score: Double?, entries: Int)] {
        var result: [(date: Date, score: Double?, entries: Int)] = []
        let valueByDay = dayScoreMap()
        for offset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: rangeStart) else { continue }
            let key = calendar.startOfDay(for: date)
            let tuple = valueByDay[key]
            result.append((date: key, score: tuple?.score, entries: tuple?.entries ?? 0))
        }
        return result
    }

    private func dayScoreMap() -> [Date: (score: Double, entries: Int)] {
        var bucket: [Date: [Double]] = [:]
        for (key, rawMood) in records {
            let parts = key.split(separator: "|")
            guard let datePart = parts.first else { continue }
            guard let date = parseDate(String(datePart)),
                  let mood = MoodType(rawValue: rawMood) else { continue }
            let day = calendar.startOfDay(for: date)
            bucket[day, default: []].append(moodScore(mood))
        }

        var map: [Date: (score: Double, entries: Int)] = [:]
        for (day, values) in bucket {
            guard !values.isEmpty else { continue }
            let avg = values.reduce(0, +) / Double(values.count)
            map[day] = (avg, values.count)
        }
        return map
    }

    private var successDays: Int {
        dailyScores.filter { ($0.score ?? -1) >= 0.67 }.count
    }

    private var failedDays: Int {
        dailyScores.filter { score in
            guard let s = score.score else { return false }
            return s < 0.34
        }.count
    }

    private var skippedDays: Int {
        dailyScores.filter { $0.score == nil }.count
    }

    private var totalCheckIns: Int {
        dailyScores.reduce(0) { $0 + $1.entries }
    }

    private var consistency: Double {
        let active = successDays + failedDays
        guard active > 0 else { return 0 }
        return Double(successDays) / Double(active)
    }

    private var currentStreak: Int {
        let map = dayScoreMap()
        var streak = 0
        let today = calendar.startOfDay(for: referenceDate)
        for offset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            guard let score = map[day]?.score else {
                if offset == 0 { continue }
                break
            }
            if score >= 0.5 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func moodScore(_ mood: MoodType) -> Double {
        switch mood {
        case .bad: return 0.1
        case .notGreat: return 0.3
        case .okay: return 0.5
        case .good: return 0.75
        case .great: return 1.0
        }
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct MoodStatisticsFullScreenView: View {
    let recordsData: String
    @Binding var notesData: String
    let referenceDate: Date
    @State private var selectedTab: MoodStatsTab = .statistics

    var body: some View {
        ZStack {
            PlanGlassBackground()

            VStack(spacing: 0) {
                HStack {
                    Text("Mood Statistics")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 10)

                HStack(spacing: 10) {
                    tabButton(title: "Statistics", icon: "chart.bar.xaxis", tab: .statistics)
                    tabButton(title: "Notes", icon: "note.text", tab: .notes)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    if selectedTab == .statistics {
                        MoodStatsPanel(records: decodeStringMap(recordsData), referenceDate: referenceDate)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    } else {
                        MoodNotesPanel(entries: moodEntries, notesData: $notesData)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tabButton(title: String, icon: String, tab: MoodStatsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab ? Colors.textPrimary : Colors.textSecondary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedTab == tab ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedTab == tab ? Color.white.opacity(0.28) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var moodEntries: [MoodLogEntry] {
        let records = decodeStringMap(recordsData)
        return records.compactMap { key, rawMood in
            let parts = key.split(separator: "|")
            guard parts.count == 2,
                  let date = parseDate(String(parts[0])),
                  let mood = MoodType(rawValue: rawMood),
                  let segment = MoodSegment(rawValue: String(parts[1])) else {
                return nil
            }
            return MoodLogEntry(key: key, date: date, segment: segment, mood: mood)
        }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.segment.sortOrder < rhs.segment.sortOrder
        }
    }

    private func decodeStringMap(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private enum MoodStatsTab {
    case statistics
    case notes
}

private struct MoodLogEntry: Identifiable {
    let key: String
    let date: Date
    let segment: MoodSegment
    let mood: MoodType

    var id: String { key }
}

private struct MoodNotesPanel: View {
    let entries: [MoodLogEntry]
    @Binding var notesData: String
    @State private var selectedEntryKey: String? = nil
    @State private var noteDraft: String = ""
    @State private var saveStatus: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entries.isEmpty {
                Text("No mood logs yet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("Select a mood log and add a note.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entries.prefix(40)) { entry in
                            entryChip(for: entry)
                        }
                    }
                }

                TextEditor(text: $noteDraft)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button("Save Note") {
                        saveCurrentNote()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.98, green: 0.58, blue: 0.24), Color(red: 0.93, green: 0.30, blue: 0.26)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .buttonStyle(.plain)

                    if !saveStatus.isEmpty {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            if selectedEntryKey == nil, let first = entries.first {
                selectEntry(first.key)
            }
        }
        .onChange(of: entries.map(\.key)) { _, _ in
            guard let selectedEntryKey else {
                if let first = entries.first {
                    selectEntry(first.key)
                }
                return
            }
            if !entries.contains(where: { $0.key == selectedEntryKey }), let first = entries.first {
                selectEntry(first.key)
            }
        }
    }

    @ViewBuilder
    private func entryChip(for entry: MoodLogEntry) -> some View {
        let selected = selectedEntryKey == entry.key
        Button {
            selectEntry(entry.key)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood.emoji + " " + entry.mood.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(selected ? Colors.textPrimary : Colors.textSecondary)
                Text(formattedDate(entry.date) + " • " + entry.segment.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.28) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectEntry(_ key: String) {
        selectedEntryKey = key
        noteDraft = decodeNotesMap(notesData)[key] ?? ""
        saveStatus = ""
    }

    private func saveCurrentNote() {
        guard let key = selectedEntryKey else { return }
        var notes = decodeNotesMap(notesData)
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: key)
        } else {
            notes[key] = trimmed
        }
        notesData = encodeNotesMap(notes)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        saveStatus = "Note saved"
    }

    private func decodeNotesMap(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func encodeNotesMap(_ value: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private extension MoodSegment {
    var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 1
        case .night: return 2
        }
    }
}

private struct MoodHeatMap: View {
    let records: [String: String]
    let endDate: Date
    @State private var selectedDate: Date?

    private typealias CellData = (date: Date, score: Double, hasEntry: Bool)

    private let calendar = Calendar.current
    private let columns = 12
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleView
            gridCard
            selectionSummary
        }
        .onAppear {
            if selectedDate == nil {
                selectedDate = calendar.startOfDay(for: endDate)
            }
        }
    }

    private var titleView: some View {
        Text("Mood Heat Map")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Colors.textPrimary)
    }

    private var gridCard: some View {
        HStack(alignment: .top, spacing: 8) {
            weekdayColumn
            gridRows
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var weekdayColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption2)
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 12, height: 16, alignment: .leading)
            }
        }
    }

    private var gridRows: some View {
        VStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { row in
                gridRow(row)
            }
        }
    }

    private func gridRow(_ row: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<columns, id: \.self) { column in
                let cell = cellFor(row: row, column: column)
                heatMapCell(cell)
            }
        }
    }

    private func heatMapCell(_ cell: CellData) -> some View {
        let isSelected = isSelectedDate(cell.date)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(cellColor(score: cell.score, hasEntry: cell.hasEntry, date: cell.date))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
            )
            .overlay {
                if isSelected {
                    Text(cell.hasEntry ? "\(Int((cell.score * 100).rounded()))" : "0")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 20, height: 16)
            .contentShape(Rectangle())
            .onTapGesture {
                guard cell.date <= calendar.startOfDay(for: endDate) else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedDate = cell.date
                }
            }
    }

    private var selectionSummary: some View {
        HStack(spacing: 8) {
            if let selectedDate {
                let data = moodDataByDay[selectedDate]
                let score = data?.score ?? 0
                let entries = data?.entries ?? 0

                Text(selectedDate.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundColor(Colors.textPrimary)

                Spacer()

                Text(entries > 0 ? "Score \(Int((score * 100).rounded()))%" : "No check-in")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            } else {
                Text("Tap a rectangle to view mood value")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 2)
    }

    private func isSelectedDate(_ date: Date) -> Bool {
        guard let selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var moodDataByDay: [Date: (score: Double, entries: Int)] {
        var bucket: [Date: [Double]] = [:]
        for (key, rawMood) in records {
            let parts = key.split(separator: "|")
            guard let datePart = parts.first else { continue }
            guard let date = parseDate(String(datePart)),
                  let mood = MoodType(rawValue: rawMood) else { continue }
            let day = calendar.startOfDay(for: date)
            bucket[day, default: []].append(score(for: mood))
        }

        var map: [Date: (score: Double, entries: Int)] = [:]
        for (day, values) in bucket where !values.isEmpty {
            map[day] = (
                score: values.reduce(0, +) / Double(values.count),
                entries: values.count
            )
        }
        return map
    }

    private var startDate: Date {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: -((columns - 1) * 7), to: weekStart) ?? weekStart
    }

    private func cellFor(row: Int, column: Int) -> CellData {
        let dayIndex = (column * 7) + row
        let date = calendar.date(byAdding: .day, value: dayIndex, to: startDate) ?? startDate
        let key = calendar.startOfDay(for: date)
        let value = moodDataByDay[key]?.score ?? 0
        return (key, value, moodDataByDay[key] != nil)
    }

    private func cellColor(score: Double, hasEntry: Bool, date: Date) -> Color {
        if date > calendar.startOfDay(for: endDate) {
            return Color.clear
        }
        guard hasEntry else {
            return Color.white.opacity(0.08)
        }

        // Yellow / orange / red shades as requested
        let shade: Color
        switch score {
        case ..<0.34:
            shade = Color(red: 0.93, green: 0.30, blue: 0.26) // red
        case ..<0.67:
            shade = Color(red: 0.98, green: 0.58, blue: 0.24) // orange
        default:
            shade = Color(red: 0.98, green: 0.82, blue: 0.32) // yellow
        }
        return shade.opacity(0.35 + (score * 0.50))
    }

    private func score(for mood: MoodType) -> Double {
        switch mood {
        case .bad: return 0.1
        case .notGreat: return 0.3
        case .okay: return 0.5
        case .good: return 0.75
        case .great: return 1.0
        }
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct MoodQuickLogPanel: View {
    let canLog: Bool
    let saveStatus: String
    let onLog: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onLog) {
                Text("Log mood")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.98, green: 0.58, blue: 0.24), Color(red: 0.93, green: 0.30, blue: 0.26)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .disabled(!canLog)
            .opacity(canLog ? 1 : 0.45)
            .buttonStyle(.plain)

            if !saveStatus.isEmpty {
                Text(saveStatus)
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
        }
    }
}

private struct MoodChoiceButton: View {
    let mood: MoodType
    let isSelected: Bool
    let onConfirm: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.20, dampingFraction: 0.62)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                    isPressed = false
                }
            }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.72)) {
                onConfirm()
            }
        } label: {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 34))
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(isSelected ? Color(red: 0.40, green: 0.53, blue: 0.90) : Color.white.opacity(0.14))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white.opacity(0.68) : Color.clear, lineWidth: 1.5)
                    )
                    .scaleEffect(isPressed ? 0.92 : (isSelected ? 1.05 : 1.0))

                Text(mood.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? Color(red: 0.50, green: 0.64, blue: 0.98) : Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct CalendarHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Binding var selectedDate: Date
    @Binding var isListView: Bool
    @Binding var showCalendarCoachMark: Bool
    var moodEmoji: String? = nil
    var hasMoodNoteOnDate: ((Date) -> Bool)? = nil
    var onMoodTap: (() -> Void)? = nil
    
    private var calendar: Calendar { Calendar.current }
    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    var body: some View {

        VStack(spacing: 16) {
            // Unified Top Bar: Date Info + Actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(formatDateTitle)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        
                        if isToday {
                            Text("Today")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isLightMode ? Color.white.opacity(0.95) : Colors.cardSurface)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(formatDateSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                // Right Side: Badges + Toggle
                VStack(alignment: .trailing, spacing: 12) {
                    // Badges
                    HStack(spacing: 8) {
                        Button(action: { onMoodTap?() }) {
                            ZStack(alignment: .bottomTrailing) {
                                Text(moodEmoji ?? "🙂")
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(isLightMode ? Color.white.opacity(0.95) : Color.white.opacity(0.08))
                                    .clipShape(Circle())

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 0.86, green: 0.22, blue: 0.16))
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 2, y: 2)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .planGlassPanel(cornerRadius: 14, fillOpacity: 0.12)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // View Toggle
                    HStack(spacing: 0) {
                        Button(action: { withAnimation { isListView = true } }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14))
                                .foregroundColor(isListView ? Colors.textPrimary : Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(isListView ? (isLightMode ? Color.white.opacity(0.95) : Colors.cardSurface) : Color.clear)
                                .clipShape(Circle())
                        }
                        
                        Button(action: { withAnimation { isListView = false } }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(!isListView ? Colors.textPrimary : Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(!isListView ? (isLightMode ? Color.white.opacity(0.95) : Colors.cardSurface) : Color.clear)
                                .clipShape(Circle())
                        }
                    }
                    .padding(2)
                    .background(isLightMode ? Color.white.opacity(0.75) : Colors.cardSurface.opacity(0.3))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Week Row with Navigation
            HStack {
                Button(action: { shiftDate(-1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 24, height: 40)
                }
                
                WeekStripView(selectedDate: $selectedDate)
                    .environment(\.hasMoodNoteOnDate, hasMoodNoteOnDate)
                    .coachMark(
                        title: "Dates",
                        subtitle: "Tap a day to see schedule.",
                        isVisible: $showCalendarCoachMark,
                        alignment: .top,
                        pointDirection: .bottom,
                        arrowAlignment: .center,
                        arrowOffsetX: 0,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -40,
                        color: .red
                    )
                
                Button(action: { shiftDate(1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 24, height: 40)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    
    private var isToday: Bool { calendar.isDateInToday(selectedDate) }
    
    private var formatDateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: selectedDate)
    }
    
    private var formatDateSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, yyyy"
        return f.string(from: selectedDate)
    }
    
    private func shiftDate(_ days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation {
                selectedDate = newDate
            }
        }
    }
}

struct WeekStripView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    @Environment(\.hasMoodNoteOnDate) private var hasMoodNoteOnDate
    
    var body: some View {
        // Show current week centered around selected date or fixed?
        // Let's show -3 to +3 days from selected
        HStack(spacing: 0) {
            ForEach(-3...3, id: \.self) { offset in
                if let day = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
                    let isSelected = offset == 0
                    WeekDayCell(
                        date: day,
                        isSelected: isSelected,
                        hasMoodNote: hasMoodNoteOnDate?(day) == true
                    ) {
                        withAnimation {
                            selectedDate = day
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct WeekDayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    let date: Date
    let isSelected: Bool
    let hasMoodNote: Bool
    let onTap: () -> Void
    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(dayName)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
            VStack(spacing: 3) {
                Text(dayNum)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? (isLightMode ? Colors.textPrimary : .white) : Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        isSelected
                            ? (isLightMode ? Color(red: 0.90, green: 0.90, blue: 0.90) : Color(red: 0.06, green: 0.45, blue: 0.62))
                            : Color.clear
                    )
                    .clipShape(Circle())

                Circle()
                    .fill(Color(red: 0.98, green: 0.58, blue: 0.24))
                    .frame(width: 5, height: 5)
                    .opacity(hasMoodNote ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .onTapGesture(perform: onTap)
    }
    
    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // Single letter day
        return f.string(from: date)
    }
    
    private var dayNum: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

private struct HasMoodNoteOnDateKey: EnvironmentKey {
    static let defaultValue: ((Date) -> Bool)? = nil
}

extension EnvironmentValues {
    var hasMoodNoteOnDate: ((Date) -> Bool)? {
        get { self[HasMoodNoteOnDateKey.self] }
        set { self[HasMoodNoteOnDateKey.self] = newValue }
    }
}

struct PlanBannerView: View {
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.white)
                Text("Take the first step – 10-min focus!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.white)
            }
            .padding()
            .background(LinearGradient(colors: [Color(hex: "7F7FD5"), Color(hex: "86A8E7")], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(12)
        }
        .padding()
    }
}

private struct PlanItemRowSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 1, height: 1)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// Updated PlanItemRow
struct PlanItemRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Bindable var item: PlanItem
    let selectedDate: Date
    let isCompleted: Bool
    let onToggle: () -> Void
    var onPlay: (() -> Void)? = nil
    var onQuickAdd: ((Double, CGPoint) -> Void)? = nil
    var onAdjust: ((Double) -> Void)? = nil
    
    @State private var quickAddScale: CGFloat = 1.0
    @State private var isDragging: Bool = false
    @State private var dragPreviewValue: Double?
    @State private var dragStartValue: Double?
    @State private var rowWidth: CGFloat = 320
    @State private var rowHeight: CGFloat = 80
    @State private var lastHapticStep: Int = -1
    @State private var dragIntent: DragIntent?
    private let habitRowScale: CGFloat = 0.9
    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isHabitItem
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                isLightMode ? Color.white.opacity(0.98) : Color(red: 0.04, green: 0.08, blue: 0.12).opacity(0.92),
                                isLightMode ? Color(red: 0.97, green: 0.97, blue: 0.97).opacity(0.98) : Color(red: 0.06, green: 0.11, blue: 0.17).opacity(0.86),
                                isLightMode ? Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.98) : Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                isLightMode ? Color.white.opacity(0.98) : Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.94),
                                isLightMode ? Color(red: 0.97, green: 0.97, blue: 0.97).opacity(0.98) : Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.88),
                                isLightMode ? Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.98) : Color(red: 0.04, green: 0.06, blue: 0.10).opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Horizontal "cover" style strip inspired by media cards while staying list-friendly.
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(isLightMode ? 0.24 : 0.38),
                                tintColor.opacity(isLightMode ? 0.12 : 0.18),
                                isLightMode ? Color.white.opacity(0.01) : Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isHabitItem ? (86 * habitRowScale) : 86)
                    .padding(.leading, 6)
                    .padding(.vertical, isHabitItem ? (6 * habitRowScale) : 6)
                
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Progress fill on top of base card
            progressBackground
            
            HStack(spacing: 12) {
                iconSection
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isLightMode ? Colors.textPrimary : PlanPalette.textPrimary)
                        .strikethrough(isCompleted)
                    
                    if let goalText = goalText {
                        Text(goalText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isLightMode ? Colors.textSecondary : PlanPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                if item.type == .habit && !isCompleted {
                    GeometryReader { geo in
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: isHabitItem ? (24 * habitRowScale) : 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(tintColor)
                            .scaleEffect(quickAddScale)
                            .onTapGesture {
                                let frame = geo.frame(in: .global)
                                let center = CGPoint(x: frame.midX, y: frame.midY)
                                onQuickAdd?(1, center)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    quickAddScale = 1.2
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    quickAddScale = 1.0
                                }
                            }
                    }
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                }
                
                if let duration = item.defaultDurationSeconds, duration > 0, !isCompleted {
                    Button(action: { onPlay?() }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: isHabitItem ? (24 * habitRowScale) : 24))
                            .foregroundColor(isLightMode ? Colors.textPrimary : Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: isHabitItem ? (24 * habitRowScale) : 24))
                        .foregroundColor(PlanPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isHabitItem ? (12 * habitRowScale) : 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isCompleted
                        ? PlanPalette.accent.opacity(0.32)
                        : (isDragging ? tintColor.opacity(0.5) : (isLightMode ? Colors.cardStroke : Color.white.opacity(0.20))),
                    lineWidth: isDragging ? 2 : 1
                )
        )
        .shadow(
            color: isCompleted
                ? PlanPalette.accent.opacity(0.20)
                : (isDragging ? tintColor.opacity(0.3) : (isLightMode ? Color.black.opacity(0.08) : Color.black.opacity(0.16))),
            radius: isDragging ? 15 : 10,
            x: 0,
            y: isDragging ? 6 : 4
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: PlanItemRowSizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(PlanItemRowSizePreferenceKey.self) { size in
            rowWidth = max(1, size.width)
            rowHeight = max(1, size.height)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            dragAdjustGesture,
            including: supportsInlineDragAdjust ? .gesture : .none
        )
    }

    private var dragAdjustGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                if dragIntent == nil {
                    // Drag only activates for clear horizontal swipes.
                    // Higher threshold keeps vertical List scroll responsive on habit rows.
                    guard horizontal > (vertical * 1.8) else { return }

                    dragIntent = .horizontal
                    isDragging = true
                    dragStartValue = item.currentValue(on: selectedDate)
                    let startRatio = item.goalValue > 0 ? max(0, min(1, (dragStartValue ?? 0) / item.goalValue)) : 0
                    lastHapticStep = Int((startRatio * 20).rounded(.down))
                }

                guard dragIntent == .horizontal, isDragging else { return }

                // Relative drag model: swipe right increases from current value, left decreases.
                // This avoids jumping to goal on tiny movement near the row's right side.
                let startValue = dragStartValue ?? item.currentValue(on: selectedDate)
                let effectiveWidth = max(rowWidth - 56, 220)
                let deltaRatio = Double(value.translation.width / effectiveWidth)
                let rawValue = startValue + (deltaRatio * item.goalValue)
                let nextValue = max(0, min(item.goalValue, rawValue))
                dragPreviewValue = nextValue

                let progressRatio = item.goalValue > 0 ? max(0, min(1, nextValue / item.goalValue)) : 0
                let newStep = Int((progressRatio * 20).rounded(.down))
                if newStep != lastHapticStep {
                    UISelectionFeedbackGenerator().selectionChanged()
                    lastHapticStep = newStep
                }
            }
            .onEnded { _ in
                if dragIntent == .horizontal {
                    commitDraggedAdjustment()
                } else {
                    isDragging = false
                    dragPreviewValue = nil
                    dragStartValue = nil
                    lastHapticStep = -1
                }
                dragIntent = nil
            }
    }
    
    private func commitDraggedAdjustment() {
        defer {
            isDragging = false
            dragPreviewValue = nil
            dragStartValue = nil
            lastHapticStep = -1
        }
        
        guard isDragging else { return }
        
        let current = item.currentValue(on: selectedDate)
        let rawTarget = dragPreviewValue ?? current
        let forceGoalCompletion = item.goalValue > 0 && (rawTarget / item.goalValue) >= 0.995
        let target = snapDraggedValue(rawTarget, forceGoalCompletion: forceGoalCompletion)
        let delta = target - current
        guard abs(delta) > 0.0001 else { return }
        onAdjust?(delta)
    }
    
    private func snapDraggedValue(_ value: Double, forceGoalCompletion: Bool = false) -> Double {
        let unit = item.goalUnit.lowercased()
        let step: Double
        
        if unit == "ml" {
            step = 10
        } else if unit == "oz" {
            step = 0.5
        } else if unit.contains("cup") {
            step = 0.1
        } else if unit.contains("step") {
            step = 50
        } else if unit == "m" || unit.contains("meter") {
            step = 10
        } else if unit == "km" || unit.contains("kilometer") {
            step = 0.1
        } else if unit.contains("min") {
            step = 1
        } else if unit.contains("hr") || unit.contains("hour") {
            step = 0.05
        } else {
            step = 1
        }

        if forceGoalCompletion {
            return item.goalValue
        }

        let clamped = max(0, min(item.goalValue, value))
        let snapped = floor(clamped / step) * step
        return max(0, min(item.goalValue, snapped))
    }
    
    @ViewBuilder
    private var progressBackground: some View {
        GeometryReader { geo in
            let p = displayedProgress
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (isWaterHabit ? Color.blue : tintColor).opacity(isDragging ? (isLightMode ? 0.24 : 0.35) : (isLightMode ? 0.16 : 0.24)),
                            (isWaterHabit ? Color.cyan : tintColor).opacity(isDragging ? (isLightMode ? 0.16 : 0.20) : (isLightMode ? 0.08 : 0.10))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, geo.size.width * p))
                .animation(isDragging ? .none : .spring(), value: p)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    private var iconSection: some View {
        Group {
            if item.type == .habit {
                iconContent
            } else {
                Button(action: onToggle) { iconContent }
                    .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        ZStack {
            if isSFIcon {
                Image(systemName: item.iconName)
                    .font(.system(size: iconFontSize, weight: .bold))
                    .foregroundColor(tintColor)
                    .frame(width: iconContainerSize, height: iconContainerSize)
                    .background(tintColor.opacity(isLightMode ? 0.22 : 0.14))
                    .clipShape(Circle())
            } else {
                Text(item.iconName)
                    .font(.system(size: emojiFontSize))
                    .frame(width: iconContainerSize, height: iconContainerSize)
            }
        }
    }

    private var isHabitItem: Bool { item.type == .habit }
    private var iconFontSize: CGFloat { isHabitItem ? (22.8 * habitRowScale) : 19.0 }        // +20% for habits, compacted by 10%
    private var emojiFontSize: CGFloat { isHabitItem ? (28.8 * habitRowScale) : 24.0 }       // +20% for habits, compacted by 10%
    private var iconContainerSize: CGFloat { isHabitItem ? (50.4 * habitRowScale) : 42.0 }   // +20% for habits, compacted by 10%
    
    private var isSFIcon: Bool {
        item.iconName.allSatisfy { $0.isASCII }
    }
    
    private var isWaterHabit: Bool {
        item.title.lowercased().contains("water") || item.iconName.contains("drop")
    }
    
    private var isMindfulHabit: Bool {
        let t = item.title.lowercased()
        return t.contains("meditation") || t.contains("yoga") || t.contains("breathe") || item.iconName.contains("body")
    }

    private var supportsInlineDragAdjust: Bool {
        item.type == .habit && !isCompleted
    }

    private func isInSliderInteractionZone(_ point: CGPoint) -> Bool {
        // Treat the central lane as the manual progress slider area.
        // This preserves vertical list scrolling when dragging near edges/icons.
        let minX: CGFloat = 28
        let maxX = max(minX + 40, rowWidth - 28)
        let minY: CGFloat = 2
        let maxY = max(minY + 24, rowHeight - 2)
        return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
    
    private var progress: Double {
        if item.type != .habit { return 0 }
        return item.progressFraction(on: selectedDate)
    }
    
    private var displayedProgress: Double {
        guard item.type == .habit else { return 0 }
        guard item.goalValue > 0 else { return 0 }
        if isDragging, let dragPreviewValue {
            return max(0, min(1, dragPreviewValue / item.goalValue))
        }
        return progress
    }
    
    var goalText: String? {
        if item.type == .habit {
            let current = (isDragging ? dragPreviewValue : nil) ?? item.currentValue(on: selectedDate)
            let total = item.goalValue
            let unit = item.goalUnit
            let currentStr = current.formatted(.number.precision(.fractionLength(0...2)))
            let totalStr = total.formatted(.number.precision(.fractionLength(0...2)))
            return "\(currentStr)/\(totalStr)\(unit)"
        }
        
        // Only return Duration (Timer)
        if let dur = item.defaultDurationSeconds, dur > 0 {
            // Format duration
            let mins = dur / 60
            if mins >= 60 {
                let hrs = mins / 60
                let remMin = mins % 60
                return remMin > 0 ? "\(hrs)h \(remMin)m" : "\(hrs)h"
            }
            return "\(mins) min"
        }
        return nil
    }
    
    var tintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "gray": return .gray
        default: return .blue
        }
    }
}

private enum DragIntent {
    case horizontal
    case vertical
}
