import SwiftUI
import SwiftData

struct PlanView: View {
    let preferences: AppPreferences
    @StateObject var viewModel = PlanViewModel()
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCoachMark = false          // FAB
    @State private var showQuickLogCoachMark = false
    @State private var showPlanHabitVsTaskCoachMark = false  // Floating menu choice
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
    @State private var showingCreateSheet = false
    @State private var showingAddMenu = false
    @State private var showingHabitSheet = false
    @State private var showUpsell = false
    @State private var showShieldSettings = false
    
    @StateObject private var subManager = SubscriptionManager.shared
    
    // Section Expansion State
    
    
    @State private var selectedItem: PlanItem? // For detail
    @State private var editingItem: PlanItem? // For edit
    @State private var editingNote: PlanItem? // For note editing
    
    // Timer State
    
    @EnvironmentObject var pomoEngine: PomodoroEngine
    @EnvironmentObject var navStore: NavigationStore
    // If pomoEngine is not in environment, I might need to check App entry point. 
    // Assuming PomoTimerView uses `PomodoroEngine`.
    // Let's assume we navigate to `PomoTimerView`.
    
    // Actually, PomoTimerView takes `viewModel` and `engine`.
    // I will use a fullScreenCover to show a wrapper for PomoTimerView.
    
    @State private var floatingBubbles: [FloatingBubble] = []
    private let floatingActionButtonBottomPadding: CGFloat = 90
    private let floatingActionButtonSize: CGFloat = 56
    private var listBottomClearance: CGFloat {
        // Keep bottom rows clearly above the floating + button and tab bar.
        AppConstants.tabBarHeight + floatingActionButtonBottomPadding + (floatingActionButtonSize * 0.5) + 22
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
                    isShieldOn: SettingsStore.shared.accountabilityEnabled,
                    onShieldTap: {
                        if subManager.isPro {
                            showShieldSettings = true
                        } else {
                            showUpsell = true
                        }
                    }
                )
                
