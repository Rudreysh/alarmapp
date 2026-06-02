import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CreateNoteView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    var itemToEdit: PlanItem?
    var parentTask: PlanItem? // Support for subtasks
    
    // Task State
    @State private var title: String = ""
    @State private var selectedDate: Date? = Date()
    @State private var hasTime: Bool = false
    @State private var priority: PriorityLevel = .none
    @State private var selectedList: String = "Inbox"
    @State private var reminderOffset: ReminderOption = .none
    @State private var repeatOption: RepeatOption = .none
    
    // UI State
    @State private var showDatePicker = false
    @State private var showPriorityMenu = false
    @State private var showListMenu = false
    @State private var showSettings = false // Now "More" menu
    @State private var showAttachmentMenu = false // New
    @State private var showCustomRepeat = false
    @State private var isEditingTags = false // New tag state
    @FocusState private var isFocused: Bool
    @FocusState private var isTagFocused: Bool // New focus state for tag
    
    // Attachment State
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showFileImporter = false
    @State private var showComingSoonAlert = false
    @State private var comingSoonMessage = ""
    @State private var tempImage: UIImage?
    @State private var attachments: [String] = [] // Placeholder for attachment file names/refs
    
    // Tag State
    @State private var tags: [String] = []
    @State private var currentTagInput: String = ""
    
    // Settings persistence
    @AppStorage("note_action_dates") private var actionDates = true
    @AppStorage("note_action_priority") private var actionPriority = true
    @AppStorage("note_action_tag") private var actionTag = true
    @AppStorage("note_action_list") private var actionList = true
    @AppStorage("note_action_attachment") private var actionAttachment = true
    @AppStorage("note_action_template") private var actionTemplate = false
    @AppStorage("note_action_convert") private var actionConvert = false
    @AppStorage("note_action_fullscreen") private var actionFullScreen = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer() 
            
            // Input Container
            VStack(spacing: 0) {
                // Text Input Area OR Tag Input Area
                if isEditingTags {
                    // Tag Input Mode (Image 2)
                    // Tag Input Mode (Image 2)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "tag")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Colors.accentOrange.opacity(0.15))
                                        .foregroundColor(Colors.accentOrange)
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            tags.removeAll { $0 == tag }
                                        }
                                }
                                
                                TextField("Add tag...", text: $currentTagInput)
                                    .font(.system(size: 18))
                                    .frame(minWidth: 80)
                                    .focused($isTagFocused)
                                    .onSubmit {
                                        addTag()
                                    }
                                    .onChange(of: currentTagInput) { _, newValue in
                                        if newValue.hasSuffix(" ") || newValue.hasSuffix(",") {
                                            addTag()
                                        }
                                    }
                            }
                        }
                        
                        Button(action: { isEditingTags = false }) {
                             Image(systemName: "chevron.down")
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .padding(16)
                } else {
                    // Standard Note Input Mode
                    HStack(alignment: .top, spacing: 12) {
                        TextField("What would you like to do?", text: $title, axis: .vertical)
                            .font(.system(size: 20, weight: .regular)) // Slightly larger font
                            .foregroundColor(Colors.textPrimary) // Brighter white text
                            .frame(minHeight: 80) // Taller input area
                            .focused($isFocused)
                            .accentColor(Colors.accentOrange)
                    }
                    .padding(20) // More padding
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isFocused = true
                    }
                }
                
                // Smart Toolbar
                HStack(spacing: 12) {
                    // Date
                    // Date (Pill Style)
                    if actionDates {
                        Button(action: { showDatePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                Text(dateString)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Colors.accentOrange)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Colors.accentOrange.opacity(0.15)) // Subtle orange background
                            .clipShape(Capsule()) // Pill shape
                            .overlay(
                                Capsule()
                                    .stroke(Colors.accentOrange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Priority
                    if actionPriority {
                        Button(action: { showPriorityMenu = true }) {
                            Image(systemName: priority.icon)
                                .font(.system(size: 20)) // Bigger icon
                                .foregroundColor(priority == .none ? Colors.textSecondary : priority.uiColor)
                                .padding(8)
                        }
                    }
                    
                    // Tag (Toggles Tag Mode)
                    if actionTag {
                        Button(action: { 
                            withAnimation { 
                                isEditingTags.toggle()
                                if isEditingTags { isTagFocused = true } else { isFocused = true }
                            }
                        }) {
                            Image(systemName: "tag")
                                .font(.system(size: 20))
                                .foregroundColor(isEditingTags ? Colors.accentOrange : Colors.textSecondary)
                                .padding(8)
                        }
                    }
                    
                    // List
                    if actionList {
                        Menu {
                            Button { selectedList = "Inbox" } label: { Text("Inbox 📥") }
                            Button { selectedList = "Work" } label: { Text("Work 💼") }
                            Button { selectedList = "Personal" } label: { Text("Personal 🏠") }
                            Button { selectedList = "Shopping" } label: { Text("Shopping 🛒") }
                        } label: {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textSecondary)
                                .padding(8)
                        }
                    }
                    
                    // Attachment (New)
                    if actionAttachment {
                        Button(action: { showAttachmentMenu = true }) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 20))
                                .foregroundColor(Colors.textSecondary)
                                .padding(8)
                        }
                    }
                    
                    Spacer()
                    
                    // Settings (More Menu)
                    Button(action: { showSettings = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                            .padding(8)
                    }
                    
                    // Send/Done Button
                    if !title.isEmpty && !isEditingTags {
                         Button(action: saveNote) {
                             Image(systemName: "arrow.up.circle.fill")
                                 .font(.system(size: 28))
                                 .foregroundColor(PlanPalette.accent)
                         }
                         .transition(.scale)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20) // More bottom padding
                .padding(.top, 4)
            }
            .planGlassPanel(cornerRadius: 16) // Use card surface for the panel
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: -5) // Drop shadow for floating effect
            .padding(.horizontal, 0) // Edge to edge or slightly floated? User image shows edge to edge mostly or modal.
        }
        .task {
            // Restore state if editing
            if let item = itemToEdit {
                title = item.title
                selectedDate = item.scheduledDate
                hasTime = item.scheduledTime != nil
                // Case-insensitive matching for priority
                if let p = PriorityLevel(rawValue: item.priority) { 
                    priority = p 
                } else if let p = PriorityLevel(rawValue: item.priority.lowercased()) {
                    priority = p 
                }
                selectedList = item.category
                tags = item.tags
            }
            
            // Delay to allow view transition to complete before requesting focus
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            isFocused = true
        }
        .sheet(isPresented: $showDatePicker) {
            AdvancedDatePickerSheet(
                date: $selectedDate,
                hasTime: $hasTime,
                reminder: $reminderOffset,
                repeatRule: $repeatOption,
                showCustomRepeat: $showCustomRepeat
            )
            .presentationDetents([.fraction(0.85)])
        }
        .sheet(isPresented: $showSettings) {
             NoteToolbarConfigurationSheet()
                 .presentationDetents([.large])
         }
         .sheet(isPresented: $showPriorityMenu) {
             PriorityPickerSheet(selection: $priority)
                 .presentationDetents([.fraction(0.35)])
         }
         .sheet(isPresented: $showAttachmentMenu) {
              AttachmentSheet { action in
                  showAttachmentMenu = false
                  switch action {
                  case .camera: showCamera = true
                  case .photo: showPhotoLibrary = true
                  case .files: showFileImporter = true
                  case .scanDoc, .scanText, .record:
                      comingSoonMessage = "\(action.title) is coming soon!"
                      showComingSoonAlert = true
                  }
              }
              .presentationDetents([.height(350)])
         }
         .sheet(isPresented: $showCamera) {
             ImagePicker(sourceType: .camera) { image in
                 // Handle image selection
             }
         }
         .sheet(isPresented: $showPhotoLibrary) {
             ImagePicker(sourceType: .photoLibrary) { image in
                 // Handle image selection
             }
         }
         .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.content]) { result in
             // Handle file selection
         }
         .alert("Coming Soon", isPresented: $showComingSoonAlert) {
             Button("OK", role: .cancel) { }
         } message: {
             Text(comingSoonMessage)
         }

    }
    
    private var dateString: String {
        guard let date = selectedDate else { return "No Date" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            if hasTime {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return "Today \(f.string(from: date))"
            }
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            if hasTime {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return "Tmw \(f.string(from: date))"
            }
             return "Tomorrow"
        }
        
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        if hasTime {
            let t = DateFormatter()
            t.dateFormat = "HH:mm"
            return "\(f.string(from: date)) \(t.string(from: date))"
        }
        return f.string(from: date)
    }

    
    private func saveNote() {
        let tintKey: String
        switch priority {
        case .high: tintKey = "red"
        case .medium: tintKey = "orange"
        case .low: tintKey = "blue"
        case .none: tintKey = "gray"
        }
        
        // Ensure we are using lowercase raw value for consistency
        let priorityValue = priority.rawValue.lowercased()
        
        if let editingItem = itemToEdit {
            // Update existing item
            editingItem.title = title
            editingItem.tintKey = tintKey
            editingItem.scheduledDate = selectedDate
            editingItem.scheduledTime = hasTime ? selectedDate : nil
            editingItem.category = selectedList
            editingItem.priority = priorityValue
            editingItem.reminderOffset = reminderOffset.timeInterval
            editingItem.tags = tags
            editingItem.anytime = (selectedDate == nil)
            editingItem.updatedAt = Date()
            
            // Re-schedule notification
            NoteNotificationScheduler.cancel(editingItem)
            NoteNotificationScheduler.schedule(editingItem)
            
        } else {
            // Create new item
            let newItem = PlanItem(
                title: title,
                iconName: "circle",
                tintKey: tintKey, // Maps priority to color
                type: .note,
                anytime: selectedDate == nil
            )
            // Set new fields
            newItem.scheduledDate = selectedDate
            newItem.scheduledTime = hasTime ? selectedDate : nil
            newItem.category = selectedList
            newItem.priority = priorityValue
            newItem.reminderOffset = reminderOffset.timeInterval
            newItem.tags = tags
            
            if let parent = parentTask {
                newItem.parentTask = parent
                newItem.type = .task // Subtasks default to task type
                parent.subtasks.append(newItem)
            }
            
            modelContext.insert(newItem)
            NoteNotificationScheduler.schedule(newItem)
        }
        
        try? modelContext.save()
        
        dismiss()
    }
    
    private func addTag() {
        let tag = currentTagInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        currentTagInput = ""
    }
}

