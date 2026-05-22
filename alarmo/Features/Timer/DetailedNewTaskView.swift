import SwiftUI

struct DetailedNewTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskStore: TaskStore
    private let onTaskCreated: (() -> Void)?
    
    // Form State
    @State private var taskName: String = ""
    @State private var note: String = ""
    @State private var isAnytime: Bool = true
    @State private var isIntervalTimer: Bool = false
    @State private var durationMinutes: Int = 25
    @State private var tags: [String] = [] 
    
    // Interval Specific State
    @State private var sessionsPerCycle: Int = 4
    @State private var shortBreakDuration: Int = 5
    @State private var longBreakDuration: Int = 25
    @State private var autoStartNextSession: Bool = true
    @State private var autoStartNextCycle: Bool = false
    
    // Pickers State
    @State private var showDurationPicker = false
    @State private var showSessionsPicker = false
    @State private var showShortBreakPicker = false
    @State private var showLongBreakPicker = false
    @State private var showTagSelection = false
    @State private var showEmojiPicker = false
    @State private var selectedEmoji: String = ""
    
    // Focus State
    @FocusState private var isNameFocused: Bool

    init(onTaskCreated: (() -> Void)? = nil) {
        self.onTaskCreated = onTaskCreated
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        
                        // Top Section: Icon + Name
                        HStack(spacing: 16) {
                            Button(action: { showEmojiPicker = true }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(TimerPalette.accent)
                                        .frame(width: 50, height: 50)
                                    if selectedEmoji.isEmpty {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text(selectedEmoji)
                                            .font(.system(size: 28))
                                    }
                                }
                            }
                            
                            TextField("Task Name", text: $taskName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .focused($isNameFocused)
                                .submitLabel(.done)
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                        // Section 1: Schedule
                        VStack(spacing: 0) {
                            ToggleRow(title: "Anytime", isOn: $isAnytime)
                            
                            Divider().background(Colors.cardStroke)
                            
                            HStack {
                                Text("Repeat")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text("No Repeat")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            .padding()
                        }
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                        // Section 2: Timer Configuration
                        VStack(spacing: 0) {
                            ToggleRow(title: "Interval Timer", isOn: $isIntervalTimer.animation(.easeInOut))
                            
                            Divider().background(Colors.cardStroke)
                            
                            // Focus Duration (Always visible)
                            HStack {
                                Text("Focus Session Duration")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Button(action: { showDurationPicker = true }) {
                                    Text("\(durationMinutes) min")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Colors.bgSecondary)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            
                            Divider().background(Colors.cardStroke)
                            
                            // Break Duration (Always visible now)
                            HStack {
                                HStack(spacing: 6) {
                                    Text(isIntervalTimer ? "Short Break Duration" : "Break Duration")
                                        .foregroundColor(Colors.textPrimary)
                                    if isIntervalTimer {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                    }
                                }
                                Spacer()
                                Button(action: { showShortBreakPicker = true }) {
                                    Text("\(shortBreakDuration) min")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Colors.bgSecondary)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            
                            if isIntervalTimer {
                                Group {
                                    Divider().background(Colors.cardStroke)
                                    
                                    // Sessions per Cycle
                                    HStack {
                                        HStack(spacing: 6) {
                                            Text("Focus Sessions per Cycle")
                                                .foregroundColor(Colors.textPrimary)
                                            Image(systemName: "crown.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12))
                                        }
                                        Spacer()
                                        Button(action: { showSessionsPicker = true }) {
                                            Text("\(sessionsPerCycle)")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Colors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Colors.bgSecondary)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                    
                                    Divider().background(Colors.cardStroke)
                                    
                                    // Long Break
                                    HStack {
                                        HStack(spacing: 6) {
                                            Text("Long Break Duration")
                                                .foregroundColor(Colors.textPrimary)
                                            Image(systemName: "crown.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12))
                                        }
                                        Spacer()
                                        Button(action: { showLongBreakPicker = true }) {
                                            Text("\(longBreakDuration) min")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Colors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Colors.bgSecondary)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                    
                                    Divider().background(Colors.cardStroke)
                                    
                                    // Auto Start Next Session
                                    HStack {
                                        HStack(spacing: 6) {
                                            Text("Auto-Start Next Session")
                                                .foregroundColor(Colors.textPrimary)
                                            Image(systemName: "questionmark.circle")
                                                .foregroundColor(Colors.textSecondary)
                                                .font(.system(size: 14))
                                        }
                                        Spacer()
                                        Toggle("", isOn: $autoStartNextSession)
                                            .labelsHidden()
                                            .tint(TimerPalette.accent)
                                    }
                                    .padding()
                                    
                                    Divider().background(Colors.cardStroke)
                                    
                                    // Auto Start Next Cycle
                                    HStack {
                                        HStack(spacing: 6) {
                                            Text("Auto-Start Next Cycle")
                                                .foregroundColor(Colors.textPrimary)
                                            Image(systemName: "questionmark.circle")
                                                .foregroundColor(Colors.textSecondary)
                                                .font(.system(size: 14))
                                        }
                                        Spacer()
                                        Toggle("", isOn: $autoStartNextCycle)
                                            .labelsHidden()
                                            .tint(TimerPalette.accent)
                                    }
                                    .padding()
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                        // Section 3: Tags
                        Button(action: { showTagSelection = true }) {
                            HStack {
                                Text("Tags")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                
                                if tags.isEmpty {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Colors.textTertiary)
                                } else {
                                    HStack(spacing: 4) {
                                        ForEach(tags.prefix(3), id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Colors.bgSecondary)
                                                .cornerRadius(8)
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        if tags.count > 3 {
                                            Text("+\(tags.count - 3)")
                                                .font(.caption)
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                        }
                        
                        // Section 4: Note
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text("Add a note")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.textTertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: $note)
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(minHeight: 120)
                            }
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(16)
                        
                    }
                    .padding(Spacing.l)
                }
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TimerPalette.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { createTask() }
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                        .disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showDurationPicker) {
            NumberPickerSheet(title: "Focus Duration", unit: "min", value: $durationMinutes, range: 1...180)
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showSessionsPicker) {
            NumberPickerSheet(title: "Sessions / Cycle", unit: "", value: $sessionsPerCycle, range: 1...12)
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showShortBreakPicker) {
            NumberPickerSheet(title: "Short Break", unit: "min", value: $shortBreakDuration, range: 1...60)
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showLongBreakPicker) {
            NumberPickerSheet(title: "Long Break", unit: "min", value: $longBreakDuration, range: 1...120)
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showTagSelection) {
            TagSelectionView(selectedTags: $tags)
                .environmentObject(taskStore)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                selectedEmoji = emoji
                showEmojiPicker = false
            }
            .presentationDetents([.fraction(0.35)])
        }
    }
    
    private func createTask() {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let finalName: String
        if selectedEmoji.isEmpty || trimmedName.hasPrefix(selectedEmoji) {
            finalName = trimmedName
        } else {
            finalName = "\(selectedEmoji) \(trimmedName)"
        }

        let newTask = TaskItem(
            name: finalName,
            note: note,
            tags: tags,
            focusDurationMinutes: durationMinutes,
            isIntervalTimer: isIntervalTimer,
            isAnytime: isAnytime,
            sessionsPerCycle: sessionsPerCycle,
            shortBreakMinutes: shortBreakDuration,
            longBreakMinutes: longBreakDuration,
            autoStartNextSession: autoStartNextSession,
            autoStartNextCycle: autoStartNextCycle
        )
        
        taskStore.add(task: newTask)
        taskStore.selectTask(newTask.id)
        onTaskCreated?()
        dismiss()
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(TimerPalette.accent)
        }
        .padding()
    }
}