                // Content
                if viewModel.isListView {
                    // Timeline List View
                    List {
                         let filtered = viewModel.items(from: allItems)
                         let firstVisibleItemId = filtered.first?.id
                         // Separate "All Day" (Anytime) vs "Scheduled"
                         
                         // All Day / Anytime Section
                         let anytimeItems = filtered.filter { $0.anytime || $0.scheduledTime == nil }
                         if !anytimeItems.isEmpty {
                             Section(header: timelineSectionHeader(title: "All Day", count: anytimeItems.count, icon: "sun.max.fill")) {
                                 ForEach(Array(anytimeItems.enumerated()), id: \.element.id) { index, item in
                                     PlanItemTimelineRow(item: item, timeString: "", isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                         viewModel.toggleComplete(item, context: modelContext)
                                     } onPlay: {
                                         startTimer(for: item)
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
                         
                         // Scheduled items sorted by time
                         let scheduledItems = filtered.filter { !$0.anytime && $0.scheduledTime != nil }
                             .sorted { ($0.scheduledTime ?? Date()) < ($1.scheduledTime ?? Date()) }
                             
                         if !scheduledItems.isEmpty {
                             Section(header: timelineSectionHeader(title: "Scheduled", count: scheduledItems.count, icon: "clock.fill")) {
                                 ForEach(scheduledItems) { item in
                                     let timeStr = formatTime(item.scheduledTime)
                                     PlanItemTimelineRow(item: item, timeString: timeStr, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                         viewModel.toggleComplete(item, context: modelContext)
                                     } onPlay: {
                                         startTimer(for: item)
                                     }
                                     .listRowBackground(Color.clear)
                                     .listRowSeparator(.hidden)
                                     .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                     .contentShape(Rectangle())
                                     .onTapGesture {
                                         selectedItem = item
                                     }
                                     .id(item.updatedAt) // Force Refresh
                                     .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { deleteItem(item) } label: { Label("Delete", systemImage: "trash") }
                                        Button { startEditing(item) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
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
                        let firstVisibleItemId = filtered.first?.id
                        let anytimeItems = filtered.filter { $0.anytime }
                        let scheduledItems = filtered.filter { !$0.anytime }
                        
                        let habits = scheduledItems.filter { $0.type == .habit }
                        let tasks = scheduledItems.filter { $0.type != .habit }
                        
                        // Anytime Section
                        if !anytimeItems.isEmpty {
                             Section(header: 
                                Button(action: { withAnimation { viewModel.isAnytimeExpanded.toggle() } }) {
                                    HStack {
                                        Text("Anytime (\(anytimeItems.count))")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(PlanPalette.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(PlanPalette.textSecondary)
                                            .rotationEffect(.degrees(viewModel.isAnytimeExpanded ? 90 : 0))
                                        Spacer()
                                    }
                                    .padding(.leading, -16) 
                                }
                                .buttonStyle(.plain)
                            ) {
                                if viewModel.isAnytimeExpanded {
                                    ForEach(anytimeItems) { item in
                                        PlanItemRow(item: item, selectedDate: viewModel.selectedDate, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        } onPlay: {
                                            startTimer(for: item)
                                        } onQuickAdd: { _, position in
                                            let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                            addFloatingBubble(value: "+\(Int(amount))", at: position)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        } onAdjust: { delta in
                                            viewModel.updateHabitValue(item, delta: delta, context: modelContext)
                                        }
                                        .coachMark(
                                            title: "Manage",
                                            subtitle: "Long press to edit or delete.",
                                            isVisible: Binding(get: { item.id == firstVisibleItemId ? showPlanSwipeCoachMark : false }, set: { showPlanSwipeCoachMark = $0 }),
                                            alignment: .top,
                                            pointDirection: .bottom,
                                            arrowAlignment: .center,
                                            arrowOffsetX: 0,
                                            bubbleOffsetX: 0,
                                            bubbleOffsetY: -60,
                                            color: .red
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
                                            Button(role: .destructive) { deleteItem(item) } label: { Label("Delete", systemImage: "trash") }
                                            Button { startEditing(item) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        
                         // Habits Section
                        if !habits.isEmpty {
                            Section(header: 
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
                                    .padding(.leading, -16)
                                }
                                .buttonStyle(.plain)
                            ) {
                                if viewModel.isHabitsExpanded {
                                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, item in
                                        PlanItemRow(item: item, selectedDate: viewModel.selectedDate, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
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
                                            // Tap on habit -> Open Detail View (Start Focus screen)
                                            selectedItem = item
                                        }
                                        .id(item.updatedAt) // Force Refresh
                                        .contextMenu {
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
                                        }
                                    }
                                }
                            }
                        }
                                            
                        // Daily Tasks Section
                        if !tasks.isEmpty {
                             Section(header: 
                                Button(action: { withAnimation { viewModel.isTasksExpanded.toggle() } }) {
                                    HStack {
                                        Text("Tasks (\(tasks.count))")
                                           .font(.system(size: 14, weight: .medium))
                                           .foregroundColor(PlanPalette.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(PlanPalette.textSecondary)
                                            .rotationEffect(.degrees(viewModel.isTasksExpanded ? 90 : 0))
                                        Spacer()
                                    }
                                    .padding(.leading, -16)
                                }
                                .buttonStyle(.plain)
                            ) {
                                 if viewModel.isTasksExpanded {
                                    ForEach(tasks) { item in
                                        PlanItemRow(item: item, selectedDate: viewModel.selectedDate, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        } onPlay: {
                                            startTimer(for: item)
                                        } onQuickAdd: { _, position in
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
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedItem = item
                                        }
                                        .id(item.updatedAt) // Force Refresh
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) { deleteItem(item) } label: { Label("Delete", systemImage: "trash") }
                                            Button { startEditing(item) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.visible, axes: .vertical)
                    .scrollIndicatorsFlash(onAppear: true)
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
            
            // Dimmed Background when menu is open
            if showingAddMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showingAddMenu = false }
                    }
                    .zIndex(1)
            }
            
            // Floating Add Menu (Top Level ZStack)
            if showingAddMenu {
                VStack {
                    Spacer()
                    HStack {
                        PlanFloatingMenu(
                            onSelectTask: {
                                preferences.hasSeenPlanHabitVsTaskTooltip = true
                                showPlanHabitVsTaskCoachMark = false
                                withAnimation { showingAddMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingCreateSheet = true
                                }
                            },
                            onSelectHabit: {
                                let habitCount = allItems.filter { $0.type == .habit }.count
                                preferences.hasSeenPlanHabitVsTaskTooltip = true
                                showPlanHabitVsTaskCoachMark = false
                                withAnimation { showingAddMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if !subManager.isPro && habitCount >= 2 {
                                        showUpsell = true
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    } else {
                                        showingHabitSheet = true
                                    }
                                }
                            }
                        )
                        .coachMark(
                            title: "Plan Type",
                            subtitle: "Streaks vs tasks.",
                            isVisible: $showPlanHabitVsTaskCoachMark,
                            alignment: .topLeading,
                            pointDirection: .bottom,
                            arrowAlignment: .leading,
                            arrowOffsetX: 24,
                            bubbleOffsetX: 0,
                            bubbleOffsetY: -80,
                            color: .red
                        )
                        .padding(.leading, 20)
                        .padding(.bottom, 160) // Position above FAB (90 + 56 + 14)
                        Spacer()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
            
            // FAB
            Button(action: {
                withAnimation(.spring()) {
                    showingAddMenu.toggle()
                }
                if preferences.hasSeenPlanTooltip == false {
                    preferences.hasSeenPlanTooltip = true
                    showCoachMark = false
                }
            }) {
                Image(systemName: showingAddMenu ? "xmark" : "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .planGlassCircle(size: 56, fillOpacity: 0.13)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .coachMark(
                        title: "Create Plan",
                        subtitle: "Tap to add item.",
                        isVisible: $showCoachMark,
                        alignment: .topLeading,
                        pointDirection: .bottom,
                        arrowAlignment: .leading,
                        arrowOffsetX: 24,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -80,
                        color: .red
                    )
            }
            .padding(.leading, 20)
            .padding(.bottom, floatingActionButtonBottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .zIndex(4)

            if showHabitCelebration {
                HabitGoalCelebrationOverlay(habitTitle: celebrationHabitTitle)
                    .zIndex(30)
            }
        }
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.allItems = allItems
            checkDefaultTasks()
            
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
            if !preferences.hasSeenPlanTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showCoachMark = true }
                }
            } else if !preferences.hasSeenPlanHabitVsTaskTooltip && !allItems.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showPlanHabitVsTaskCoachMark = true }
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
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePlanItemView()
        }
        // Notes quick-create from '+' menu is intentionally disabled for now.
        // TODO: Re-enable this sheet when Notes is brought back to the add menu.
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
        .onChange(of: viewModel.selectedDate) { _, _ in
            if showPlanCalendarCoachMark {
                showPlanCalendarCoachMark = false
                preferences.hasSeenPlanCalendarTooltip = true
            }
        }
        .onChange(of: allItems.count) { _, _ in
            viewModel.allItems = allItems
            Task {
                await viewModel.syncHealthData(from: allItems)
            }
        }
        .onChange(of: showCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenPlanTooltip {
                preferences.hasSeenPlanTooltip = true
                if !allItems.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPlanHabitVsTaskCoachMark = true }
                }
            }
        }
        .onChange(of: showPlanHabitVsTaskCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenPlanHabitVsTaskTooltip {
                preferences.hasSeenPlanHabitVsTaskTooltip = true
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
        pomoEngine.stop(reset: true)
        pomoEngine.apply(planItem: item)
        if item.type != .habit {
            pomoEngine.start()
        }
        
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
    
    private func checkDefaultTasks() {
        // Logic to ensure "Study" and "Working" anytime tasks exist
        let defaults = ["Study", "Working"]
        var insertedAny = false
        
        for title in defaults {
            if !allItems.contains(where: { $0.title == title && $0.anytime == true && !$0.isArchived }) {
                let newItem = PlanItem(
                    title: title,
                    iconName: title == "Study" ? "graduationcap.fill" : "briefcase.fill",
                    tintKey: title == "Study" ? "red" : "orange", // Matching image roughly
                    type: .task,
                    anytime: true
                )
                modelContext.insert(newItem)
                insertedAny = true
            }
        }
        
        if insertedAny {
            try? modelContext.save()
        }
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
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
    let item: PlanItem
    let timeString: String
    let isCompleted: Bool
    let onToggle: () -> Void
    var onPlay: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time Column (only reserve space when there is a scheduled time)
            if showsTimeColumn {
                Text(timeString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 50, alignment: .trailing)
                    .padding(.top, 14) // Align with text roughly
            }
            
            // Content Card
            if item.type == .note {
                // Note Item
                HStack(spacing: 12) {
                    // Indicator
                    ZStack {
                        if isCompleted {
                             Image(systemName: "checkmark.circle.fill") // or just circle fill
                                 .foregroundColor(PlanPalette.accent)
                                 .font(.system(size: 14))
                        } else {
                            if item.iconName.allSatisfy({ !$0.isASCII }) {
                                // Emoji
                                Text(item.iconName)
                                    .font(.system(size: 14))
                            } else if item.iconName != "circle" {
                                // SF Symbol
                                Image(systemName: item.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(tintColor)
                            } else {
                                // Default Circle
                                Circle().stroke(tintColor, lineWidth: 1.5).frame(width: 14, height: 14)
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
            } else {
                // Task / Habit
                HStack(spacing: 12) {
                    // Checkbox Button
                    Button(action: onToggle) {
                        ZStack {
                            if isCompleted {
                                Circle()
                                    .fill(tintColor)
                                    .frame(width: 18, height: 18)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                // Unchecked
                                let isSF = item.iconName.allSatisfy { $0.isASCII }
                                
                                if isSF {
                                    Circle()
                                        .stroke(tintColor, lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                    
                                    if item.iconName == "circle" {
                                        Circle().fill(tintColor).frame(width: 6, height: 6)
                                    } else {
                                        Image(systemName: item.iconName)
                                            .font(.system(size: 9))
                                            .foregroundColor(tintColor)
                                    }
                                } else {
                                    Text(item.iconName)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .contentShape(Rectangle()) // Expand hit area slightly?
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
                    
                    if let duration = item.defaultDurationSeconds, duration > 0 {
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
        }
        .padding(.vertical, 4)
    }
    
    private var showsTimeColumn: Bool {
        !timeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var tintColor: Color {
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

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @Binding var isListView: Bool
    @Binding var showCalendarCoachMark: Bool
    var isShieldOn: Bool = false
    var onShieldTap: (() -> Void)? = nil
    
    private var calendar: Calendar { Calendar.current }
    
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
                                .background(Colors.cardSurface)
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
                        Button(action: { onShieldTap?() }) {
                            HStack(spacing: 4) {
                                Image(systemName: isShieldOn ? "shield.checkered" : "shield.slash.fill")
                                    .font(.caption2)
                                    .foregroundColor(isShieldOn ? Colors.accentTeal : .gray)
                                Text(isShieldOn ? "On" : "Off")
                                    .font(.caption2)
                                    .foregroundColor(PlanPalette.textPrimary)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .planGlassPanel(cornerRadius: 12, fillOpacity: isShieldOn ? 0.18 : 0.12)
                            .overlay(
                                isShieldOn
                                    ? RoundedRectangle(cornerRadius: 12)
                                        .stroke(Colors.accentTeal.opacity(0.3), lineWidth: 1)
                                    : nil
                            )
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
                                .background(isListView ? Colors.cardSurface : Color.clear)
                                .clipShape(Circle())
                        }
                        
                        Button(action: { withAnimation { isListView = false } }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(!isListView ? Colors.textPrimary : Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(!isListView ? Colors.cardSurface : Color.clear)
                                .clipShape(Circle())
                        }
                    }
                    .padding(2)
                    .background(Colors.cardSurface.opacity(0.3))
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
    
    var body: some View {
        // Show current week centered around selected date or fixed?
        // Let's show -3 to +3 days from selected
        HStack(spacing: 0) {
            ForEach(-3...3, id: \.self) { offset in
                if let day = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
                    let isSelected = offset == 0
                    WeekDayCell(date: day, isSelected: isSelected) {
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
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(dayName)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
            Text(dayNum)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color(red: 0.06, green: 0.45, blue: 0.62) : Color.clear)
                .clipShape(Circle())
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
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isHabitItem
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.08, blue: 0.12).opacity(0.92),
                                Color(red: 0.06, green: 0.11, blue: 0.17).opacity(0.86),
                                Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.94),
                                Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.88),
                                Color(red: 0.04, green: 0.06, blue: 0.10).opacity(0.94)
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
                                tintColor.opacity(0.38),
                                tintColor.opacity(0.18),
                                Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86)
                    .padding(.leading, 6)
                    .padding(.vertical, 6)
                
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
                        .foregroundColor(PlanPalette.textPrimary)
                        .strikethrough(isCompleted)
                    
                    if let goalText = goalText {
                        Text(goalText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(PlanPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                if item.type == .habit && !isCompleted {
                    GeometryReader { geo in
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
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
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(PlanPalette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCompleted ? PlanPalette.accent.opacity(0.32) : (isDragging ? tintColor.opacity(0.5) : Color.white.opacity(0.20)), lineWidth: isDragging ? 2 : 1)
        )
        .shadow(color: isCompleted ? PlanPalette.accent.opacity(0.20) : (isDragging ? tintColor.opacity(0.3) : Color.black.opacity(0.16)), radius: isDragging ? 15 : 10, x: 0, y: isDragging ? 6 : 4)
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
                            (isWaterHabit ? Color.blue : tintColor).opacity(isDragging ? 0.35 : 0.24),
                            (isWaterHabit ? Color.cyan : tintColor).opacity(isDragging ? 0.20 : 0.10)
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
                    .background(tintColor.opacity(0.14))
                    .clipShape(Circle())
            } else {
                Text(item.iconName)
                    .font(.system(size: emojiFontSize))
                    .frame(width: iconContainerSize, height: iconContainerSize)
            }
        }
    }

    private var isHabitItem: Bool { item.type == .habit }
    private var iconFontSize: CGFloat { isHabitItem ? 22.8 : 19.0 }        // +20% for habits
    private var emojiFontSize: CGFloat { isHabitItem ? 28.8 : 24.0 }       // +20% for habits
    private var iconContainerSize: CGFloat { isHabitItem ? 50.4 : 42.0 }   // +20% for habits
    
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
