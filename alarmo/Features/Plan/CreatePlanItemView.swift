import SwiftUI
import SwiftData

struct CreatePlanItemView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var type: PlanItemType = .task
    @State private var iconName: String = "circle"
    @State private var tintKey: String = "blue"
    
    @State private var isAnytime: Bool = true
    @State private var scheduledDate: Date = Date()
    @State private var hasTime: Bool = false
    
    @State private var isFocusMode: Bool = false
    @State private var focusMinutes: Int = 25
    @State private var enableIntervals: Bool = false
    @State private var sessions: Int = 4
    @State private var shortBreak: Int = 5
    @State private var longBreak: Int = 25
    
    @State private var missionType: String = "none"
    @State private var missionTarget: String = ""
    
    // Repeat State
    @State private var repeatFrequency: RepeatFrequency = .none
    @State private var repeatInterval: Int = 1
    @State private var repeatWeekdays: Set<Int> = [] // 1=Sun, 2=Mon...
    @State private var repeatEndDate: Date?
    
    // Reminder State
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Date()
    @State private var reminderOffset: TimeInterval = 0 // 0 = At time of event
    @State private var reminderRingtone: Ringtone = .systemDefault
    
    // NEW HABIT STATE
    @State private var habitIntent: HabitIntent = .build
    @State private var goalPeriod: GoalPeriod = .dayLong
    @State private var metricKind: MetricKind = .count
    @State private var goalValue: Double = 1

    @State private var goalUnit: String = "times"
    
    @State private var showFocusPicker: Bool = false
    @State private var showMetricPicker: Bool = false
    @State private var showSaveErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""
    
    // Preset Colors
    let presetColors: [(Color, String)] = [
        (PlanPalette.accent, "blue"),
        (PlanPalette.accentStrong, "red"),
        (PlanPalette.accent, "green"),
        (PlanPalette.accentSoft, "orange"),
        (Color.purple, "purple"),
        (Color.cyan, "cyan"),
        (Color.pink, "pink"),
        (Color.yellow, "yellow"),
        (Color.gray, "gray")
    ]
    
    // Preset Icons (SF Symbols)
    let presetIcons: [String] = [
        // Health
        "heart.fill", "bed.double.fill", "drop.fill", "pills.fill", "cross.case.fill", "brain.head.profile", "lungs.fill", "eye.fill", "mouth", "face.smiling",
        // Sports
        "figure.run", "figure.walk", "dumbbell.fill", "figure.yoga", "bicycle", "figure.pool.swim", "sportscourt.fill", "figure.strengthtraining.traditional", "figure.cooldown", "figure.stand",
        // Food/Drink
        "cup.and.saucer.fill", "wineglass.fill", "fork.knife", "carrot.fill", "apple.logo", "birthday.cake.fill", "takeoutbag.and.cup.and.straw.fill",
        // Life/Productivity
        "book.fill", "pencil", "laptopcomputer", "calendar", "clock.fill", "graduationcap.fill", "briefcase.fill", "folder.fill",
        // Lifestyle
        "house.fill", "leaf.fill", "cart.fill", "gamecontroller.fill", "tv.fill", "music.note", "film.fill", "camera.fill", "paintbrush.fill", "hammer.fill",
        // Finance
        "dollarsign.circle.fill", "creditcard.fill", "banknote.fill", "bag.fill"
    ]
    
    var editingItem: PlanItem?
    var templateItem: PlanItem? // New: For pre-filling from a template
    var parentTask: PlanItem?
    var onSave: ((PlanItem) -> Void)?
    var onStartFocus: (() -> Void)?
    
    @Namespace private var intentNamespace
    
    // Time Goal Bindings (Helpers to avoid compiler complexity)
    private var hoursBinding: Binding<Int> {
        Binding(
            get: { Int(goalValue) / 60 },
            set: { goalValue = Double($0 * 60 + (Int(goalValue) % 60)) }
        )
    }
    
    private var minutesBinding: Binding<Int> {
        Binding(
            get: { Int(goalValue) % 60 },
            set: { goalValue = Double((Int(goalValue) / 60 * 60) + $0) }
        )
    }
    
    init(editingItem: PlanItem? = nil, templateItem: PlanItem? = nil, parentTask: PlanItem? = nil, onSave: ((PlanItem) -> Void)? = nil, onStartFocus: (() -> Void)? = nil) {
        self.editingItem = editingItem
        self.templateItem = templateItem
        self.parentTask = parentTask
        self.onSave = onSave
        self.onStartFocus = onStartFocus
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: 32, height: 32)
                                .planGlassPanel(cornerRadius: 16)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                        }
                    }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        initiateSave()
                    }) {
                        Text("Save")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.24))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                }
                }
        }
        .onAppear { loadInitialData() }
        .sheet(isPresented: $showAddSubtask) { subtaskSheet }
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sheet(isPresented: $showTimePicker) { timePickerSheet }
        .sheet(isPresented: $showRepeatPicker) { repeatPickerSheet }
        .sheet(isPresented: $showReminderPicker) { reminderPickerSheet }
        .sheet(isPresented: $showTagPicker) { tagPickerSheet }
        .sheet(isPresented: $showGoalPicker) { goalPickerSheet }
        .sheet(isPresented: $showFocusPicker) { focusPickerSheet }
        .sheet(isPresented: $showMetricPicker) {
             MetricSelectionSheet(metricKind: $metricKind, unit: $goalUnit)
                .presentationDetents([.medium, .large])
        }
        .alert("Connect Apple Health?", isPresented: $showHealthAlert) {
            Button("Connect") {
                Task {
                    if let key = pendingHealthKey {
                         _ = await HealthKitManager.shared.requestAuthorization(for: key)
                    }
                    await completeSave(shouldDismiss: pendingShouldDismiss, onComplete: pendingOnComplete)
                }
            }
            Button("Cancel", role: .cancel) {
                Task {
                    await completeSave(shouldDismiss: pendingShouldDismiss, onComplete: pendingOnComplete)
                }
            }
        } message: {
            if let key = pendingHealthKey {
                Text("Would you like to sync your \(key) data from Apple Health?")
            } else {
                Text("Would you like to sync your data from Apple Health?")
            }
        }
        .alert("Connect Apple Health?", isPresented: $showHealthAlert) {
            Button("Connect") {
                Task {
                    if let key = pendingHealthKey {
                         _ = await HealthKitManager.shared.requestAuthorization(for: key)
                    }
                    await completeSave(shouldDismiss: pendingShouldDismiss, onComplete: pendingOnComplete)
                }
            }
            Button("Cancel", role: .cancel) {
                Task {
                    await completeSave(shouldDismiss: pendingShouldDismiss, onComplete: pendingOnComplete)
                }
            }
        } message: {
            if let key = pendingHealthKey {
                if HealthKitManager.shared.isAuthorized(for: key) {
                     Text("Apple Health is already connected for \(key). Determine if you want to sync data for this habit.")
                } else {
                     Text("Would you like to sync your \(key) data from Apple Health? Requires permission.")
                }
            } else {
                Text("Would you like to sync your data from Apple Health?")
            }
        }
        .alert("Couldn't Save Item", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    @ViewBuilder
    private var formContent: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        settingsSection
                        
                        if type == .habit {
                            habitGoalSection
                        } else {
                            taskGoalSection
                        }
                        
                        if type == .habit || isFocusMode {
                            focusSection
                            intervalTimerSection
                        }
                        
                        missionsChipSection
                        
                        if let onStartFocus = onStartFocus {
                            Button(action: {
                                initiateSave(shouldDismiss: false, onComplete: onStartFocus)
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                    Text("Start Focus")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(PlanPalette.accent)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .shadow(color: PlanPalette.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Sheet Content Wrappers
    
    private var subtaskSheet: some View {
        CreatePlanItemView(parentTask: targetParentForSubtask ?? editingItem, onSave: { newSub in
            handleNewSubtask(newSub)
        })
        .presentationDetents([.large])
    }
    
    private var datePickerSheet: some View {
        DateSelectionSheet(date: $scheduledDate, isAnytime: $isAnytime, hasTime: $hasTime, duration: $scheduledDuration)
            .presentationDetents([.large])
    }
    
    private var timePickerSheet: some View {
        TimeSelectionSheet(date: $scheduledDate, hasTime: $hasTime, duration: $scheduledDuration)
            .presentationDetents([.large])
    }
    
    private var repeatPickerSheet: some View {
        RepeatSelectionSheet(frequency: $repeatFrequency, interval: $repeatInterval, weekdays: $repeatWeekdays, endDate: $repeatEndDate)
            .presentationDetents([.large])
    }
    
    private var reminderPickerSheet: some View {
        ReminderSelectionSheet(isEnabled: $reminderEnabled, time: $reminderTime, offset: $reminderOffset, eventTime: hasTime ? scheduledDate : nil)
            .presentationDetents([.medium, .large])
    }
    
    private var tagPickerSheet: some View {
        TagSelectionSheet(selectedTag: $tag)
            .presentationDetents([.medium, .large])
    }
    
    private var goalPickerSheet: some View {
        GoalSelectionSheet(isEnabled: $goalEnabled, mode: $goalMode, targetMinutes: $goalMinutes, targetSeconds: $goalSeconds, targetCount: $goalCount, targetUnit: $goalUnit)
            .presentationDetents([.medium, .large])
    }
    
    // NEW FOCUS SHEET
    private var focusPickerSheet: some View {
        FocusSelectionSheet(isEnabled: $isFocusMode, mode: $goalMode, minutes: $focusMinutes, targetCount: $goalCount, targetUnit: $goalUnit)
            .presentationDetents([.medium, .large])
    }

    private func loadInitialData() {
        if let item = editingItem ?? templateItem {
            title = item.title
            subtitle = item.subtitle ?? ""
            type = item.type
            iconName = item.iconName
            tintKey = item.tintKey
            isAnytime = item.anytime
            if let date = item.scheduledDate {
                scheduledDate = date
                if item.scheduledTime != nil { hasTime = true }
            }
            
            if let dur = item.defaultDurationSeconds {
                 focusMinutes = dur / 60
            }
            enableIntervals = item.intervalTimerEnabled
            if let sets = item.intervalSettings {
                sessions = sets.sessionsPerCycle
                shortBreak = sets.shortBreakMinutes
                longBreak = sets.longBreakMinutes
            }
            
            missionType = item.mission.type
            missionTarget = item.mission.targetValue ?? ""
            
            repeatFrequency = item.repeatRule.frequency
            repeatInterval = item.repeatRule.interval
            repeatWeekdays = item.repeatRule.weekdays ?? []
            repeatEndDate = item.repeatRule.endDate
            
            if let _ = item.scheduledTime, !item.anytime, item.reminderEnabled {
                reminderEnabled = true 
                reminderTime = item.scheduledTime ?? Date()
                reminderOffset = item.reminderOffset ?? 0
                reminderRingtone = item.ringtone ?? .systemDefault
            }
            
            if item.type == .habit || item.type == .focusSession {
                habitIntent = item.habitIntent ?? .build
                goalPeriod = item.goalPeriod ?? .dayLong
                metricKind = item.metricKind ?? .count
                goalValue = item.goalValue
                goalUnit = item.goalUnit
                goalValue = item.goalValue
                goalUnit = item.goalUnit
                
                if item.goalValue == 1.0 && item.defaultDurationSeconds != nil {
                     // Migration or specific case
                     // metricKind = .time // already loaded if set, but if it was default .count...
                }

                // Sync Focus State
                if let dur = item.defaultDurationSeconds {
                    isFocusMode = true
                    focusMinutes = dur / 60
                    if focusMinutes == 0 { focusMinutes = 25 } 
                    goalMode = 0 // Timer
                } else {
                    isFocusMode = false
                    focusMinutes = 25
                    goalMode = 0 
                }
                
                // goalMode/Minutes/Count are for Task Goal UI, but for Habit Goal we use metricKind/goalValue
                // We don't need to sync goalMode for Habit anymore as it's handled by metricKind picker
            } else {
                if let dur = item.defaultDurationSeconds {
                    scheduledDuration = TimeInterval(dur)
                    if dur > 0 {
                        if item.mission.type == "goal_count" {
                            goalEnabled = true
                            goalMode = 1
                            let parts = item.mission.targetValue?.split(separator: "|")
                            if let parts = parts, parts.count == 2 {
                                goalCount = Int(parts[0]) ?? 1
                                goalUnit = String(parts[1])
                            }
                        } else {
                            goalEnabled = true
                            goalMode = 0
                            goalMinutes = dur / 60
                            goalSeconds = dur % 60
                        }
                    }
                }
            }
            tag = item.tags.first
        } else {
            if type == .habit {
                repeatFrequency = .daily
                metricKind = .count
                goalUnit = "times"
            }
        }
    }

    private func handleNewSubtask(_ newSub: PlanItem) {
        if let target = targetParentForSubtask {
            target.subtasks.append(newSub)
            newSub.parentTask = target
            modelContext.insert(newSub)
        } else if let parent = editingItem {
            parent.subtasks.append(newSub)
            newSub.parentTask = parent
            modelContext.insert(newSub)
        } else {
            tempSubtasks.append(newSub)
        }
    }
    
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showRepeatPicker = false

    @State private var showReminderPicker = false
    @State private var showTagPicker = false
    @State private var showGoalPicker = false
    @State private var showAddSubtask = false 
    @State private var tempSubtasks: [PlanItem] = [] 
    @State private var targetParentForSubtask: PlanItem? = nil // New state
    
    @State private var tag: String? = nil
    @State private var goalEnabled = false
    @State private var goalMode = 0 // 0: Timer, 1: Count
    @State private var goalMinutes = 20
    @State private var goalSeconds = 0
    @State private var goalCount = 1

    @State private var scheduledDuration: TimeInterval? = nil
    
    // HealthKit Alert States
    @State private var showHealthAlert = false
    @State private var pendingHealthKey: String? = nil
    @State private var pendingShouldDismiss = true
    @State private var pendingOnComplete: (() -> Void)? = nil
    

    
    private func detectHealthKey() -> String? {
        if type != .habit { return nil }
        let t = title.lowercased()
        let u = goalUnit.lowercased()
        
        // 1. Steps
        if u.contains("step") {
            if t.contains("run") || t.contains("jog") || t.contains("marathon") || t.contains("sprint") {
                return "running"
            }
            return "steps"
        }
        
        // 2. Distance (Cycling, Running, Walking)
        // Check for common distance units
        let distUnits = ["km", "mi", "m", "meter", "metre", "mile", "kilometer", "kilometre"]
        // Check if 'u' implies any of these (contains or equals)
        // Simplest is to check if 'u' starts with or equals
        let isDistance = distUnits.contains { u.hasPrefix($0) || u == $0 + "s" }
        
        if isDistance {
            if t.contains("cycle") || t.contains("bike") || t.contains("ride") || t.contains("spin") {
                 return "cycling"
            } else if t.contains("run") || t.contains("jog") || t.contains("marathon") || t.contains("sprint") {
                 return "running"
            }
            return "distance"
        }
        
        // 3. Time (Sleep, Stand)
        if u.contains("hour") || u == "h" || u == "hr" {
            if t.contains("sleep") || t.contains("nap") {
                return "sleep"
            } else if t.contains("stand") {
                return "standing"
            }
        }
        
        // 4. Mindfulness (Time/Minutes)
        if (u.contains("min") || u == "m") && (t.contains("meditat") || t.contains("mindful") || t.contains("breath")) {
            return "mindfulness"
        }
        
        return nil
    }

    private func initiateSave(shouldDismiss: Bool = true, onComplete: (() -> Void)? = nil) {
        if let key = detectHealthKey() {
            pendingHealthKey = key
            pendingShouldDismiss = shouldDismiss
            pendingOnComplete = onComplete
            showHealthAlert = true
        } else {
            Task {
                await completeSave(shouldDismiss: shouldDismiss, onComplete: onComplete)
            }
        }
    }

    // ... existing saveItem ...
    private func completeSave(shouldDismiss: Bool = true, onComplete: (() -> Void)? = nil) async {
        // Use pending key or re-detect
        let detectedHealthKey = pendingHealthKey ?? detectHealthKey()
        
        // Note: Authorization Request is handled by Alert in initiateSave flow

        // Normal Save Logic
        if let existing = editingItem {
            // Update
            existing.title = sanitizedTitle
            existing.subtitle = subtitle.isEmpty ? nil : subtitle
            existing.type = type
            existing.iconName = iconName
            existing.tintKey = tintKey
            existing.anytime = isAnytime
            existing.updatedAt = Date()
            
            if !isAnytime {
               existing.scheduledDate = scheduledDate
               if hasTime {
                   existing.scheduledTime = scheduledDate
               } else {
                   existing.scheduledTime = nil
               }
            } else {
               existing.scheduledDate = nil
               existing.scheduledTime = nil
            }
            
            existing.reminderEnabled = reminderEnabled
            if reminderEnabled {
                existing.scheduledTime = reminderTime
                existing.reminderOffset = reminderOffset > 0 ? reminderOffset : nil
            } else {
                existing.reminderOffset = nil
            }
            existing.ringtone = reminderRingtone // Save ringtone
            
            // Save New Habit Fields
            if type == .habit {
                existing.habitIntent = habitIntent
                existing.goalPeriod = goalPeriod
                existing.metricKind = metricKind
                existing.goalValue = goalValue
                existing.goalUnit = goalUnit
                existing.ringtone = reminderRingtone
                
                // Update Health Tracking
                existing.autoHealthTracking = detectedHealthKey
                
                // Focus Settings
                if isFocusMode {
                    existing.defaultDurationSeconds = focusMinutes * 60
                    existing.intervalTimerEnabled = enableIntervals
                    if enableIntervals {
                        existing.intervalSettings = IntervalTimerSettings(
                            focusMinutes: focusMinutes,
                            sessionsPerCycle: sessions,
                            shortBreakMinutes: shortBreak,
                            longBreakMinutes: longBreak
                        )
                    } else {
                        existing.intervalSettings = nil
                    }
                } else {
                    existing.defaultDurationSeconds = nil
                    existing.intervalTimerEnabled = false
                    existing.intervalSettings = nil
                }
            }
            
            existing.repeatRule = RepeatRule(
                frequency: repeatFrequency,
                interval: repeatInterval,
                weekdays: repeatWeekdays.isEmpty ? nil : repeatWeekdays,
                dayOfMonth: nil,
                endDate: repeatEndDate
            )
            
            if enableIntervals && isFocusMode {
                existing.intervalSettings = IntervalTimerSettings(
                    focusMinutes: focusMinutes,
                    sessionsPerCycle: sessions,
                    shortBreakMinutes: shortBreak,
                    longBreakMinutes: longBreak
                )
            } else {
                existing.intervalSettings = nil
            }
            
            existing.tags = tag != nil ? [tag!] : []
            
            if type != .habit {
                if goalEnabled {
                    if goalMode == 0 {
                        existing.defaultDurationSeconds = (goalMinutes * 60) + goalSeconds
                    } else {
                         // Count mode
                         existing.defaultDurationSeconds = nil
                         if let duration = scheduledDuration, duration > 0 {
                             existing.defaultDurationSeconds = Int(duration)
                         }
                         existing.mission = MissionRequirement(type: "goal_count", targetValue: "\(goalCount)|\(goalUnit)")
                    }
                } else {
                    if let duration = scheduledDuration, duration > 0 {
                        existing.defaultDurationSeconds = Int(duration)
                    } else {
                        existing.defaultDurationSeconds = nil
                    }
                    
                    if existing.mission.type == "goal_count" {
                         existing.mission = MissionRequirement(type: "none")
                    }
                }
            }
            
            // Interval Settings preserve
             if type == .focusSession || type == .habit {
                 existing.intervalTimerEnabled = enableIntervals
                 // ...
             }
             
             // Append new subtasks
             for sub in tempSubtasks {
                 sub.parentTask = existing
                 existing.subtasks.append(sub)
                  modelContext.insert(sub) // Insert subtasks into context
              }
              
              // Schedule Notification for existing item
              PlanNotificationScheduler.shared.schedule(existing)

            PlanNotificationScheduler.shared.schedule(existing)
            do {
                try modelContext.save()
                print("[PlanCreate] Updated item saved. id=\(existing.id) title=\(existing.title) type=\(existing.type.rawValue)")
            } catch {
                print("[PlanCreate] Failed to save updated item: \(error)")
                presentSaveError(error)
                return
            }
            
            onSave?(existing)
            
        } else {
            // Create New
            let newItem = PlanItem(
                title: sanitizedTitle,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                iconName: iconName,
                tintKey: tintKey,
                type: type,
                createdAt: Date(),
                anytime: isAnytime,
                mission: MissionRequirement(
                    type: missionType,
                    targetValue: missionTarget.isEmpty ? nil : missionTarget,
                    difficulty: 0
                )
            )
            
            if let t = tag { newItem.tags.append(t) }
            
            if !isAnytime {
                newItem.scheduledDate = scheduledDate
                if hasTime {
                    newItem.scheduledTime = scheduledDate
                }
            }
            
            newItem.reminderEnabled = reminderEnabled
            if reminderEnabled {
                newItem.scheduledTime = reminderTime
                newItem.reminderOffset = reminderOffset > 0 ? reminderOffset : nil
            }
            newItem.ringtone = reminderRingtone
            
            // Save New Habit Fields
            if type == .habit {
                newItem.habitIntent = habitIntent
                newItem.goalPeriod = goalPeriod
                newItem.metricKind = metricKind
                newItem.goalValue = goalValue
                newItem.goalUnit = goalUnit
                
                // Update Health Tracking
                newItem.autoHealthTracking = detectedHealthKey
                
                if isFocusMode {
                    newItem.defaultDurationSeconds = focusMinutes * 60
                    newItem.intervalTimerEnabled = enableIntervals
                    if enableIntervals {
                        newItem.intervalSettings = IntervalTimerSettings(
                            focusMinutes: focusMinutes,
                            sessionsPerCycle: sessions,
                            shortBreakMinutes: shortBreak,
                            longBreakMinutes: longBreak,
                            autoStartNextSession: true,
                            autoStartNextCycle: false
                        )
                    } else {
                        newItem.intervalSettings = nil
                    }
                } else {
                    newItem.defaultDurationSeconds = nil
                    newItem.intervalTimerEnabled = false
                    newItem.intervalSettings = nil
                }
            }
            
            newItem.repeatRule = RepeatRule(
                frequency: repeatFrequency,
                interval: repeatInterval,
                weekdays: repeatWeekdays.isEmpty ? nil : repeatWeekdays,
                dayOfMonth: nil,
                endDate: repeatEndDate
            )
            
            // Handle Mission
            if missionType != "none" {
                if missionType == "goal_count" {
                     // handled by basic type? No mission is different
                }
                // ... logic
            } else {
                 // default mission?
            }
            
             // Default Mission for Habit if no specific mission set?
            if type == .habit && missionType == "none" {
                if metricKind == .time {
                    newItem.mission = MissionRequirement(type: "goal_time", targetValue: "\(Int(goalValue))")
                } else {
                    if metricKind == .quantity {
                        // Just use count for now or quantity
                    }
                    newItem.mission = MissionRequirement(type: "goal_count", targetValue: "\(goalCount)|\(goalUnit)")
                }
            }
            if type != .habit && type != .focusSession {
                if let duration = scheduledDuration, duration > 0 {
                    newItem.defaultDurationSeconds = Int(duration)
                }
            }
            
            if let parent = parentTask {
                newItem.parentTask = parent
                parent.subtasks.append(newItem)
            }
            
            // Append new temp subtasks to this new items
            for sub in tempSubtasks {
                sub.parentTask = newItem
                newItem.subtasks.append(sub)
                // note: sub items are inserted when newItem is inserted? No, relationships need explicit insert if not cascaded automatically, assuming Cascade on delete, but insert usually cascades.
                modelContext.insert(sub)
            }
            
            // Subtask flows provide onSave and handle persistence externally.
            // Top-level create must persist here to avoid silent loss.
            if parentTask == nil || onSave == nil {
                modelContext.insert(newItem)
                
                // Schedule Notification
                PlanNotificationScheduler.shared.schedule(newItem)
                do {
                    try modelContext.save()
                    print("[PlanCreate] New item saved. id=\(newItem.id) title=\(newItem.title) type=\(newItem.type.rawValue) anytime=\(newItem.anytime) repeat=\(newItem.repeatRule.frequency.rawValue)")
                } catch {
                    print("[PlanCreate] Failed to save new item: \(error)")
                    presentSaveError(error)
                    return
                }
            }
            
            onSave?(newItem)
        }
        
        if shouldDismiss { dismiss() }
    }
    
    // ... helpers ...
    
    
    // ... onAppear Logic ...
    // Note: Since I cannot easily inject onAppear in the same replace block as it is further up in my memory or file structure, I will handle it if possible.
    // Actually, onAppear is inside body. I can't easily replace just that.
    // I will try to target the saveItem first, then a separate replace for onAppear content if needed, but wait, onAppear is at the end of body.
    // The previous tool call ended at line 264. `onAppear` starts around line 266 in original file? No, `onAppear` is at the end of body.
    // Let's replace `saveItem` first.
    
    private func colorFor(_ key: String) -> Color {
        switch key {
        case "blue": return .blue
        case "red": return .red
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

    private var sanitizedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func presentSaveError(_ error: Error) {
        saveErrorMessage = error.localizedDescription
        showSaveErrorAlert = true
    }
    
    // Formatting Helpers
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    private func possibleColor(for key: String) -> Color {
        return presetColors.first(where: { $0.1 == key })?.0 ?? PlanPalette.accent
    }
    // MARK: - Sub-View Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: Spacing.l) {
            // Icon Display
            ZStack {
                Circle()
                    .fill(possibleColor(for: tintKey).opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(possibleColor(for: tintKey))
                    .shadow(color: possibleColor(for: tintKey).opacity(0.3), radius: 10, x: 0, y: 5)
                    .symbolEffect(.bounce, value: iconName)
            }
            .padding(.top, Spacing.m)

            // Title & Subtitle
            VStack(spacing: Spacing.xs) {
                TextField("Habit Name", text: $title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textPrimary)
                    .submitLabel(.done)
                
                Text("Tap to rename")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                    .opacity(title.isEmpty ? 1 : 0.6)
            }
            
            // Color Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(presetColors, id: \.1) { color, key in
                        PlanColorButton(color: color, selected: tintKey == key) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                tintKey = key
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .padding(.bottom, Spacing.m)
    }
    
    
    private var timeRowValue: String {
        if !isAnytime && hasTime {
            if let duration = scheduledDuration, duration > 0 {
                // Formatting for time period
                // We don't have start/end stored separately easily here without calculating
                let end = scheduledDate.addingTimeInterval(duration)
                return "\(formatTime(scheduledDate)) - \(formatTime(end))"
            }
            return formatTime(scheduledDate)
        }
        return "Anytime"
    }

    private var reminderLabel: String {
        guard reminderEnabled else { return "No Reminder" }
        return "At \(formatTime(reminderTime))"
    }

    @ViewBuilder
    private var settingsSection: some View {
        VStack(spacing: Spacing.m) {
            VStack(spacing: 0) {
                PlanSettingsRow(icon: "calendar", title: "Starting from", value: !isAnytime ? formatDate(scheduledDate) : "Today") {
                    showDatePicker = true
                }
                
                Divider().padding(.leading, 56)
                
                PlanSettingsRow(icon: "arrow.triangle.2.circlepath", title: "Repeat", value: repeatFrequency == .none ? "No repeat" : repeatFrequency.rawValue.capitalized) {
                    showRepeatPicker = true
                }
                
                Divider().padding(.leading, 56)
                
                PlanSettingsRow(icon: "clock", title: "Time", value: timeRowValue) {
                    showTimePicker = true
                }
                
                Divider().padding(.leading, 56)
                
                PlanSettingsRow(icon: "bell.fill", title: "Reminder", value: reminderLabel) {
                    showReminderPicker = true
                }
                
                if reminderEnabled {
                    Divider().padding(.leading, 56)
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(possibleColor(for: tintKey))
                            .frame(width: 32, height: 32)
                            .background(possibleColor(for: tintKey).opacity(0.1))
                            .cornerRadius(8)
                        
                        Text("Sound")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                        
                        Spacer()
                        
                        Picker("Ringtone", selection: $reminderRingtone) {
                            Text("Default").tag(Ringtone.systemDefault)
                            Text("Classic").tag(Ringtone.classic)
                            Text("Chirp").tag(Ringtone.chirp)
                            Text("Subtle").tag(Ringtone.subtle)
                        }
                        .pickerStyle(.menu)
                        .tint(Colors.textSecondary)
                    }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                }
                
                Divider().padding(.leading, 56)
                
                PlanSettingsRow(icon: "tag.fill", title: "Tag", value: tag ?? "No tag") {
                    showTagPicker = true
                }
            }
            .planGlassPanel(cornerRadius: 16)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var habitGoalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("GOAL SETTINGS")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textTertiary)
                .padding(.leading, Spacing.m)
            
            VStack(spacing: 0) {
                // Intent Switcher
                HStack(spacing: 0) {
                    ForEach([HabitIntent.build, HabitIntent.quit], id: \.self) { intent in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                habitIntent = intent
                            }
                        }) {
                            Text(intent == .build ? "Build habit" : "Quit habit")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(habitIntent == intent ? Colors.textPrimary : Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    ZStack {
                                        if habitIntent == intent {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Colors.bgSecondary)
                                                .matchedGeometryEffect(id: "intent_bg", in: intentNamespace)
                                                .shadow(color: Colors.shadow.opacity(0.3), radius: 5)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .planGlassPanel(cornerRadius: 12, fillOpacity: 0.08)
                .cornerRadius(16)
                .padding(Spacing.m)
                
                Divider().padding(.horizontal, Spacing.m)
                
                PlanSettingsRow(icon: "calendar.badge.clock", title: "Target Period", value: "Daily") { }
                
                Divider().padding(.leading, 56)
                
                PlanSettingsRow(icon: "chart.bar.fill", title: "Metric Type", value: metricKind == .time ? "Time" : (metricKind == .quantity ? "Quantity" : "Count")) {
                    showMetricPicker = true
                }
                
                Divider().padding(.horizontal, Spacing.m)
                
                // Target Input Area
                VStack(spacing: Spacing.m) {
                    if metricKind == .time {
                        timeGoalPicker
                    } else {
                        quantityGoalInput
                    }
                }
                .padding(Spacing.m)
            }
            .planGlassPanel(cornerRadius: 16)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
        }
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var timeGoalPicker: some View {
        HStack {
            Text("Duration Target")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            
            HStack(spacing: 12) {
                Picker("Hours", selection: hoursBinding) {
                    ForEach(0...23, id: \.self) { Text("\($0)h").tag($0) }
                }
                .pickerStyle(.menu)
                .background(Colors.bgSecondary.opacity(0.5))
                .cornerRadius(8)
                
                Picker("Minutes", selection: minutesBinding) {
                    ForEach(0...59, id: \.self) { Text("\($0)m").tag($0) }
                }
                .pickerStyle(.menu)
                .background(Colors.bgSecondary.opacity(0.5))
                .cornerRadius(8)
            }
            .tint(possibleColor(for: tintKey))
        }
    }

    @ViewBuilder
    private var quantityGoalInput: some View {
        VStack(spacing: Spacing.m) {
            HStack {
                Text(habitIntent == .build ? "Daily Target" : "Daily Limit")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                
                HStack(spacing: 8) {
                    TextField("0", value: $goalValue, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 70, height: 40)
                        .background(Colors.bgSecondary.opacity(0.5))
                        .cornerRadius(10)
                        .foregroundColor(Colors.textPrimary)
                    
                    unitSelectorMenu
                    

                }
            }
            
            // Presets
            let presets = getGoalPresets(for: goalUnit)
            if !presets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { val in
                            Button(action: {
                                withAnimation { goalValue = val }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text("\(Int(val))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(goalValue == val ? possibleColor(for: tintKey) : Colors.bgSecondary.opacity(0.5))
                                    .foregroundColor(goalValue == val ? .white : Colors.textPrimary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }
        }
    }


    


    private var unitSelectorMenu: some View {
        Menu {
            if metricKind == .count {
                ForEach(["times", "reps", "sets", "chapters"], id: \.self) { u in
                    Button(u) { goalUnit = u }
                }
            } else {
                Section("Volume") {
                    ForEach(["ml", "L", "oz", "cups"], id: \.self) { u in Button(u) { goalUnit = u } }
                }
                Section("Distance") {
                    ForEach(["km", "mi", "m", "steps"], id: \.self) { u in Button(u) { goalUnit = u } }
                }
                Section("Other") {
                    ForEach(["pages", "chapters", "g", "kg", "cal"], id: \.self) { u in Button(u) { goalUnit = u } }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(goalUnit)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .background(possibleColor(for: tintKey).opacity(0.1))
            .cornerRadius(10)
        }
    }

    private func getGoalPresets(for unit: String) -> [Double] {
        switch unit {
        case "ml": return [1500, 2000, 2500, 3000, 4000]
        case "L": return [1, 2, 3, 4]
        case "oz": return [64, 80, 100, 128]
        case "steps": return [5000, 7500, 10000, 12500, 15000]
        case "pages": return [5, 10, 20, 50, 100]
        case "times", "reps", "sets": return [1, 3, 5, 10, 15]
        default: return []
        }
    }






    @ViewBuilder
    private var taskGoalSection: some View {
        VStack(spacing: 0) {
            PlanSettingsRow(icon: "target", title: "Task Goal", value: goalEnabled ? (goalMode == 0 ? "\(goalMinutes)m" : "\(goalCount) \(goalUnit)") : "None set") {
                showGoalPicker = true
            }
        }
        .planGlassPanel(cornerRadius: 16)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var focusSection: some View {
        VStack(spacing: 0) {
            PlanSettingsRow(icon: "timer", title: "Focus Timer", value: isFocusMode ? (goalMode == 0 ? "\(focusMinutes) min" : "Counter") : "Off") {
                showFocusPicker = true
            }
        }
        .planGlassPanel(cornerRadius: 16)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var intervalTimerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PlanPalette.accent.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "hourglass.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(PlanPalette.accent)
                }
                
                Text("Interval Timer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $enableIntervals)
                    .labelsHidden()
                    .tint(PlanPalette.accent)
                    .disabled(goalMode != 0)
                    .onChange(of: enableIntervals) { _, newValue in
                        if newValue { isFocusMode = true }
                    }
            }
            .padding(Spacing.m)
            
            if goalMode != 0 {
                Text("Intervals are only available in Timer mode.")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.m)
            } else if enableIntervals {
                Divider().padding(.leading, 56)
                
                VStack(spacing: Spacing.l) {
                    let sessionLen = focusMinutes / max(sessions, 1)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sessions")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Colors.textPrimary)
                            Text("~ \(sessionLen) min / session")
                                .font(.caption2)
                                .foregroundColor(Colors.textTertiary)
                        }
                        Spacer()
                        CustomStepperHelper(value: $sessions, range: 1...12)
                    }
                    
                    HStack {
                        Text("Short Break")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(shortBreak) min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                            CustomStepperHelper(value: $shortBreak, range: 1...30)
                        }
                    }
                    
                    HStack {
                        Text("Long Break")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(longBreak) min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                            CustomStepperHelper(value: $longBreak, range: 5...60)
                        }
                    }
                }
                .padding(Spacing.m)
            }
        }
        .planGlassPanel(cornerRadius: 16)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.m)
    }

    // Concept B: Active Chips Cloud for Missions
    @ViewBuilder
    private var missionsChipSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Spacing.m) {
                 ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PlanPalette.accentSoft.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checklist")
                        .font(.system(size: 16))
                        .foregroundColor(PlanPalette.accentSoft)
                }
                
                Text("Missions")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                let items = editingItem?.subtasks ?? tempSubtasks
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption.bold())
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Colors.bgSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.m)
            
            // Chips Cloud
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add Button
                    Button(action: {
                        targetParentForSubtask = nil
                        showAddSubtask = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Add")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PlanPalette.accent.opacity(0.1))
                        .foregroundColor(PlanPalette.accent)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PlanPalette.accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    // Chips
                    let items = editingItem?.subtasks ?? tempSubtasks
                    ForEach(items) { sub in
                        MissionChip(item: sub)
                    }
                }
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.m)
            }
        }
        .planGlassPanel(cornerRadius: 16)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PlanPalette.accent.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 16))
                        .foregroundColor(PlanPalette.accent)
                }
                
                Text("Subtasks")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    targetParentForSubtask = nil
                    showAddSubtask = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(PlanPalette.accent)
                }
            }
            .padding(Spacing.m)
            
            VStack(alignment: .leading, spacing: 0) {
                let items = editingItem?.subtasks ?? tempSubtasks
                if !items.isEmpty {
                    Divider().padding(.leading, 56)
                    ForEach(items) { sub in
                        SubtaskRow(item: sub, level: 0) { target in
                            targetParentForSubtask = target
                            showAddSubtask = true
                        }
                        .padding(.horizontal, Spacing.m)
                    }
                }
                
                Text(items.isEmpty ? "Add subtasks to break down your goal" : "Tap subtasks to manage detail hierarchy")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.m)
            }
        }
        .planGlassPanel(cornerRadius: 16)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.m)
    }
}

