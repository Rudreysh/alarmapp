import SwiftUI
import SwiftData

struct TaskSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var engine: PomodoroEngine
    
    // Fetch Plan Items (Habits, Focus sessions, Tasks)
    @Query(filter: #Predicate<PlanItem> { !$0.isArchived }, sort: \PlanItem.createdAt, order: .reverse)
    var activePlans: [PlanItem]
    
    @State private var showNewTaskSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // "New Task" row
                    Button(action: { showNewTaskSheet = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Colors.accentTeal.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's task")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.horizontal, Spacing.l)
                            .padding(.top, Spacing.l)
                        
                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 12) {
                                // Active Plans Section
                                ForEach(activePlans) { plan in
                                    PlanTaskRowCard(
                                        item: plan,
                                        isSelected: engine.state.selectedTaskId == plan.id,
                                        onSelect: {
                                            // Apply plan settings
                                            engine.stop(reset: true) // Reset first
                                            engine.apply(planItem: plan)
                                            dismiss()
                                        }
                                    )
                                }
                                
                                // Legacy/Quick Tasks from TaskStore
                                ForEach(taskStore.tasks.filter { !$0.isArchived }) { task in
                                    TaskRowCard(
                                        task: task,
                                        isSelected: engine.state.selectedTaskId == task.id, // Check against engine state too
                                        onSelect: {
                                            taskStore.selectTask(task.id)
                                            // Clear override since this is a regular task
                                            engine.state.overriddenTaskName = nil 
                                            engine.apply(task: task)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Spacing.l)
                            .padding(.bottom, Spacing.xl)
                        }
                        .scrollIndicators(.visible)
                    }
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
                NewTaskSheet()
                    .environmentObject(taskStore)
                    .presentationDetents([.height(180)]) // Compact height for Quick Add
                    .presentationDragIndicator(.hidden)
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
                    .foregroundColor(isSelected ? Colors.accentTeal : Colors.textTertiary.opacity(0.3))
            }
            .padding()
            .background(Colors.cardSurface.opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Colors.accentTeal.opacity(0.3) : Color.clear, lineWidth: 2)
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
            return ("drop.fill", Color.blue)
        } else if lower.contains("focus") || lower.contains("study") {
            return ("timer", Color.orange)
        } else if lower.contains("read") || lower.contains("book") {
            return ("book.fill", Color(red: 1.0, green: 0.4, blue: 0.6)) // Pinkish
        } else if lower.contains("pomo") {
            return ("stopwatch.fill", Colors.accentRed)
        } else if lower.contains("exercise") || lower.contains("gym") || lower.contains("fitness") {
            return ("figure.run", Colors.accentGreen)
        } else if lower.contains("code") || lower.contains("work") {
            return ("briefcase.fill", Colors.accentTeal)
        }
        return ("pencil.and.outline", Colors.textTertiary)
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
                    .foregroundColor(isSelected ? Colors.accentTeal : Colors.textTertiary.opacity(0.3))
            }
            .padding()
            .background(Colors.cardSurface.opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Colors.accentTeal.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
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
