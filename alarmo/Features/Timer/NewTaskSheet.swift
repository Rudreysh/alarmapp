import SwiftUI

struct NewTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskStore: TaskStore
    @FocusState private var isFocused: Bool
    
    @State private var taskName: String = ""
    @State private var isAnytime = true
    @State private var selectedDuration = 25
    @State private var isPomodoro = false // Defaults to true if interval timer
    
    // Sheet States
    @State private var showDurationPicker = false
    @State private var showTimePicker = false // Placeholder for "Anytime today" picker
    @State private var showDetailedView = false
    @State private var showEmojiPicker = false
    @State private var selectedEmoji: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
            
            VStack(spacing: 0) {
                // Input Bar Area
                VStack(spacing: 12) {
                    // Task Name Input
                    HStack(spacing: 12) {
                        Button(action: { showEmojiPicker = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Colors.cardSurface)
                                    .frame(width: 40, height: 40)
                                if selectedEmoji.isEmpty {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                } else {
                                    Text(selectedEmoji)
                                        .font(.system(size: 22))
                                }
                            }
                        }

                        TextField("Task Name", text: $taskName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { createQuickTask() }
                        
                        // Submit Button
                        Button(action: createQuickTask) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(!taskName.isEmpty ? TimerPalette.accent : Colors.textTertiary)
                        }
                        .disabled(taskName.isEmpty)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    
                    // Options Row (Horizontal Scroll)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            
                            // 1. Anytime Option
                            // Uses red outline style when active/pressed as requested
                            Button(action: { showTimePicker = true }) {
                                Text("Anytime today")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Colors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Colors.cardSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 30)
                                            .stroke(showTimePicker ? TimerPalette.accent : Color.clear, lineWidth: 1)
                                    )
                                    .cornerRadius(30)
                            }
                            
                            // 2. Duration/Pomodoro Option
                            Button(action: { showDurationPicker = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 14))
                                    Text("\(selectedDuration)m, \(isPomodoro ? "Pomodoro" : "Timer")")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(Colors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Colors.cardSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(showDurationPicker ? TimerPalette.accent : Color.clear, lineWidth: 1) // Red outline when active
                                )
                                .cornerRadius(30)
                            }
                            
                            // 3. Plus Button (Detailed)
                            Button(action: { showDetailedView = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(Colors.cardSurface)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.bottom, Spacing.m)
                    }
                }
                .background(Colors.bgSecondary)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: Colors.shadow, radius: 10, y: -5)
            }
        }
        .onAppear {
            isFocused = true
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(focusDuration: $selectedDuration, isPomodoro: $isPomodoro)
        }
        .sheet(isPresented: $showTimePicker) {
            // For now, re-using standard TimePickerSheet or a new specialized one if needed.
            // Screenshot implies a simple time wheel. Let's use the existing TimePickerSheet for now 
            // but wrapped to look like the "Anytime" sheet request.
            // Or create a quick inline one. Let's create a dedicated one.
            AnytimePickerSheet()
        }
        .sheet(isPresented: $showDetailedView) {
            DetailedNewTaskView(onTaskCreated: {
                dismiss()
            })
                .environmentObject(taskStore)
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                selectedEmoji = emoji
                showEmojiPicker = false
            }
            .presentationDetents([.fraction(0.35)])
        }
    }
    
    private func createQuickTask() {
        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let finalName: String
        if selectedEmoji.isEmpty || trimmed.hasPrefix(selectedEmoji) {
            finalName = trimmed
        } else {
            finalName = "\(selectedEmoji) \(trimmed)"
        }
        
        let newTask = TaskItem(
            name: finalName,
            focusDurationMinutes: selectedDuration,
            isIntervalTimer: isPomodoro, // Map "Pomodoro" UI toggle to interval timer logic
            isAnytime: isAnytime
        )
        taskStore.add(task: newTask)
        taskStore.selectTask(newTask.id)
        dismiss()
    }
}
