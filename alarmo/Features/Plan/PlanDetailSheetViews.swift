import SwiftUI

struct DateSelectionSheet: View {
    @Binding var date: Date
    @Binding var isAnytime: Bool
    @Binding var hasTime: Bool
    @Binding var duration: TimeInterval?
    @Environment(\.dismiss) var dismiss
    
    // Local State
    @State private var tempDate: Date = Date()
    @State private var tempIsAnytime: Bool = true
    @State private var tempHasTime: Bool = false
    @State private var tempTimeMode: Int = 0 // 0: Point, 1: Period
    @State private var tempEndTime: Date = Date().addingTimeInterval(3600)
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Button("Save") {
                        date = tempDate
                        isAnytime = tempIsAnytime
                        hasTime = tempHasTime
                        
                        if !tempIsAnytime {
                             // If anytime is false, ensure we save the date components
                        } else {
                            // If anytime is true, usually date is just today/selected day without time significance
                        }
                        
                        // Sync Has Time Logic
                        if tempHasTime {
                            isAnytime = false // Force specific
                            if tempTimeMode == 1 {
                                let diff = tempEndTime.timeIntervalSince(tempDate)
                                duration = diff > 0 ? diff : 3600
                            } else {
                                duration = nil
                            }
                        }
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        Text(timeTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Month/Year
                        Text(monthYearString(tempDate))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Calendar Grid
                        DatePicker("", selection: $tempDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .accentColor(PlanPalette.accent) 
                        
                        // Quick Action Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                quickActionChip("Today") { tempDate = Date() }
                                quickActionChip("Tomorrow") { 
                                    if let d = Calendar.current.date(byAdding: .day, value: 1, to: Date()) { tempDate = d }
                                }
                                quickActionChip("Next Monday") { tempDate = nextMonday() }
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider().padding(.vertical)
                        
                        // Time Selection
                        VStack(alignment: .leading, spacing: 20) {
                            Toggle("Specified time", isOn: $tempHasTime)
                                .toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                            
                            if tempHasTime {
                                Picker("Time Mode", selection: $tempTimeMode) {
                                    Text("Point time").tag(0)
                                    Text("Time period").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .padding(.bottom, 8)
                                
                                if tempTimeMode == 0 {
                                    DatePicker("", selection: $tempDate, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.wheel)
                                        .labelsHidden()
                                } else {
                                    // Time Period Layout (Start TO End)
                                    VStack(alignment: .center, spacing: 16) {
                                        VStack(spacing: 4) {
                                            Text("Start Time")
                                                .font(.subheadline)
                                                .foregroundColor(Colors.textSecondary)
                                            DatePicker("Start Time", selection: $tempDate, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.wheel)
                                                .labelsHidden()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 120)
                                                .clipped()
                                        }
                                        
                                        Image(systemName: "arrow.down")
                                            .font(.title2)
                                            .foregroundColor(PlanPalette.accent)
                                        
                                        VStack(spacing: 4) {
                                            Text("End Time")
                                                .font(.subheadline)
                                                .foregroundColor(Colors.textSecondary)
                                            DatePicker("End Time", selection: $tempEndTime, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.wheel)
                                                .labelsHidden()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 120)
                                                .clipped()
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .background(Colors.cardSurface.opacity(0.3))
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            tempDate = date
            tempIsAnytime = isAnytime
            tempHasTime = hasTime
            if let dur = duration {
                tempTimeMode = 1
                tempEndTime = date.addingTimeInterval(dur)
            } else {
                tempEndTime = date.addingTimeInterval(3600)
            }
        }
    }
    
    // ... Helpers ...
    private func quickActionChip(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .planGlassPanel(cornerRadius: 16)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        }
    }
    
    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
    
    private var timeTitle: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if tempHasTime {
            if tempTimeMode == 1 {
                return "\(f.string(from: tempDate)) of the day"
            }
            return "Do it at \(f.string(from: tempDate)) of the day"
        }
        return "Do it anytime"
    }
    
    private func nextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        var daysToAdd = 0
        if weekday == 2 { daysToAdd = 7 }
        else if weekday < 2 { daysToAdd = 2 - weekday }
        else { daysToAdd = 9 - weekday }
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}

struct ReminderSelectionSheet: View {
    @Binding var isEnabled: Bool
    @Binding var time: Date
    @Binding var offset: TimeInterval
    var eventTime: Date? // Optional event time to calculate relative reminders
    @Environment(\.dismiss) var dismiss
    
    // Local State
    @State private var tempIsEnabled: Bool = false
    @State private var tempTime: Date = Date()
    @State private var tempOffset: TimeInterval = 0
    
    let offsets: [(title: String, val: TimeInterval)] = [
        ("At time of event", 0),
        ("10 mins before", 600),
        ("30 mins before", 1800),
        ("1 hour before", 3600),
        ("1 day before", 86400)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 32) {
                    // Title
                    Text("Remind me at \(timeString)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 96)
                        .padding(.top, 20)
                    
                    // Toggle
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "bell.fill").font(.title2)
                                Text("Reminder").font(.title3).fontWeight(.semibold)
                            }
                            Text("Set a specific time to remind me")
                                .font(.subheadline)
                                .foregroundColor(Colors.textPrimary.opacity(0.80))
                        }
                        Spacer()
                        Toggle("", isOn: $tempIsEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                    }
                    .padding(.horizontal)
                    
                    if tempIsEnabled {
                        // Time Picker
                        DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .padding(.horizontal)
                        
                        // Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(offsets, id: \.title) { item in
                                    Button(action: { 
                                        tempOffset = item.val
                                        if let event = eventTime {
                                            if item.val == 0 {
                                                 tempTime = event
                                            } else {
                                                 tempTime = event.addingTimeInterval(-item.val)
                                            }
                                        }
                                    }) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(tempOffset == item.val ? Colors.textPrimary : Colors.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                tempOffset == item.val
                                                ? AnyShapeStyle(
                                                    LinearGradient(
                                                        colors: [PlanPalette.accentSoft, PlanPalette.accentStrong],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                : AnyShapeStyle(Colors.cardSurface)
                                            )
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(
                                                        tempOffset == item.val
                                                        ? PlanPalette.accent.opacity(0.55)
                                                        : Colors.cardStroke,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isEnabled = tempIsEnabled
                        time = tempTime
                        offset = tempOffset
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                }
            }
        }
        .onAppear {
            tempIsEnabled = isEnabled
            tempTime = time
            tempOffset = offset
        }
    }
    
    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: tempTime)
    }
}