// MARK: - Subviews

struct PlanSettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Colors.textPrimary.opacity(0.05))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textPrimary)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundColor(Colors.textSecondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PlanColorButton: View {
    let color: Color
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if selected {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)
                }
                
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .scaleEffect(selected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct PlanTypePill: View {
    let title: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selected ? Colors.textPrimary : Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? Colors.bgSecondary : Colors.cardSurface)
                )
        }
        .buttonStyle(.plain)
    }
}

// Recursive Subtask Row
struct SubtaskRow: View {
    let item: PlanItem
    let level: Int
    let onAddChild: (PlanItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Self Row
            HStack(spacing: 12) {
                // Indentation Line or Spacer
                if level > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<level, id: \.self) { _ in
                             Rectangle()
                                 .fill(Colors.cardStroke)
                                 .frame(width: 1, height: 24)
                                 .padding(.trailing, 19) // 1 + 19 = 20 spacing
                        }
                    }
                    .frame(height: 24)
                }
                
                // Radio Icon
                Image(systemName: "circle")
                    .foregroundColor(Colors.textSecondary)
                    .font(.system(size: 16))
                
                // Title
                Text(item.title)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Add Child Button (Only show if levels < 3 to prevent infinite nesting issues nicely)
                if level < 2 {
                    Button(action: { onAddChild(item) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.textSecondary)
                            .padding(8)
                            .background(Colors.bgSecondary.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, level == 0 ? 0 : 4) // adjust padding for top level
            
            // Children
            if !item.subtasks.isEmpty {
                ForEach(item.subtasks) { sub in
                    SubtaskRow(item: sub, level: level + 1, onAddChild: onAddChild)
                }
            }
        }
    }
}

