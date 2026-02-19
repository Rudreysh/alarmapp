import SwiftUI
import SwiftData

struct PlanItemTaskDetailView: View {
    @Bindable var item: PlanItem
    var onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingAddSubtask = false
    @State private var editingSubtask: PlanItem? // For editing subtasks
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        if item.iconName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }) {
                            Image(systemName: item.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(iconPriorityColor)
                        } else {
                            Text(item.iconName)
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PlanPalette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text(item.title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(PlanPalette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(PlanPalette.textSecondary)
                            .planGlassCircle(size: 34, fillOpacity: 0.12)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 10) {
                    Text("Priority")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PlanPalette.textMuted)
                    
                    Text(selectedPriorityTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(selectedPriorityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectedPriorityColor.opacity(0.18))
                        )
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        ForEach(PriorityLevel.allCases.reversed(), id: \.self) { p in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    item.priority = p.rawValue
                                    item.tintKey = tintKey(for: p, fallback: item.tintKey)
                                    item.updatedAt = Date()
                                }
                                try? modelContext.save()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(colorForPriority(p).opacity(p.rawValue == item.priority ? 0.34 : 0.16))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    p.rawValue == item.priority ? colorForPriority(p).opacity(0.9) : Color.white.opacity(0.18),
                                                    lineWidth: p.rawValue == item.priority ? 1.4 : 1
                                                )
                                        )
                                    
                                    Image(systemName: p.icon)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(colorForPriority(p))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .planGlassPanel(cornerRadius: 16, fillOpacity: 0.10)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            

            
            // Subtasks Section (Image 2 style)
            VStack(alignment: .leading, spacing: 0) {
                let orderedSubtasks = item.subtasks.sorted { $0.createdAt < $1.createdAt }
                if !orderedSubtasks.isEmpty {
                     ForEach(orderedSubtasks) { sub in
                         SwipeableSubtaskRow(sub: sub, isCompleted: isSubtaskCompleted(sub)) {
                             toggleSubtask(sub)
                         } onDelete: {
                             deleteSubtask(sub)
                         } onEdit: {
                             editingSubtask = sub
                         }
                         
                         Divider().background(Colors.cardStroke)
                     }
                }
                
                Button(action: { showingAddSubtask = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("Add Subtask")
                            .font(.system(size: 16))
                        Spacer()
                    }
                    .foregroundColor(PlanPalette.accent)
                    .padding()
                }
            }
            .planGlassPanel(cornerRadius: 16) // Solid card background
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Edit Button (Shifted down or kept)
            Button(action: { showingEditSheet = true }) {
                Text("Edit Task")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .stroke(Colors.textSecondary.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .background(PlanGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 24))
        // Edit Sheet
        .sheet(isPresented: $showingEditSheet) {
             CreatePlanItemView(editingItem: item)
        }
        .sheet(isPresented: $showingAddSubtask) {
            CreateNoteView(parentTask: item)
                .presentationDetents([.height(140)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .sheet(item: $editingSubtask) { sub in
             CreateNoteView(itemToEdit: sub)
                 .presentationDetents([.height(140)])
                 .presentationDragIndicator(.hidden)
                 .presentationBackground(.clear)
        }
    }
    
    // MARK: - Logic
    
    private var isCompletedToday: Bool {
        item.completionLogs.contains { Calendar.current.isDateInToday($0.date) && $0.completed }
    }
    
    private func toggleComplete() {
         if isCompletedToday {
            // Undo
            if let index = item.completionLogs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                item.completionLogs.remove(at: index)
            }
        } else {
            // Complete
            let log = CompletionLog(date: Date(), completed: true)
            item.completionLogs.append(log)
            
            // Award points
            if item.type == .task {
                PointsService.shared.taskCompleted(taskId: item.id, taskName: item.title)
            }
        }
        try? modelContext.save()
    }
    
    private var timeString: String {
        if item.anytime { return "Anytime" }
        guard let date = item.scheduledTime else { return "Anytime" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private var tintColor: Color {
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
    
    private var statusSummary: String {
        var parts: [String] = []
        
        // Repeat logic
        if item.repeatRule.frequency == .none {
            parts.append("Never Repeat")
        } else {
             parts.append("Repeats")
        }
        
        // Reminder logic
        if item.reminderEnabled {
            parts.append("Reminder On")
        } else {
            parts.append("No Reminder")
        }
        
        return parts.joined(separator: ". ") + "."
    }
    
     private var priorityColor: Color {
         if let p = PriorityLevel(rawValue: item.priority) {
             return colorForPriority(p)
         }
         return Colors.textSecondary
     }
     
     private func colorForPriority(_ p: PriorityLevel) -> Color {
         switch p {
         case .high: return .red
         case .medium: return .orange
         case .low: return .blue
         case .none: return Color.gray
         }
     }

    private var selectedPriority: PriorityLevel {
        PriorityLevel(rawValue: item.priority) ?? .none
    }

    private var selectedPriorityColor: Color {
        colorForPriority(selectedPriority)
    }

    private var iconPriorityColor: Color {
        switch selectedPriority {
        case .high:
            return colorForPriority(.high)
        case .medium:
            return colorForPriority(.medium)
        case .low:
            return tintColor
        case .none:
            return colorForPriority(.none)
        }
    }

    private var selectedPriorityTitle: String {
        switch selectedPriority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }

    private func tintKey(for priority: PriorityLevel, fallback: String) -> String {
        switch priority {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        case .none: return "gray"
        }
    }
    
    // Subtask Logic
    private func isSubtaskCompleted(_ sub: PlanItem) -> Bool {
        sub.completionLogs.contains { Calendar.current.isDateInToday($0.date) && $0.completed }
    }
    
    private func toggleSubtask(_ sub: PlanItem) {
        if isSubtaskCompleted(sub) {
             if let index = sub.completionLogs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                 sub.completionLogs.remove(at: index)
             }
        } else {
             let log = CompletionLog(date: Date(), completed: true)
             sub.completionLogs.append(log)
        }
        try? modelContext.save()
        try? modelContext.save()
    }
    
    private func deleteSubtask(_ sub: PlanItem) {
        if let index = item.subtasks.firstIndex(of: sub) {
            item.subtasks.remove(at: index)
            modelContext.delete(sub)
            try? modelContext.save()
        }
    }
}

// Custom Swipe Row for Subtasks
struct SwipeableSubtaskRow: View {
    let sub: PlanItem
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    var body: some View {
        ZStack {

            
            // Content
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    ZStack {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(PlanPalette.accent)
                        } else {
                            Circle()
                                .stroke(Colors.textSecondary.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                    .frame(width: 18, height: 18) // Fixed container size (30% smaller)
                }
                .buttonStyle(.plain)
                
                Text(sub.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                    .strikethrough(isCompleted, color: .black)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .planGlassPanel(cornerRadius: 16) // Opaque background to hide actions

        }
        .clipped()
    }
}