struct GoalSelectionSheet: View {
    @Binding var isEnabled: Bool
    @Binding var mode: Int // 0: Timer, 1: Count
    @Binding var targetMinutes: Int
    @Binding var targetSeconds: Int
    @Binding var targetCount: Int
    @Binding var targetUnit: String
    
    @Environment(\.dismiss) var dismiss
    
    // Local State
    @State private var tempIsEnabled = false
    @State private var tempMode = 0
    @State private var tempMinutes = 0
    @State private var tempSeconds = 0
    @State private var tempCount = 1
    @State private var tempUnit = "times"
    
    @State private var showNumberPad = false
    @State private var showUnitPicker = false
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "arrow.left").foregroundColor(Colors.textPrimary) }
                    Spacer()
                    Button("Save") { 
                        isEnabled = tempIsEnabled
                        mode = tempMode
                        targetMinutes = tempMinutes
                        targetSeconds = tempSeconds
                        targetCount = tempCount
                        targetUnit = tempUnit
                        dismiss() 
                    }.font(.headline).foregroundColor(Colors.textPrimary)
                }.padding()
                
                VStack(spacing: 32) {
                    HStack {
                        Image(systemName: "target").font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text("Goal").font(.title2).fontWeight(.bold)
                            Text("Set a tracking goal for your task").font(.subheadline).foregroundColor(Colors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $tempIsEnabled).labelsHidden().toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                    }.padding(.horizontal)
                    
                    if tempIsEnabled {
                        Picker("Mode", selection: $tempMode) {
                            Text("Timer").tag(0)
                            Text("Count").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if tempMode == 0 {
                            // TIMER MODE (Wheel Pickers)
                            HStack(spacing: 20) {
                                VStack {
                                    Picker("", selection: $tempMinutes) {
                                        ForEach(0...120, id: \.self) { 
                                            Text("\($0)")
                                                .foregroundColor(Colors.textPrimary)
                                                .tag($0) 
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 80, height: 100)
                                    .planGlassPanel(cornerRadius: 16)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.cardStroke, lineWidth: 1)
                                    )
                                    .clipped()
                                    
                                    Text("Minutes").foregroundColor(Colors.textSecondary)
                                }
                                
                                VStack {
                                    Picker("", selection: $tempSeconds) {
                                        ForEach(0...59, id: \.self) { 
                                            Text(String(format: "%02d", $0))
                                                .foregroundColor(Colors.textPrimary)
                                                .tag($0) 
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 80, height: 100)
                                    .planGlassPanel(cornerRadius: 16)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.cardStroke, lineWidth: 1)
                                    )
                                    .clipped()
                                    
                                    Text("Seconds").foregroundColor(Colors.textSecondary)
                                }
                            }
                        } else {
                            // COUNT MODE
                            HStack(spacing: 32) {
                                // Goal Number Input
                                Button(action: { showNumberPad = true }) {
                                    VStack(spacing: 12) {
                                        Text("\(tempCount)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                            .frame(width: 140, height: 80)
                                            .planGlassPanel(cornerRadius: 16, fillOpacity: 0.11)
                                        
                                        Text("Goal")
                                            .font(.headline)
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // Unit Selection
                                Button(action: { showUnitPicker = true }) {
                                    VStack(spacing: 12) {
                                        Text(tempUnit)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                            .frame(width: 140, height: 80)
                                            .planGlassPanel(cornerRadius: 16, fillOpacity: 0.11)
                                        
                                        Text("Unit")
                                            .font(.headline)
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 20)
                        }
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showNumberPad) {
            NumberInputSheet(value: $tempCount)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showUnitPicker) {
            UnitSelectionSheet(selectedUnit: $tempUnit)
                .presentationDetents([.medium])
        }
        .onAppear {
            tempIsEnabled = isEnabled
            tempMode = mode
            tempMinutes = targetMinutes
            tempSeconds = targetSeconds
            tempCount = targetCount
            tempUnit = targetUnit
        }
    }
}

// MARK: - Helper Sheets for Count Mode

struct NumberInputSheet: View {
    @Binding var value: Int
    @Environment(\.dismiss) var dismiss
    
    // Keypad layout
    let rows = [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
        ["backspace", "0", "checkmark"]
    ]
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PlanPalette.textPrimary)
                            .font(.title2)
                    }
                    Spacer()
                    Text("Count")
                        .font(.headline)
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                    Spacer().frame(width: 24) // Balance
                }
                .padding()
                
                // Display
                Text("\(value)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(PlanPalette.textPrimary)
                    .padding(.vertical, 20)
                
                // Keypad
                VStack(spacing: 16) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(row, id: \.self) { key in
                                Button(action: { handleKey(key) }) {
                                    ZStack {
                                        if key == "checkmark" {
                                            Color(red: 0.13, green: 0.74, blue: 0.84)
                                        } else if key == "backspace" {
                                            Color.white.opacity(0.18)
                                        } else {
                                            Color.white.opacity(0.12)
                                        }
                                    }
                                    .cornerRadius(16)
                                    .frame(height: 70)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                                    .overlay(
                                        Group {
                                            if key == "checkmark" {
                                                Image(systemName: "checkmark").foregroundColor(.white).font(.title)
                                            } else if key == "backspace" {
                                                Image(systemName: "delete.left").foregroundColor(PlanPalette.textPrimary).font(.title2)
                                            } else {
                                                Text(key).font(.title).fontWeight(.bold).foregroundColor(PlanPalette.textPrimary)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private func handleKey(_ key: String) {
        if key == "checkmark" {
            dismiss()
        } else if key == "backspace" {
            value = value / 10
        } else {
            if let num = Int(key) {
                if value == 0 { value = num }
                else if value < 1000 { // Limit
                    value = value * 10 + num
                }
            }
        }
    }
}

struct UnitSelectionSheet: View {
    @Binding var selectedUnit: String
    @Environment(\.dismiss) var dismiss
    
    let units = ["times", "glasses", "$", "pages", "meter", "km", "groups", "steps", "grams", "kg", "books", "kcal", "oz", "ml", "L", "Custom"]
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PlanPalette.textPrimary)
                            .font(.title2)
                    }
                    Spacer()
                    Button("Save") { dismiss() }
                        .font(.headline)
                        .foregroundColor(PlanPalette.textPrimary)
                }
                .padding()
                
                Text("Unit selection")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(PlanPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(units, id: \.self) { unit in
                        Button(action: { selectedUnit = unit }) {
                            Text(unit)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(selectedUnit == unit ? .white : PlanPalette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    selectedUnit == unit
                                    ? Color(red: 0.13, green: 0.74, blue: 0.84)
                                    : Color.white.opacity(0.10)
                                )
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

struct TagSelectionSheet: View {
    @Binding var selectedTag: String?
    @Environment(\.dismiss) var dismiss
    
    @State private var tempTag: String? = nil
    @AppStorage("customUserTagsList") private var customTagsString: String = ""
    @State private var showAddAlert = false
    @State private var newTagName = ""
    
    // Mock tags
    let defaultTags = ["Morning Routine", "Workout", "Clean Room", "Healthy Lifestyle", "Sleep Better", "Relationship"]
    
    var allTags: [String] {
        let custom = customTagsString.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var combined = defaultTags
        for c in custom {
            if !combined.contains(c) {
                combined.append(c)
            }
        }
        if let sel = tempTag, !combined.contains(sel) {
            combined.append(sel)
        }
        return combined
    }
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "arrow.left").foregroundColor(Colors.textPrimary) }
                    Spacer()
                    Button("Save") { 
                        selectedTag = tempTag
                        dismiss() 
                    }.font(.headline).foregroundColor(Colors.textPrimary)
                }.padding()
                
                Text("Tag").font(.largeTitle).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading).padding()
                
                List {
                    Button { tempTag = nil } label: {
                        HStack {
                            Text("No tag").foregroundColor(Colors.textPrimary)
                            Spacer()
                            if tempTag == nil {
                                Image(systemName: "circle.inset.filled").foregroundColor(Colors.textPrimary)
                            } else {
                                Image(systemName: "circle").foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(tempTag == nil ? PlanPalette.accent.opacity(0.3) : Colors.bgSecondary)
                    
                    ForEach(allTags, id: \.self) { tag in
                        Button { tempTag = tag } label: {
                            HStack {
                                Text(tag).foregroundColor(Colors.textPrimary)
                                Spacer()
                                // Just simple selection
                                if tempTag == tag {
                                    Image(systemName: "checkmark").foregroundColor(Colors.textPrimary)
                                }
                            }
                        }
                        .listRowBackground(tempTag == tag ? Colors.bgSecondary : Colors.bgPrimary)
                    }
                }
                .scrollContentBackground(.hidden)
                
                Button(action: { showAddAlert = true }) {
                    Text("Add New")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Colors.bgSecondary)
                        .cornerRadius(30)
                }
                .padding()
                .alert("New Tag", isPresented: $showAddAlert) {
                    TextField("Tag name", text: $newTagName)
                    Button("Cancel", role: .cancel) {
                        newTagName = ""
                    }
                    Button("Add") {
                        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            if !allTags.contains(trimmed) {
                                var currentCustom = customTagsString.components(separatedBy: "|").filter { !$0.isEmpty }
                                currentCustom.append(trimmed)
                                customTagsString = currentCustom.joined(separator: "|")
                            }
                            // Auto-select the newly added tag
                            tempTag = trimmed
                        }
                        newTagName = ""
                    }
                } message: {
                    Text("Enter a name for your new tag.")
                }
            }
        }
        .onAppear {
            tempTag = selectedTag
        }
    }
}

// Re-add RepeatSelectionSheet from previous step (shortened for brevity but keeping it complete)
struct RepeatSelectionSheet: View {
    @Binding var frequency: RepeatFrequency
    @Binding var interval: Int
    @Binding var weekdays: Set<Int>
    @Binding var endDate: Date?
    @Environment(\.dismiss) var dismiss
    
    @State private var tempIsRepeatOn: Bool = false
    @State private var tempIntervalType: Int = 0 
    @State private var tempInterval: Int = 1
    @State private var tempHasEndDate: Bool = false
    @State private var tempEndDate: Date = Date()
    @State private var showIntervalPicker: Bool = false
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "arrow.left").foregroundColor(Colors.textPrimary) }
                    Spacer()
                    Button("Save") {
                        if !tempIsRepeatOn { 
                            frequency = .none 
                        } else {
                            switch tempIntervalType { 
                            case 0: frequency = .daily 
                            case 1: frequency = .weekly 
                            case 2: frequency = .monthly 
                            default: frequency = .daily
                            }
                        }
                        interval = tempInterval
                        if tempHasEndDate { 
                            endDate = tempEndDate 
                        } else {
                            endDate = nil
                        }
                        dismiss()
                    }.font(.headline).foregroundColor(Colors.textPrimary)
                }.padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title
                        Text(titleString)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "repeat")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Repeat")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Text("Set a cycle for your plan").font(.subheadline).foregroundColor(Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $tempIsRepeatOn)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                        }
                        .padding(.horizontal)
                        
                        if tempIsRepeatOn {
                            // Custom Segmented Control
                            HStack(spacing: 0) {
                                SegmentButton(title: "Daily", isSelected: tempIntervalType == 0) { tempIntervalType = 0 }
                                SegmentButton(title: "Weekly", isSelected: tempIntervalType == 1) { tempIntervalType = 1 }
                                SegmentButton(title: "Monthly", isSelected: tempIntervalType == 2) { tempIntervalType = 2 }
                            }
                            .planGlassPanel(cornerRadius: 16) // Light gray bg
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Interval Picker Row
                            VStack(spacing: 0) {
                                Button(action: { withAnimation { showIntervalPicker.toggle() } }) {
                                    HStack {
                                        Text("Interval")
                                            .font(.headline)
                                            .foregroundColor(Colors.textPrimary)
                                        Spacer()
                                        Text("Every \(tempInterval) \(intervalUnit)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Colors.textPrimary)
                                        Image(systemName: showIntervalPicker ? "chevron.up" : "chevron.down")
                                            .foregroundColor(Colors.textSecondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Colors.bgPrimary)
                                }
                                
                                if showIntervalPicker {
                                    Divider()
                                    Picker("", selection: $tempInterval) {
                                        ForEach(1...30, id: \.self) { i in
                                            Text("\(String(format: "%02d", i))").tag(i)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 120)
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider().padding(.horizontal)
                            
                            // End Date Row
                            VStack(spacing: 0) {
                                HStack {
                                    Text("End Date")
                                        .font(.headline)
                                        .foregroundColor(Colors.textPrimary)
                                    Spacer()
                                    Toggle("", isOn: $tempHasEndDate)
                                        .labelsHidden()
                                        .toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                                }
                                .padding()
                                
                                if tempHasEndDate {
                                    DatePicker("", selection: $tempEndDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            tempIsRepeatOn = frequency != .none
            tempInterval = interval
            
            switch frequency {
            case .weekly: tempIntervalType = 1
            case .monthly: tempIntervalType = 2
            default: tempIntervalType = 0
            }
            
            if let end = endDate {
                tempHasEndDate = true
                tempEndDate = end
            }
        }
    }
    
    private var titleString: String {
        if !tempIsRepeatOn { return "Repeat is off" }
        let unit = intervalUnit
        if tempInterval == 1 {
            return "Repeats every \(dayUnit)"
        } else {
            return "Repeats every \(tempInterval) \(unit)s"
        }
    }
    
    private var intervalUnit: String {
        switch tempIntervalType {
        case 0: return "day"
        case 1: return "week"
        case 2: return "month"
        default: return "day"
        }
    }
    
    private var dayUnit: String {
        switch tempIntervalType {
        case 0: return "day"
        case 1: return "week"
        case 2: return "month"
        default: return "day"
        }
    }
}

struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? PlanPalette.accent.opacity(0.3) : Color.clear) // Light green for selected
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct TimeSelectionSheet: View {
    @Binding var date: Date
    @Binding var hasTime: Bool
    @Binding var duration: TimeInterval?
    @Environment(\.dismiss) var dismiss
    
    // Local State
    @State private var tempDate: Date = Date()
    @State private var tempHasTime: Bool = false
    @State private var tempTimeMode: Int = 0 // 0: Point, 1: Period
    @State private var tempEndTime: Date = Date()
    @State private var activeTab: Int = 0 // 0: Start, 1: End
    
    var body: some View {
        ZStack {
            PlanGlassBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Button("Save") {
                        date = tempDate
                        hasTime = tempHasTime
                        
                        if tempHasTime && tempTimeMode == 1 {
                            // Calculate duration
                            let diff = tempEndTime.timeIntervalSince(tempDate)
                            duration = diff > 0 ? diff : 3600
                        } else if tempHasTime && tempTimeMode == 0 {
                            duration = nil
                        }
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Dynamic Title
                        Text(titleString)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    // Custom Icon Logic for "Specified time"
                                    ZStack {
                                        Circle()
                                            .fill(Color.black) // As per image
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "clock.fill") // Or just L shape
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Specified time")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Text("Set a specific time to do it")
                                    .font(.subheadline)
                                    .foregroundColor(Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $tempHasTime)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: PlanPalette.accent))
                        }
                        .padding(.horizontal)
                        
                        if tempHasTime {
                            // Segmented Control
                            Picker("Time Mode", selection: $tempTimeMode) {
                                Text("Point time").tag(0)
                                Text("Time period").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            // Pickers
                            if tempTimeMode == 0 {
                                DatePicker("", selection: $tempDate, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(height: 180)
                                    .clipped()
                            } else {
                                VStack(spacing: 24) {
                                    HStack(spacing: 40) {
                                        Button(action: { activeTab = 0 }) {
                                            VStack(spacing: 8) {
                                                Text("START")
                                                    .font(.caption)
                                                    .foregroundColor(activeTab == 0 ? PlanPalette.accent : Colors.textSecondary)
                                                Text(formatTime(tempDate))
                                                    .font(.title2)
                                                    .fontWeight(activeTab == 0 ? .bold : .regular)
                                                    .foregroundColor(activeTab == 0 ? PlanPalette.accent : Colors.textPrimary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("-")
                                            .font(.title)
                                            .foregroundColor(Colors.textSecondary)
                                        
                                        Button(action: { activeTab = 1 }) {
                                            VStack(spacing: 8) {
                                                Text("END")
                                                    .font(.caption)
                                                    .foregroundColor(activeTab == 1 ? PlanPalette.accent : Colors.textSecondary)
                                                Text(formatTime(tempEndTime))
                                                    .font(.title2)
                                                    .fontWeight(activeTab == 1 ? .bold : .regular)
                                                    .foregroundColor(activeTab == 1 ? PlanPalette.accent : Colors.textPrimary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.top, 16)
                                    
                                    if activeTab == 0 {
                                        DatePicker("", selection: $tempDate, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.wheel)
                                            .labelsHidden()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(height: 180)
                                            .clipped()
                                    } else {
                                        DatePicker("", selection: $tempEndTime, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.wheel)
                                            .labelsHidden()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .frame(height: 180)
                                            .clipped()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            tempDate = date
            tempHasTime = hasTime
            
            if let dur = duration {
                tempTimeMode = 1
                tempEndTime = date.addingTimeInterval(dur)
            } else {
                tempTimeMode = 0
                tempEndTime = date.addingTimeInterval(3600)
            }
        }
    }
    
    private var titleString: String {
        if !tempHasTime {
            return "Do it at any time of the day"
        }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if tempTimeMode == 1 {
            return "Do it from \(f.string(from: tempDate)) to \(f.string(from: tempEndTime)) of the day"
        } else {
            return "Do it at \(f.string(from: tempDate)) of the day"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