struct FocusSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isEnabled: Bool
    @Binding var mode: Int // 0=Timer, 1=Count
    @Binding var minutes: Int
    // Using local binding for seconds if we can't persist it yet
    @State private var seconds: Int = 0 
    
    @Binding var targetCount: Int
    @Binding var targetUnit: String

    var body: some View {
        NavigationView {
            ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 24))
                                .foregroundColor(Colors.textPrimary)
                            Text("Focus")
                                .font(.title3.bold())
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                                .tint(PlanPalette.accent)
                        }
                        .padding()
                        
                        Text("Set a focus timer or counter for your habit.")
                            .font(.subheadline)
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    
                    if isEnabled {
                        Picker("Mode", selection: $mode) {
                            Text("Timer").tag(0)
                            Text("Count").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if mode == 0 {
                            HStack(spacing: 20) {
                                VStack {
                                    Picker("", selection: $minutes) {
                                        ForEach(0...120, id: \.self) { Text("\($0)").tag($0) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 80, height: 80)
                                    .planGlassPanel(cornerRadius: 16)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.cardStroke, lineWidth: 1)
                                    )
                                    .clipped()
                                    
                                    Text("Minutes")
                                        .font(.caption)
                                        .foregroundColor(Colors.textSecondary)
                                }
                                
                                VStack {
                                    Picker("", selection: $seconds) {
                                        ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 80, height: 80)
                                    .planGlassPanel(cornerRadius: 16)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.cardStroke, lineWidth: 1)
                                    )
                                    .clipped()
                                    
                                    Text("Seconds")
                                        .font(.caption)
                                        .foregroundColor(Colors.textSecondary)
                                }
                            }
                            .padding(.vertical)
                            
                        } else {
                            // Count UI
                            HStack {
                                 Text("Starting Value")
                                    .foregroundColor(Colors.textPrimary)
                                 Spacer()
                                 TextField("0", value: $targetCount, format: .number)
                                     .keyboardType(.numberPad)
                                     .multilineTextAlignment(.center)
                                     .frame(width: 80, height: 36)
                                     .background(Colors.bgSecondary.opacity(0.5)).cornerRadius(8)
                                     .foregroundColor(Colors.textPrimary)
                             }
                             .padding()
                             .planGlassPanel(cornerRadius: 16)
                             .cornerRadius(16)
                             .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
            }
        }
    }
}
// MARK: - Components helper
struct CustomStepperHelper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                if value > range.lowerBound {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    value -= 1
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Rectangle()
                .fill(Colors.textSecondary.opacity(0.2))
                .frame(width: 1, height: 16)
            
