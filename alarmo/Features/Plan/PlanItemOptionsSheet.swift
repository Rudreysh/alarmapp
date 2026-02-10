import SwiftUI
import SwiftData

struct PlanItemOptionsSheet: View {
    @Bindable var item: PlanItem
    @Binding var showFocusSelection: Bool
    @Binding var showAddSubtask: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Grid
            HStack(spacing: 0) {
                OptionGridItem(icon: "pin", title: "Pin", color: .orange) {
                    item.isPinned.toggle()
                    dismiss()
                }
                OptionGridItem(icon: "square.and.arrow.up", title: "Share", color: .green) {
                    // Share action
                    dismiss()
                }
                OptionGridItem(icon: "xmark.square", title: "Won't Do", color: .blue) {
                    // Won't Do logic
                    dismiss()
                }
                OptionGridItem(icon: "trash", title: "Delete", color: .red) {
                    item.isArchived = true
                    item.archivedAt = Date()
                    item.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
            }
            .padding(.vertical, 20)
            .background(Colors.bgSecondary.opacity(0.3))
            
            // List Items
            ScrollView {
                VStack(spacing: 0) {
                    OptionListItem(title: "Add Subtask", icon: "arrow.turn.down.right") {
                        dismiss()
                        // Use a slight delay to allow the sheet to dismiss before opening the next one
                        // Actually, binding works better if we don't dismiss the parent presenting view?
                        // But this is a sheet inside a sheet?
                        // No, PlanItemTaskDetailView presents this.
                        // If we dismiss this, we can tell parent to show subtask sheet.
                        // So we use binding passed from parent.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showAddSubtask = true
                        }
                    }
                    
                    OptionListItem(title: "Link Parent Task", icon: "link") {
                        dismiss()
                    }
                    
                    OptionListItem(title: "Start Focus", icon: "record.circle") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showFocusSelection = true
                        }
                    }
                    
                    OptionListItem(title: "Convert to Note", icon: "book") {
                        item.type = .note
                        try? modelContext.save()
                        dismiss()
                    }
                    
                    OptionListItem(title: "Attachment", icon: "paperclip") {
                        dismiss()
                    }
                    
                    OptionListItem(title: "Tags", icon: "tag") {
                        dismiss()
                    }
                    
                    OptionListItem(title: "Task Activities", icon: "list.bullet.rectangle") {
                        dismiss()
                    }
                     
                    OptionListItem(title: "Add to Live Activity", icon: "bell") {
                        dismiss()
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            Button(action: {}) {
                HStack {
                    Text("More")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Image(systemName: "ellipsis")
                }
                .padding()
                .background(Colors.cardSurface)
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Colors.bgPrimary)
    }
}

struct OptionGridItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct OptionListItem: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
