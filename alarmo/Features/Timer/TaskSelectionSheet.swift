import SwiftUI
import SwiftData

struct TaskSelectionSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var engine: PomodoroEngine
    
    // Fetch Plan Items (Habits, Focus sessions, Tasks)
    @Query(filter: #Predicate<PlanItem> { !$0.isArchived }, sort: \PlanItem.createdAt, order: .reverse)
    var activePlans: [PlanItem]
    
    @State private var showNewTaskSheet = false
    @State private var renamingTaskId: UUID?
    @State private var renamingPlanId: UUID?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    @State private var showQuickPresets = false
    
    private var selectablePlans: [PlanItem] {
        activePlans.filter { plan in
            plan.parentTask == nil &&
            (plan.type == .task || plan.type == .habit)
        }
    }

    private var hasActiveTimerContext: Bool {
        engine.isRunning || engine.isPaused
    }

    private func handleSelection(for plan: PlanItem) {
        if hasActiveTimerContext {
            engine.startParallelSession(for: plan)
        } else {
            engine.apply(planItem: plan)
        }
        dismiss()
    }

    private func handleSelection(for task: TaskItem) {
        taskStore.selectTask(task.id)
        if hasActiveTimerContext {
            engine.startParallelSession(for: task)
        } else {
            engine.apply(task: task)
        }
        dismiss()
    }

    private func handleCreatedTaskSelection() {
        defer { dismiss() }
        guard let selected = taskStore.selectedTask else { return }
        if hasActiveTimerContext {
            engine.startParallelSession(for: selected)
        } else {
            engine.apply(task: selected)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                VStack(spacing: 0) {
                    // "New Task" row
                    Button(action: { showNewTaskSheet = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(TimerPalette.accent.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(TimerPalette.accent)
                            }
                            
                            Text("New Task")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)

                    Button(action: { showQuickPresets = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(TimerPalette.accent.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(TimerPalette.accent)
                            }

                            Text("Quick Presets")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textTertiary)
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, 8)
                    
                    List {
                        Section {
                            ForEach(selectablePlans) { plan in
                                PlanTaskRowCard(
                                    item: plan,
                                    isSelected: engine.state.selectedTaskId == plan.id,
                                    onSelect: {
                                        handleSelection(for: plan)
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Spacing.l, bottom: 6, trailing: Spacing.l))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        renamingPlanId = plan.id
                                        renamingTaskId = nil
                                        renameText = plan.title
                                        showRenameAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(TimerPalette.accent)

                                    Button(role: .destructive) {
                                        if engine.state.selectedTaskId == plan.id {
                                            engine.state.selectedTaskId = nil
                                            engine.state.overriddenTaskName = nil
                                        }
                                        modelContext.delete(plan)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("Today's task")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Colors.textTertiary)
                                .textCase(nil)
                        }

                        Section {
                            ForEach(taskStore.tasks.filter { !$0.isArchived }) { task in
                                TaskRowCard(
                                    task: task,
                                    isSelected: engine.state.selectedTaskId == task.id,
                                    onSelect: {
                                        handleSelection(for: task)
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Spacing.l, bottom: 6, trailing: Spacing.l))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        renamingTaskId = task.id
                                        renamingPlanId = nil
                                        renameText = task.name
                                        showRenameAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(TimerPalette.accent)

                                    Button(role: .destructive) {
                                        if engine.state.selectedTaskId == task.id {
                                            engine.state.selectedTaskId = nil
                                            engine.state.overriddenTaskName = nil
                                        }
                                        taskStore.deleteTask(task.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("Added tasks")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Colors.textTertiary)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Select a Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 26))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showNewTaskSheet) {
                DetailedNewTaskView(onTaskCreated: {
                    handleCreatedTaskSelection()
                })
                .environmentObject(taskStore)
            }
            .sheet(isPresented: $showQuickPresets) {
                FrequentlyUsedPomoSheet(
                    viewModel: viewModel,
                    engine: engine,
                    onPresetApplied: {
                        showQuickPresets = false
                        dismiss()
                    }
                )
            }
            .alert("Rename Task", isPresented: $showRenameAlert) {
                TextField("Task Name", text: $renameText)
                Button("Save") {
                    let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }

                    if let planId = renamingPlanId,
                       let plan = selectablePlans.first(where: { $0.id == planId }) {
                        plan.title = String(trimmedName.prefix(50))
                        plan.updatedAt = Date()
                        try? modelContext.save()
                    } else if let taskId = renamingTaskId {
                        taskStore.renameTask(taskId, to: trimmedName)
                        if taskStore.selectedTaskId == taskId {
                            engine.state.overriddenTaskName = nil
                        }
                    }
                    renamingTaskId = nil
                    renamingPlanId = nil
                }
                Button("Cancel", role: .cancel) {
                    renamingTaskId = nil
                    renamingPlanId = nil
                }
            } message: {
                Text("Update the task name.")
            }
        }
    }
}

struct TaskRowCard: View {
    let task: TaskItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon styling based on task name (matching user screenshot patterns)
                taskIconView
                
                Text(task.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                // Play button indicator (decorative/functional selection)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(playButtonColor)
            }
            .padding()
            .background(Colors.cardSurface.opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? TimerPalette.accent.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
    }
    
    @ViewBuilder
    private var taskIconView: some View {
        let (icon, color) = getTaskMetaData(name: task.name)
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.2))
                .frame(width: 38, height: 38)
            
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
        }
    }
    
    private func getTaskMetaData(name: String) -> (String, Color) {
        let lower = name.lowercased()
        if lower.contains("water") || lower.contains("drink") {
            return ("drop.fill", TimerPalette.accent)
        } else if lower.contains("focus") || lower.contains("study") {
            return ("timer", Color.orange)
        } else if lower.contains("read") || lower.contains("book") {
            return ("book.fill", Color(red: 1.0, green: 0.4, blue: 0.6)) // Pinkish
        } else if lower.contains("pomo") {
            return ("stopwatch.fill", TimerPalette.accent)
        } else if lower.contains("exercise") || lower.contains("gym") || lower.contains("fitness") {
            return ("figure.run", TimerPalette.accent)
        } else if lower.contains("code") || lower.contains("work") {
            return ("briefcase.fill", TimerPalette.accent)
        }
        return ("pencil.and.outline", Colors.textTertiary)
    }

    private var playButtonColor: Color {
        if SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch {
            return Colors.accentBlue.opacity(isSelected ? 1.0 : 0.55)
        }
        return isSelected ? TimerPalette.accent : Colors.textTertiary.opacity(0.3)
    }
}

struct PlanTaskRowCard: View {
    let item: PlanItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon styling based on plan item
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tintColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: item.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(tintColor)
                }
                
                Text(item.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                // Play button indicator
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(playButtonColor)
            }
            .padding()
            .background(Colors.cardSurface.opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? TimerPalette.accent.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
    }
    
    var tintColor: Color {
        switch item.tintKey {
        case "red": return .red
        case "blue": return TimerPalette.accent
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        default: return TimerPalette.accent
        }
    }

    private var playButtonColor: Color {
        if SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch {
            return Colors.accentBlue.opacity(isSelected ? 1.0 : 0.55)
        }
        return isSelected ? TimerPalette.accent : Colors.textTertiary.opacity(0.3)
    }
}