            Button(action: {
                if value < range.upperBound {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    value += 1
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Colors.bgSecondary)
        .cornerRadius(8)
    }
}

struct MetricSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var metricKind: MetricKind
    @Binding var unit: String
    
    // Suggestion logic
    private let quantityCategories: [(String, [String])] = [
        ("Volume", ["ml", "L", "oz", "cups"]),
        ("Distance", ["km", "mi", "m", "steps"]),
        ("Mass", ["kg", "g", "lbs"]),
        ("Reading", ["pages", "chapters"]),
        ("Other", ["cal"])
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 24) {
                    // Metric Type Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metric Type")
                            .font(.headline)
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            MetricTypeButton(title: "Count", icon: "number", isSelected: metricKind == .count) {
                                metricKind = .count
                                unit = "times"
                            }
                            MetricTypeButton(title: "Time", icon: "clock", isSelected: metricKind == .time) {
                                metricKind = .time
                                unit = "min"
                            }
                            MetricTypeButton(title: "Quantity", icon: "ruler", isSelected: metricKind == .quantity) {
                                metricKind = .quantity
                                unit = "ml" // default
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Unit Selector (Dynamic)
                    if metricKind == .count {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Units")
                                .font(.headline)
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal)
                            
                            WrappableHStack(tags: ["times", "reps", "sets"], selectedTag: $unit)
                                .padding(.horizontal)
                        }
                    } else if metricKind == .quantity {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(quantityCategories, id: \.0) { category, units in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(category)
                                            .font(.subheadline.bold())
                                            .foregroundColor(Colors.textSecondary)
                                        
                                        WrappableHStack(tags: units, selectedTag: $unit)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Time units are fixed to min/hr usually, handled by wheel picker in main view
                        VStack(alignment: .center, spacing: 12) {
                            Spacer()
                            Text("Time is tracked in minutes and hours.")
                                .foregroundColor(Colors.textSecondary)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Select Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Colors.textPrimary)
                }
            }
        }
    }
}

struct MetricTypeButton: View {
    let title: String
    let icon: String // SF Symbol Name
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .padding(.bottom, 4)
                Text(title)
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? PlanPalette.accent.opacity(0.2) : Colors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? PlanPalette.accent : Colors.cardStroke, lineWidth: 2)
            )
            .cornerRadius(12)
            .foregroundColor(isSelected ? PlanPalette.accent : Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// Helper for Flow Layout of Tags
struct WrappableHStack: View {
    let tags: [String]
    @Binding var selectedTag: String
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button(action: {
                    selectedTag = tag
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Text(tag)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTag == tag ? PlanPalette.accent : Colors.bgSecondary)
                        .foregroundColor(selectedTag == tag ? .white : Colors.textPrimary)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Mission Chip (Concept B)
struct MissionChip: View {
    let item: PlanItem
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Colors.bgPrimary.opacity(0.8))
                    .frame(width: 24, height: 24)
                
                Image(systemName: item.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(Colors.textPrimary)
            }
            
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [PlanPalette.accent, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .shadow(color: PlanPalette.accent.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
