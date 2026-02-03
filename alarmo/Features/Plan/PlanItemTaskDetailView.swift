import SwiftUI
import SwiftData

struct PlanItemTaskDetailView: View {
    @Bindable var item: PlanItem
    var onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingAddSubtask = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header: Icon, Info, Checkbox
            HStack(alignment: .center, spacing: 16) {
                // Icon
                ZStack {
                     Circle()
                         .fill(Colors.bgSecondary)
                         .frame(width: 56, height: 56)
                     if item.iconName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }) {
                         Image(systemName: item.iconName)
                             .font(.system(size: 28))
                             .foregroundColor(tintColor)
                     } else {
                         Text(item.iconName)
                             .font(.system(size: 28))
                     }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time: \(timeString)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                    
                    Text(item.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                
                
                
                Spacer()
                
                // Priority Checkbox
                // Priority Selection (Cleaner inline style)
                HStack(spacing: 8) {
                    ForEach(PriorityLevel.allCases.reversed(), id: \.self) { p in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                item.priority = p.rawValue
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(p.rawValue == item.priority ? colorForPriority(p).opacity(0.15) : Colors.bgSecondary)
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: p.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(p.rawValue == item.priority ? colorForPriority(p) : Colors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Colors.cardSurface)
                .cornerRadius(24)
                 
                // Close Button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Colors.bgSecondary)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            

            
            // Subtasks Section (Image 2 style)
            VStack(alignment: .leading, spacing: 0) {
                if !item.subtasks.isEmpty {
                     ForEach(item.subtasks) { sub in
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
                    .foregroundColor(Colors.accentBlue)
                    .padding()
                }
            }
            .background(Colors.cardSurface) // Solid card background
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
        .background(Colors.bgPrimary)
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
    
    @State private var editingSubtask: PlanItem? // For editing subtasks
    
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
         case .none: return Colors.textSecondary
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
                                .foregroundColor(.green)
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
            .background(Colors.cardSurface) // Opaque background to hide actions

        }
        .clipped()
    }
}