// MARK: - Priority Picker Sheet
struct PriorityPickerSheet: View {
    @Binding var selection: PriorityLevel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            VStack {
                Text("Priority").font(.headline).foregroundColor(Colors.textPrimary).padding()
                List {
                    Section {
                        ForEach(PriorityLevel.allCases, id: \.self) { option in
                            Button {
                                selection = option
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: option.icon)
                                        .foregroundColor(option == .none ? Colors.textSecondary : option.uiColor)
                                    Text(option.title)
                                        .foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    if selection == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(PlanPalette.accent)
                                    }
                                }
                            }
                            .listRowBackground(Colors.cardSurface)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}


// MARK: - Notification Manager
struct NoteNotificationScheduler {
    static func schedule(_ item: PlanItem) {
        guard item.reminderOffset != nil, let date = item.scheduledDate, let time = item.scheduledTime else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        guard let dueTime = calendar.date(from: components) else { return }
        
        let triggerDate = dueTime.addingTimeInterval(-(item.reminderOffset ?? 0))
        
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "Reminder: \(item.title)"
        content.sound = .default
        
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    static func cancel(_ item: PlanItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }
}

// MARK: - Enums

enum ReminderOption: String, CaseIterable {
    case none, onTime, min5, min30, hour1, day1
    
