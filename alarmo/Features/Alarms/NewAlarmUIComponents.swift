import SwiftUI

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    let value: String
    var showHotBadge: Bool = false
    var thumbnail: Image? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 24)
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Colors.textPrimary)
                
                // Hot Badge
                if showHotBadge {
                    Text("Hot")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Thumbnail
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                        .clipped()
                }
                
                // Value
                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Digital Time Display
struct DigitalTimeDisplay: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int
    @ObservedObject private var settingsStore = SettingsStore.shared
    
    var body: some View {
        Group {
            switch settingsStore.alarmClockStyle {
            case .classicSunray:
                SunRayTimePickerView(
                    hour: $hour,
                    minute: $minute,
                    second: $second
                )
            case .focusDial:
                FocusDialAlarmTimePickerView(
                    hour: $hour,
                    minute: $minute,
                    second: $second
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct FocusDialAlarmTimePickerView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int

    @ObservedObject private var settingsStore = SettingsStore.shared
    @AppStorage("is12HourFormat") private var is12HourFormat: Bool = true
    @State private var isDragging = false
    @State private var showWheelPicker = false

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let ringSize: CGFloat = 248
    private let ringWidth: CGFloat = 36

    private var progress: Double {
        min(max(currentMinutesInCycle / totalMinutesInCycle, 0), 1)
    }

    private var timeLabel: String {
        let displayHour: Int
        if is12HourFormat {
            let hour12 = hour % 12
            displayHour = hour12 == 0 ? 12 : hour12
        } else {
            displayHour = hour
        }
        let period = is12HourFormat ? (hour >= 12 ? " PM" : " AM") : ""
        return String(format: "%02d:%02d%@", displayHour, minute, period)
    }

    private var centerTimeLabel: String {
        let displayHour = is12HourFormat ? ((hour % 12) == 0 ? 12 : (hour % 12)) : hour
        return String(format: "%02d:%02d", displayHour, minute)
    }

    private var periodLabel: String {
        is12HourFormat ? (hour >= 12 ? "PM" : "AM") : ""
    }

    private var totalMinutesInCycle: Double {
        is12HourFormat ? 12 * 60 : 24 * 60
    }

    private var currentMinutesInCycle: Double {
        let hourValue = is12HourFormat ? (hour % 12) : hour
        return Double(hourValue * 60 + minute)
    }

    private var ringGradientColors: [Color] {
        switch settingsStore.alarmFocusRingGradient {
        case .aurora:
            return [
                Color(red: 0.54, green: 0.44, blue: 0.98),
                Color(red: 0.66, green: 0.57, blue: 1.00),
                Color(red: 0.80, green: 0.68, blue: 1.00),
                Color(red: 0.54, green: 0.44, blue: 0.98)
            ]
        case .sunset:
            return [
                Color(red: 0.98, green: 0.50, blue: 0.27),
                Color(red: 0.95, green: 0.28, blue: 0.38),
                Color(red: 0.71, green: 0.29, blue: 0.96),
                Color(red: 0.98, green: 0.50, blue: 0.27)
            ]
        case .ocean:
            return [
                Color(red: 0.10, green: 0.70, blue: 0.94),
                Color(red: 0.07, green: 0.57, blue: 0.86),
                Color(red: 0.00, green: 0.82, blue: 0.76),
                Color(red: 0.10, green: 0.70, blue: 0.94)
            ]
        case .rose:
            return [
                Color(red: 0.98, green: 0.35, blue: 0.63),
                Color(red: 0.93, green: 0.29, blue: 0.45),
                Color(red: 0.82, green: 0.40, blue: 0.96),
                Color(red: 0.98, green: 0.35, blue: 0.63)
            ]
        case .emerald:
            return [
                Color(red: 0.17, green: 0.78, blue: 0.58),
                Color(red: 0.13, green: 0.69, blue: 0.46),
                Color(red: 0.23, green: 0.86, blue: 0.70),
                Color(red: 0.17, green: 0.78, blue: 0.58)
            ]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                formatButton(title: "12H", isSelected: is12HourFormat) {
                    is12HourFormat = true
                }

                Text(timeLabel)
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(Colors.accentTeal.opacity(0.92))
                    .frame(maxWidth: .infinity)

                formatButton(title: "24H", isSelected: !is12HourFormat) {
                    is12HourFormat = false
                }
            }
            .padding(.horizontal, 18)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0.0, to: max(0.01, progress))
                    .stroke(
                        AngularGradient(
                            colors: ringGradientColors,
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringGradientColors[0].opacity(0.46), radius: 10)
                    .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.82), value: progress)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.72, green: 0.74, blue: 0.96).opacity(0.95),
                                Color(red: 0.62, green: 0.65, blue: 0.92).opacity(0.9)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: ringSize * 0.62, height: ringSize * 0.62)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                    )
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.55))
                            Text(centerTimeLabel)
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.68))
                            if !periodLabel.isEmpty {
                                Text(periodLabel)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.52))
                            }
                        }
                    }
                    .onTapGesture {
                        showWheelPicker = true
                    }

                knobView
            }
            .frame(width: ringSize + 20, height: ringSize + 20)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        updateFromDrag(location: value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            HStack(spacing: 8) {
                Button {
                    showWheelPicker = true
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Colors.accentTeal.opacity(0.22)))
                }
                .buttonStyle(.plain)

                Text("Drag ring to set time")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .frame(height: 332)
        .sheet(isPresented: $showWheelPicker) {
            focusDialWheelSheet
        }
    }

    private var knobView: some View {
        let angle = Angle.degrees((progress * 360) - 90)
        let radius = (ringSize - ringWidth) / 2

        return Circle()
            .fill(ringGradientColors[1].opacity(0.95))
            .frame(width: ringWidth * 0.8, height: ringWidth * 0.8)
            .overlay(
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .opacity(isDragging ? 1 : 0)
            )
            .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.85), value: progress)
    }

    private func updateFromDrag(location: CGPoint) {
        let center = CGPoint(x: (ringSize + 20) / 2, y: (ringSize + 20) / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        let fraction = max(0, min(1, angle / (2 * .pi)))
        let maxMinutes = Int(totalMinutesInCycle)
        let snappedMinutes = Int((fraction * totalMinutesInCycle).rounded()) % maxMinutes
        let nextMinute = snappedMinutes % 60

        if is12HourFormat {
            let selectedHour12 = (snappedMinutes / 60) % 12
            let keepPM = hour >= 12
            let nextHour = selectedHour12 + (keepPM ? 12 : 0)
            if nextHour != hour || nextMinute != minute {
                hour = nextHour
                minute = nextMinute
                second = 0
                triggerFeedback()
            }
        } else {
            let nextHour = (snappedMinutes / 60) % 24
            if nextHour != hour || nextMinute != minute {
                hour = nextHour
                minute = nextMinute
                second = 0
                triggerFeedback()
            }
        }
    }

    private func formatButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            triggerFeedback()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? Colors.accentTeal : Colors.textSecondary.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Colors.accentTeal.opacity(0.14) : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Colors.accentTeal.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var focusDialWheelSheet: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        showWheelPicker = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textPrimary.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(height: 44)

                    HStack(spacing: 0) {
                        if is12HourFormat {
                            Picker("Hour", selection: hour12Binding) {
                                ForEach(1...12, id: \.self) { value in
                                    Text(String(format: "%02d", value))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            .onChange(of: hour) { _, _ in triggerFeedback() }
                        } else {
                            Picker("Hour", selection: $hour) {
                                ForEach(0..<24, id: \.self) { value in
                                    Text(String(format: "%02d", value))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            .onChange(of: hour) { _, _ in triggerFeedback() }
                        }

                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60, id: \.self) { value in
                                Text(String(format: "%02d", value))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        .onChange(of: minute) { _, _ in triggerFeedback() }

                        if is12HourFormat {
                            Picker("Period", selection: amPmBinding) {
                                Text("AM").tag(false)
                                Text("PM").tag(true)
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            .onChange(of: hour) { _, _ in triggerFeedback() }
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .colorScheme(.dark)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func triggerFeedback() {
        selectionFeedback.selectionChanged()
        impactFeedback.impactOccurred(intensity: 0.6)
    }

    private var hour12Binding: Binding<Int> {
        Binding(
            get: {
                let h = hour % 12
                return h == 0 ? 12 : h
            },
            set: { newValue in
                let clamped = max(1, min(12, newValue))
                let isPM = hour >= 12
                let normalized = clamped % 12
                hour = normalized + (isPM ? 12 : 0)
                second = 0
            }
        )
    }

    private var amPmBinding: Binding<Bool> {
        Binding(
            get: { hour >= 12 },
            set: { makePM in
                let base = hour % 12
                hour = base + (makePM ? 12 : 0)
                second = 0
            }
        )
    }
}

// MARK: - Sub-Editors (Sheets)

struct LabelSettingsView: View {
    @Binding var name: String
    @Binding var emoji: String
    @Binding var showEmojiPicker: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    Button(action: { showEmojiPicker = true }) {
                        Text(emoji)
                            .font(.system(size: 60))
                            .frame(width: 100, height: 100)
                            .background(Colors.cardSurface)
                            .clipShape(Circle())
                    }
                    
                    TextField("Alarm Name", text: $name)
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
                .navigationTitle("Label")
                .toolbar {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RepeatSettingsView: View {
    @Binding var isDaily: Bool
    @Binding var selectedWeekdays: Set<Int>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                List {
                    Section {
                        Toggle("Daily", isOn: $isDaily)
                            .listRowBackground(Colors.cardSurface)
                    }
                    
                    if !isDaily {
                        Section {
                            ForEach(1...7, id: \.self) { day in
                                Button(action: {
                                    if selectedWeekdays.contains(day) {
                                        selectedWeekdays.remove(day)
                                    } else {
                                        selectedWeekdays.insert(day)
                                    }
                                }) {
                                    HStack {
                                        Text(Calendar.current.weekdaySymbols[day-1])
                                            .foregroundColor(Colors.textPrimary)
                                        Spacer()
                                        if selectedWeekdays.contains(day) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Colors.accentTeal)
                                        }
                                    }
                                }
                                .listRowBackground(Colors.cardSurface)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Repeat")
                .toolbar {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SoundSettingsView: View {
    @Binding var soundName: String
    @Binding var volume: Float
    @Binding var vibrate: Bool
    @Binding var bypassSilentMode: Bool
    // showPicker binding removed; using NavigationLink instead to fix "Two Sheets" bug
    @ObservedObject var soundPlayer: SoundPreviewPlayer
    @Environment(\.dismiss) var dismiss

    private func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    private var isPreviewingSelectedSound: Bool {
        guard let playing = soundPlayer.playingResourceName else { return false }
        return soundPlayer.isPlaying && normalizedTitle(playing) == normalizedTitle(soundName)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    
                    // Sound Name Row with Play Button and Navigation
                    HStack(spacing: 12) {
                        // Play/Stop Button
                        Button(action: {
                            if isPreviewingSelectedSound {
                                soundPlayer.stop()
                            } else {
                                soundPlayer.play(resourceName: soundName, volume: volume)
                            }
                        }) {
                            Image(systemName: isPreviewingSelectedSound ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Colors.accentTeal)
                        }
                        .buttonStyle(.plain)
                        
                        // Picker Link
                        NavigationLink(destination: SoundPickerView(selectedSound: $soundName, soundPlayer: soundPlayer)) {
                            HStack {
                                Text("Sound")
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text(soundName)
                                    .foregroundColor(Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Colors.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                            .padding(.leading)
                        
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(Colors.textSecondary)
                            Slider(value: Binding(
                                get: { volume },
                                set: { newVal in
                                    volume = newVal
                                    if isPreviewingSelectedSound {
                                        soundPlayer.setVolume(newVal) // SoundPreviewPlayer Protocol doesn't have setVolume, checking class...
                                    }
                                }
                            ), in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Toggle(isOn: $vibrate) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(Colors.textPrimary)
                            Text("Vibrate")
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Toggle(isOn: $bypassSilentMode) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(Colors.textPrimary)
                            Text("Ring in Silent Mode")
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .navigationTitle("Alarm Sound")
                .toolbar {
                    Button("Done") {
                        soundPlayer.stop()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Mission Slots View (Multi-Mission)

struct MissionSlotsView: View {
    let missions: [AlarmMission]
    // Use fixed 5 slots per request
    let onAdd: () -> Void
    let onEdit: (Int) -> Void
    let onRemove: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
             if !missions.isEmpty {
                 HStack {
                     Spacer()
                     Text("\(missions.count)/4")
                         .font(.caption)
                         .foregroundColor(Colors.textTertiary)
                 }
                 .padding(.horizontal, 4)
             }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // 1. Existing Missions
                    ForEach(Array(missions.enumerated()), id: \.offset) { index, mission in
                        MissionSlotItem(
                            mission: mission,
                            state: .filled,
                            onTap: { onEdit(index) },
                            onRemove: { onRemove(index) }
                        )
                    }
                    
                    // 2. Add Button (if less than 4)
                     if missions.count < 4 {
                        MissionSlotItem(
                             mission: nil,
                             state: .empty,
                             onTap: onAdd,
                             onRemove: {}
                         )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
    }
}

enum MissionSlotState {
    case filled
    case empty
}

struct MissionSlotItem: View {
    let mission: AlarmMission?
    let state: MissionSlotState
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Container
            VStack(spacing: 8) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(state == .filled ? Colors.cardSurface : Color.clear)
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(state == .filled ? Colors.accentTeal.opacity(0.3) : Colors.textTertiary.opacity(0.2), lineWidth: 1.5)
                        )
                        // Dashed border for empty state
                         .overlay(
                            Group {
                                if state == .empty {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                        .foregroundColor(Colors.textTertiary.opacity(0.4))
                                }
                            }
                        )

                    // Icon
                    if let mission = mission {
                        Image(systemName: mission.iconName) 
                            .font(.system(size: 26))
                            .foregroundColor(Colors.accentTeal)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                
                // Label
                Text(state == .filled && mission != nil ? mission!.title : "Add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(state == .filled ? Colors.textPrimary : Colors.textTertiary)
                    .lineLimit(1)
                    .frame(width: 68)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Remove Button (Badge)
            if state == .filled {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Colors.textSecondary)
                        .font(.system(size: 22))
                }
                .offset(x: 6, y: -6)
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
    }
}
