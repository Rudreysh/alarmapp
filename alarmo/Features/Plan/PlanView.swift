import SwiftUI
import SwiftData

struct PlanView: View {
    @StateObject var viewModel = PlanViewModel()
    @Environment(\.modelContext) var modelContext
    
    // Fetch all active items
    @Query(filter: #Predicate<PlanItem> { !$0.isArchived }, sort: \PlanItem.createdAt, order: .reverse)
    var allItems: [PlanItem]
    
    // Sheets
    @State private var showingCreateSheet = false
    @State private var showingNoteSheet = false
    @State private var showingAddMenu = false
    @State private var showingHabitSheet = false
    
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
    
    struct FloatingBubble: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let value: String
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                PlanHeaderView()
                
                // Calendar Header
                CalendarHeaderView(selectedDate: $viewModel.selectedDate, isListView: $viewModel.isListView)
                
                // Content
                if viewModel.isListView {
                    // Timeline List View
                    List {
                         let filtered = viewModel.items(from: allItems)
                         // Separate "All Day" (Anytime) vs "Scheduled"
                         
                         // All Day / Anytime Section
                         let anytimeItems = filtered.filter { $0.anytime || $0.scheduledTime == nil }
                         if !anytimeItems.isEmpty {
                             Section(header: Text("All Day").font(.caption).foregroundColor(Colors.textSecondary)) {
                                 ForEach(anytimeItems) { item in
                                     PlanItemTimelineRow(item: item, timeString: "All Day", isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                         viewModel.toggleComplete(item, context: modelContext)
                                     } onPlay: {
                                         startTimer(for: item)
                                     }
                                     .listRowBackground(Color.clear)
                                     .listRowSeparator(.hidden)
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
                         
                         // Scheduled items sorted by time
                         let scheduledItems = filtered.filter { !$0.anytime && $0.scheduledTime != nil }
                             .sorted { ($0.scheduledTime ?? Date()) < ($1.scheduledTime ?? Date()) }
                             
                         if !scheduledItems.isEmpty {
                             Section(header: Text("Scheduled").font(.caption).foregroundColor(Colors.textSecondary)) {
                                 ForEach(scheduledItems) { item in
                                     let timeStr = formatTime(item.scheduledTime)
                                     PlanItemTimelineRow(item: item, timeString: timeStr, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                         viewModel.toggleComplete(item, context: modelContext)
                                     } onPlay: {
                                         startTimer(for: item)
                                     }
                                     .listRowBackground(Color.clear)
                                     .listRowSeparator(.hidden)
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
                    .padding(.bottom, 100)
                } else {
                    // Standard Calendar Mode (Sections)
                    List {
                        // Items List
                        let filtered = viewModel.items(from: allItems)
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
                                            .foregroundColor(Colors.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Colors.textSecondary)
                                            .rotationEffect(.degrees(viewModel.isAnytimeExpanded ? 90 : 0))
                                        Spacer()
                                    }
                                    .padding(.leading, -16) 
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            ) {
                                if viewModel.isAnytimeExpanded {
                                    ForEach(anytimeItems) { item in
                                        PlanItemRow(item: item, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        } onPlay: {
                                            startTimer(for: item)
                                        } onQuickAdd: { _, position in
                                            let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                            addFloatingBubble(value: "+\(Int(amount))", at: position)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        }
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
                                           .foregroundColor(Colors.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Colors.textSecondary)
                                            .rotationEffect(.degrees(viewModel.isHabitsExpanded ? 90 : 0))
                                        Spacer()
                                    }
                                    .padding(.leading, -16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            ) {
                                if viewModel.isHabitsExpanded {
                                    ForEach(habits) { item in
                                        PlanItemRow(item: item, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        } onPlay: {
                                            startTimer(for: item)
                                        } onQuickAdd: { _, position in
                                            let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                            addFloatingBubble(value: "+\(Int(amount))", at: position)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        }
                                        .onTapGesture {
                                            // Tap on habit -> Open Detail View (Start Focus screen)
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
                                            
                        // Daily Tasks Section
                        if !tasks.isEmpty {
                             Section(header: 
                                Button(action: { withAnimation { viewModel.isTasksExpanded.toggle() } }) {
                                    HStack {
                                        Text("Tasks (\(tasks.count))")
                                           .font(.system(size: 14, weight: .medium))
                                           .foregroundColor(Colors.textSecondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Colors.textSecondary)
                                            .rotationEffect(.degrees(viewModel.isTasksExpanded ? 90 : 0))
                                        Spacer()
                                    }
                                    .padding(.leading, -16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            ) {
                                 if viewModel.isTasksExpanded {
                                    ForEach(tasks) { item in
                                        PlanItemRow(item: item, isCompleted: viewModel.isCompleted(item, on: viewModel.selectedDate)) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        } onPlay: {
                                            startTimer(for: item)
                                        } onQuickAdd: { _, position in
                                            let amount = viewModel.incrementHabit(item, value: nil, context: modelContext)
                                            addFloatingBubble(value: "+\(Int(amount))", at: position)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            viewModel.toggleComplete(item, context: modelContext)
                                        }
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
                    .padding(.bottom, 100)
                }
            }
            
            // Floating Bubbles Overlay
            ForEach(floatingBubbles) { bubble in
                Text(bubble.value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.accentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.shadow(radius: 2))
                    .cornerRadius(8)
                    .position(x: bubble.x, y: bubble.y)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .offset(y: -100).combined(with: .opacity)))
            }
            
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
                        Spacer()
                        PlanFloatingMenu(
                            onSelectTask: {
                                print("DEBUG: Task Selected")
                                withAnimation { showingAddMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingCreateSheet = true
                                }
                            },
                            onSelectNote: {
                                print("DEBUG: Note Selected")
                                withAnimation { showingAddMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingNoteSheet = true
                                }
                            },
                            onSelectHabit: {
                                print("DEBUG: Habit Selected")
                                withAnimation { showingAddMenu = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingHabitSheet = true
                                }
                            }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 90) // Match FAB position + offset
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
            
            // FAB (Top Level ZStack)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            showingAddMenu.toggle()
                            print("DEBUG: Menu Toggled to \(showingAddMenu)")
                        }
                    }) {
                        Image(systemName: showingAddMenu ? "xmark" : "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Colors.bgPrimary)
                            .frame(width: 56, height: 56)
                            .background(Colors.textPrimary)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
            }
            .zIndex(4)
        }
        .onAppear {
            viewModel.setContext(modelContext)
            checkDefaultTasks()
            
            Task {
                await viewModel.syncHealthData()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePlanItemView()
        }
        .sheet(isPresented: $showingNoteSheet) {
            CreateNoteView()
                .presentationDetents([.height(140)]) // Small initial height
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear) // Visible background
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
        pomoEngine.start()
        
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
            }
        }
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
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
            // Time Column
            Text(timeString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 50, alignment: .trailing)
                .padding(.top, 14) // Align with text roughly
            
            // Content Card
            if item.type == .note {
                // Note Item
                HStack(spacing: 12) {
                    // Indicator
                    ZStack {
                        if isCompleted {
                             Image(systemName: "checkmark.circle.fill") // or just circle fill
                                 .foregroundColor(.green)
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
                .background(Colors.cardSurface)
                .cornerRadius(12)
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
                .background(Colors.cardSurface)
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 4)
    }
    
    var tintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
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
                    Text("Shield Off")
                        .font(.caption)
                        .foregroundColor(Colors.textPrimary)
                    Image(systemName: "shield.slash.fill")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Colors.cardSurface)
                .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("1") 
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Colors.textPrimary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Colors.cardSurface)
                .cornerRadius(16)
            }
        }
        .padding()
    }
}

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @Binding var isListView: Bool
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { shiftDate(-1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Colors.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(isToday ? "Today" : formatDateTitle)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                        if isToday {
                            Image(systemName: "chevron.down.circle.fill")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                    Text(formatDateSubtitle)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
                
                Button(action: { shiftDate(1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                // View Toggles (Only 2 Modes: List & Calendar)
                HStack(spacing: 0) {
                    // List Mode
                    Button(action: { 
                        withAnimation { isListView = true } 
                    }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(isListView ? Colors.textPrimary : Colors.textSecondary)
                            .padding(8)
                            .background(isListView ? Colors.cardSurface : Color.clear)
                            .clipShape(Circle())
                    }
                    
                    // Calendar Mode
                    Button(action: { 
                        withAnimation { isListView = false } 
                    }) {
                        Image(systemName: "calendar")
                            .foregroundColor(!isListView ? Colors.textPrimary : Colors.textSecondary)
                            .padding(8)
                            .background(!isListView ? Colors.cardSurface : Color.clear)
                            .clipShape(Circle())
                    }
                }
                .padding(4)
                .background(Colors.bgSecondary.opacity(0.3))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            // Week Row
            WeekStripView(selectedDate: $selectedDate)
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
        f.dateFormat = "E d MMM"
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
                .background(isSelected ? Colors.accentRed : Color.clear)
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

// Updated PlanItemRow
struct PlanItemRow: View {
    let item: PlanItem
    let isCompleted: Bool
    let onToggle: () -> Void
    var onPlay: (() -> Void)? = nil
    var onQuickAdd: ((Double, CGPoint) -> Void)? = nil
    
    @State private var quickAddScale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background Progress Fill
            progressBackground
            
            HStack(spacing: 12) {
                // Icon / Checkmark button
                iconSection
                
                // Content
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .strikethrough(isCompleted)
                    
                    if let goalText = goalText {
                        Text(goalText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Quick Add Button (For Habits)
                if item.type == .habit && !isCompleted {
                    GeometryReader { geo in
                        Button(action: {
                            let frame = geo.frame(in: .global)
                            let center = CGPoint(x: frame.midX, y: frame.midY)
                            onQuickAdd?(1, center) // Pass 1 for default increment
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                quickAddScale = 1.2
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                quickAddScale = 1.0
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(tintColor)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(quickAddScale)
                    }
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 4)
                }
                
                // Play Button (For focus sessions)
                if let duration = item.defaultDurationSeconds, duration > 0, !isCompleted {
                    Button(action: { onPlay?() }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Checkmark for completed habits
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Colors.cardSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Colors.cardStroke, lineWidth: 1)
        )
        .shadow(color: isCompleted ? Color.green.opacity(0.2) : Color.clear, radius: 10, x: 0, y: 0)
    }
    
    @ViewBuilder
    private var progressBackground: some View {
        GeometryReader { geo in
            let p = progress
            if isWaterHabit {
                // Water Fill
                Rectangle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: geo.size.width * p)
                    .animation(.spring(), value: p)
            } else if isMindfulHabit {
                // Soft Glow
                Circle()
                    .fill(tintColor.opacity(0.15))
                    .frame(width: geo.size.height * 2)
                    .blur(radius: 20)
                    .offset(x: -geo.size.height, y: 0)
                    .scaleEffect(0.5 + p * 0.5)
                    .animation(.spring(), value: p)
            } else {
                // Subtle Bar Fill
                Rectangle()
                    .fill(tintColor.opacity(0.1))
                    .frame(width: geo.size.width * p)
                    .animation(.spring(), value: p)
            }
        }
    }
    
    private var iconSection: some View {
        Button(action: onToggle) {
            ZStack {
                if isSFIcon {
                    Image(systemName: item.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(tintColor)
                        .frame(width: 32, height: 32)
                        .background(tintColor.opacity(0.1))
                        .clipShape(Circle())
                } else {
                    Text(item.iconName)
                        .font(.system(size: 20))
                        .frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
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
    
    private var progress: Double {
        if item.type != .habit { return 0 }
        let current = item.currentValue(on: Date())
        let target = item.goalValue
        return min(max(current / target, 0), 1)
    }
    
    var goalText: String? {
        if item.type == .habit {
            let current = item.currentValue(on: Date())
            let total = item.goalValue
            let unit = item.goalUnit
            return "\(Int(current))/\(Int(total))\(unit)"
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
        default: return .blue
        }
    }
}