    var title: String {
        switch self {
        case .none: return "None"
        case .onTime: return "On time"
        case .min5: return "5 minutes early"
        case .min30: return "30 minutes early"
        case .hour1: return "1 hour early"
        case .day1: return "1 day early"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .none: return nil
        case .onTime: return 0
        case .min5: return 5 * 60
        case .min30: return 30 * 60
        case .hour1: return 60 * 60
        case .day1: return 24 * 60 * 60
        }
    }
}

enum RepeatOption: String, CaseIterable {
    case none, daily, weekly, monthly, yearly, weekday, custom
    
    var title: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekday: return "Every Weekday"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Advanced Date Picker Sheet (And others)
struct AdvancedDatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var date: Date?
    @Binding var hasTime: Bool
    @Binding var reminder: ReminderOption
    @Binding var repeatRule: RepeatOption
    @Binding var showCustomRepeat: Bool
    
    @State private var tempDate: Date = Date()
    @State private var viewMode: Int = 0 // 0: Date, 1: Duration
    @State private var showingReminderSheet = false
    @State private var showingRepeatSheet = false
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    
                    Picker("Mode", selection: $viewMode) {
                        Text("Date").tag(0)
                        Text("Duration").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    
                    Spacer()
                    Button("Done") {
                        date = tempDate
                        dismiss()
                    }
                    .foregroundColor(PlanPalette.accent)
                    .fontWeight(.bold)
                }
                .padding()
                .planGlassPanel(cornerRadius: 16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        DatePicker("", selection: $tempDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .tint(PlanPalette.accent)
                            .colorScheme(.dark)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(PlanPalette.accent)
                                    .frame(width: 24)
                                Text("Time")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                if hasTime {
                                    DatePicker("", selection: $tempDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                    Button(action: { withAnimation { hasTime = false } }) {
                                        Image(systemName: "xmark").foregroundColor(Colors.textSecondary)
                                    }
                                } else {
                                    Button("Set") { withAnimation { hasTime = true } }.foregroundColor(PlanPalette.accent)
                                }
                            }
                            .padding()
                            .planGlassPanel(cornerRadius: 16)
                            
                            Divider().background(Colors.cardStroke).padding(.leading, 40)
                            
                            Button(action: { showingReminderSheet = true }) {
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(hasTime ? PlanPalette.accent : Colors.textSecondary)
                                        .frame(width: 24)
                                    Text("Reminder")
                                        .font(.system(size: 16))
                                        .foregroundColor(hasTime ? Colors.textPrimary : Colors.textSecondary)
                                    Spacer()
                                    Text(reminder.title).foregroundColor(PlanPalette.accent)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(Colors.textSecondary)
                                }
                                .padding()
                                .planGlassPanel(cornerRadius: 16)
                            }
                            
                            Divider().background(Colors.cardStroke).padding(.leading, 40)
                            
                            Button(action: { showingRepeatSheet = true }) {
                                HStack {
                                    Image(systemName: "repeat")
                                        .foregroundColor(Colors.textSecondary)
                                        .frame(width: 24)
                                    Text("Repeat")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    Text(repeatRule.title).foregroundColor(Colors.textSecondary)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(Colors.textSecondary)
                                }
                                .padding()
                                .planGlassPanel(cornerRadius: 16)
                            }
                        }
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Button(action: {
                            date = nil
                            hasTime = false
                            reminder = .none
                            repeatRule = .none
                            dismiss()
                        }) {
                            Text("Clear").foregroundColor(PlanPalette.accent).fontWeight(.medium)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            if let existing = date {
                tempDate = existing
            }
        }
        .sheet(isPresented: $showingReminderSheet) {
            ReminderPickerSheet(selection: $reminder, hasTime: $hasTime)
                 .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingRepeatSheet) {
            RepeatPickerSheet(selection: $repeatRule, showCustomRepeat: $showCustomRepeat)
                 .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCustomRepeat) {
            CustomRepeatView()
                .presentationDetents([.medium, .large])
        }
    }
}

struct ReminderPickerSheet: View {
    @Binding var selection: ReminderOption
    @Binding var hasTime: Bool
    @Environment(\.dismiss) var dismiss
    @State private var constantReminder = false
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            VStack(spacing: 0) {
                 Capsule()
                     .fill(Colors.textSecondary.opacity(0.3))
                     .frame(width: 40, height: 5)
                     .padding(.top, 10)
                 
                 List {
                    Section {
                        ForEach(ReminderOption.allCases, id: \.self) { option in
                            Button {
                                selection = option
                                if option != .none { hasTime = true }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(option.title).foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    if selection == option {
                                        Image(systemName: "checkmark").foregroundColor(PlanPalette.accent)
                                    }
                                }
                            }
                            .listRowBackground(Colors.cardSurface)
                        }
                    }
                    Section {
                         Button { } label: { HStack { Text("Custom").foregroundColor(Colors.textPrimary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(Colors.textSecondary) } }.listRowBackground(Colors.cardSurface)
                         HStack { Text("Constant Reminder").foregroundColor(Colors.textPrimary); Image(systemName: "crown.fill").foregroundColor(.yellow).font(.caption); Spacer(); Toggle("", isOn: $constantReminder).labelsHidden() }.listRowBackground(Colors.cardSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct RepeatPickerSheet: View {
    @Binding var selection: RepeatOption
    @Binding var showCustomRepeat: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            VStack {
                Text("Repeat").font(.headline).foregroundColor(Colors.textPrimary).padding()
                List {
                    Section {
                        ForEach(RepeatOption.allCases.filter { $0 != .custom }, id: \.self) { option in
                            Button { selection = option; dismiss() } label: { HStack { Text(option.title).foregroundColor(Colors.textPrimary); Spacer(); if selection == option { Image(systemName: "checkmark").foregroundColor(PlanPalette.accent) } } }.listRowBackground(Colors.cardSurface)
                        }
                    }
                    Section {
                         Button { showCustomRepeat = true; dismiss() } label: { HStack { Text("Custom").foregroundColor(Colors.textPrimary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(Colors.textSecondary) } }.listRowBackground(Colors.cardSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct CustomRepeatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var frequency: Int = 1
    @State private var intervalType: String = "Week"
    @State private var selectedDays: Set<String> = ["Thu"]
    @State private var repeatType: String = "By Due Dates"
    
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let intervals = ["Day", "Week", "Month", "Year"]
    
    var body: some View {
        NavigationView {
            ZStack {
                PlanGlassBackground()
                VStack(spacing: 24) {
                    HStack {
                        Text("Repeat Type").foregroundColor(Colors.textPrimary).font(.system(size: 16, weight: .medium))
                        Spacer()
                        Menu { Button("By Due Dates") { repeatType = "By Due Dates" }; Button("By Completion Date") { repeatType = "By Completion Date" } } label: { HStack { Text(repeatType).foregroundColor(Colors.textSecondary); Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(Colors.textSecondary) } }
                    }
                    .padding().planGlassPanel(cornerRadius: 16).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Frequency").foregroundColor(Colors.textPrimary).font(.headline)
                        HStack {
                            Text("Every").foregroundColor(Colors.textPrimary).font(.system(size: 16, weight: .medium))
                            Spacer()
                            HStack(spacing: 0) {
                                Picker("Frequency", selection: $frequency) { ForEach(1...99, id: \.self) { num in Text("\(num)").tag(num) } }.pickerStyle(.wheel).frame(width: 60, height: 100)
                                Picker("Interval", selection: $intervalType) { ForEach(intervals, id: \.self) { type in Text(type).tag(type) } }.pickerStyle(.wheel).frame(width: 100, height: 100)
                            }
                        }
                        Text(footerText).foregroundColor(Colors.textSecondary).font(.caption)
                    }
                    .padding().planGlassPanel(cornerRadius: 16).cornerRadius(12)
                    
                    if intervalType == "Week" {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Week").foregroundColor(Colors.textPrimary).font(.headline)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                ForEach(days, id: \.self) { day in
                                    Button(action: { if selectedDays.contains(day) { if selectedDays.count > 1 { selectedDays.remove(day) } } else { selectedDays.insert(day) } }) {
                                        Text(day).font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 8).background(selectedDays.contains(day) ? PlanPalette.accent : Colors.cardSurface).foregroundColor(selectedDays.contains(day) ? .white : Colors.textPrimary).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Colors.cardStroke, lineWidth: selectedDays.contains(day) ? 0 : 1))
                                    }
                                }
                            }
                        }
                        .padding().planGlassPanel(cornerRadius: 16).cornerRadius(12)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Custom Repeat").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(PlanPalette.accent) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundColor(PlanPalette.accent).fontWeight(.bold) }
            }
        }
    }
    
    var footerText: String {
        let interval = frequency == 1 ? intervalType.lowercased() : "\(intervalType.lowercased())s"
        if intervalType == "Week" {
            let sortedDays = days.filter { selectedDays.contains($0) }
            return "Every \(frequency) week on \(sortedDays.joined(separator: ", "))"
        }
        return "Every \(frequency) \(interval)"
    }
}

// MARK: - More Options Sheet (Image 3)


// MARK: - Toolbar Configuration (Rename of old Settings)
struct NoteToolbarConfigurationSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("note_action_dates") private var actionDates = true
    @AppStorage("note_action_priority") private var actionPriority = true
    @AppStorage("note_action_tag") private var actionTag = true
    @AppStorage("note_action_list") private var actionList = true
    @AppStorage("note_action_attachment") private var actionAttachment = true
    @AppStorage("note_action_template") private var actionTemplate = false
    @AppStorage("note_action_convert") private var actionConvert = false
    @AppStorage("note_action_fullscreen") private var actionFullScreen = false
    
     // Local State
    @State private var activeItems: [NoteActionItem] = []
    @State private var availableItems: [NoteActionItem] = []
    
    var body: some View {
        NavigationView {
             ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 0) {
                    // Preview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What would you like to do?")
                            .font(.system(size: 16))
                            .foregroundColor(Colors.textSecondary)
                        
                        HStack(spacing: 12) {
                            ForEach(activeItems) { item in
                                Image(systemName: item.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18))
                                .foregroundColor(Colors.textSecondary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(PlanPalette.accent.opacity(0.5))
                        }
                    }
                    .padding(20)
                    .planGlassPanel(cornerRadius: 16)
                    .cornerRadius(16)
                    .padding()
                    
                    List {
                        Section(header: Text("Edit actions")) {
                            ForEach(activeItems) { item in
                                HStack {
                                    Button(action: { move(item: item, toActive: false) }) {
                                        Image(systemName: "minus.circle.fill").foregroundColor(PlanPalette.accentStrong)
                                    }
                                    .buttonStyle(.plain)
                                    Image(systemName: item.icon).frame(width: 24).foregroundColor(Colors.textPrimary)
                                    Text(item.title).foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "line.3.horizontal").foregroundColor(Colors.textSecondary.opacity(0.5))
                                }
                                .listRowBackground(Colors.cardSurface)
                            }
                            .onMove(perform: moveActiveItem)
                        }
                        
                        Section(header: Text("More")) {
                            ForEach(availableItems) { item in
                                HStack {
                                    Button(action: { move(item: item, toActive: true) }) {
                                        Image(systemName: "plus.circle.fill").foregroundColor(PlanPalette.accent)
                                    }
                                    .buttonStyle(.plain)
                                    Image(systemName: item.icon).frame(width: 24).foregroundColor(Colors.textPrimary)
                                    Text(item.title).foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "line.3.horizontal").foregroundColor(Colors.textSecondary.opacity(0.5))
                                }
                                .listRowBackground(Colors.cardSurface)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(PlanPalette.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(PlanPalette.accent)
                        .fontWeight(.bold)
                }
            }
        }
        .onAppear(perform: loadData)
        .onDisappear(perform: saveData)
    }
    
    private func loadData() {
        var active: [NoteActionItem] = []
        var available: [NoteActionItem] = []
        let allItems = [
            NoteActionItem(id: "dates", title: "Dates", icon: "calendar", key: "note_action_dates"),
            NoteActionItem(id: "priority", title: "Priorities", icon: "flag", key: "note_action_priority"),
            NoteActionItem(id: "tag", title: "Tag", icon: "tag", key: "note_action_tag"),
            NoteActionItem(id: "list", title: "List", icon: "tray.and.arrow.down", key: "note_action_list"),
            NoteActionItem(id: "attachment", title: "Image", icon: "photo", key: "note_action_attachment"),
            NoteActionItem(id: "template", title: "Template", icon: "text.badge.plus", key: "note_action_template"),
            NoteActionItem(id: "convert", title: "Convert to Note", icon: "book", key: "note_action_convert"),
            NoteActionItem(id: "fullscreen", title: "Full-Screen", icon: "arrow.up.left.and.arrow.down.right", key: "note_action_fullscreen")
        ]
        
        if actionDates { active.append(allItems[0]) } else { available.append(allItems[0]) }
        if actionPriority { active.append(allItems[1]) } else { available.append(allItems[1]) }
        if actionTag { active.append(allItems[2]) } else { available.append(allItems[2]) }
        if actionList { active.append(allItems[3]) } else { available.append(allItems[3]) }
        if actionAttachment { active.append(allItems[4]) } else { available.append(allItems[4]) }
        if actionTemplate { active.append(allItems[5]) } else { available.append(allItems[5]) }
        if actionConvert { active.append(allItems[6]) } else { available.append(allItems[6]) }
        if actionFullScreen { active.append(allItems[7]) } else { available.append(allItems[7]) }
        
        self.activeItems = active
        self.availableItems = available
    }
    
    private func saveData() {
        actionDates = activeItems.contains { $0.id == "dates" }
        actionPriority = activeItems.contains { $0.id == "priority" }
        actionTag = activeItems.contains { $0.id == "tag" }
        actionList = activeItems.contains { $0.id == "list" }
        actionAttachment = activeItems.contains { $0.id == "attachment" }
        actionTemplate = activeItems.contains { $0.id == "template" }
        actionConvert = activeItems.contains { $0.id == "convert" }
        actionFullScreen = activeItems.contains { $0.id == "fullscreen" }
    }
    
    private func move(item: NoteActionItem, toActive: Bool) {
        withAnimation {
            if toActive {
                if let index = availableItems.firstIndex(where: { $0.id == item.id }) {
                    availableItems.remove(at: index)
                    activeItems.append(item)
                }
            } else {
                if let index = activeItems.firstIndex(where: { $0.id == item.id }) {
                    activeItems.remove(at: index)
                    availableItems.append(item)
                }
            }
        }
        saveData() 
    }
    private func moveActiveItem(from source: IndexSet, to destination: Int) {
        activeItems.move(fromOffsets: source, toOffset: destination)
        saveData()
    }
}

// MARK: - Attachment Menu Sheet (Image 1)


// MARK: - Attachment Menu Sheet (Image 1)
enum AttachmentAction {
    case camera, photo, record, files, scanDoc, scanText
    
    var title: String {
        switch self {
        case .camera: return "Camera"
        case .photo: return "Photo"
        case .record: return "Record"
        case .files: return "Files"
        case .scanDoc: return "Scan Documents"
        case .scanText: return "Scan Text"
        }
    }
}

struct AttachmentSheet: View {
    @Environment(\.dismiss) var dismiss
    var onAction: (AttachmentAction) -> Void
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            VStack(alignment: .leading, spacing: 0) {
                List {
                    Section {
                        Button { onAction(.camera) } label: { ActionRow(icon: "camera", title: "Camera") }
                        Button { onAction(.photo) } label: { ActionRow(icon: "photo", title: "Photo") }
                        Button { onAction(.record) } label: { ActionRow(icon: "mic", title: "Record") }
                        Button { onAction(.files) } label: { ActionRow(icon: "folder", title: "Files") }
                        Button { onAction(.scanDoc) } label: { ActionRow(icon: "doc.viewfinder", title: "Scan Documents") }
                        Button { onAction(.scanText) } label: { ActionRow(icon: "text.viewfinder", title: "Scan Text") }
                    }
                    .listRowBackground(Colors.cardSurface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    struct ActionRow: View {
        let icon: String
        let title: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(Colors.textPrimary)
                Text(title)
                    .foregroundColor(Colors.textPrimary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Models
struct NoteActionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let key: String
}

