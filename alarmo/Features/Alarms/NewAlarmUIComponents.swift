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
    var sunrayScale: CGFloat = 1.0
    
    var body: some View {
        Group {
            switch settingsStore.alarmClockStyle {
            case .classicSunray:
                SunRayTimePickerView(
                    hour: $hour,
                    minute: $minute,
                    second: $second,
                    sizeMultiplier: sunrayScale
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

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    @AppStorage("is12HourFormat") private var is12HourFormat: Bool = true
    @State private var isDragging = false
    @State private var showWheelPicker = false

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
    private let ringSize: CGFloat = 186
    private let ringWidth: CGFloat = 36
    private let alarmRingBlue = Color(red: 0.08, green: 0.78, blue: 0.92)
    private var tiimoWeekdayPurple: Color { Colors.accentBlue }

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

    private var wakeUpTimeValueLabel: String {
        if is12HourFormat {
            return "\(centerTimeLabel) \(periodLabel)"
        }
        return centerTimeLabel
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

    private var isLightMode: Bool {
        switch settingsStore.themeMode {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return colorScheme == .light
        }
    }

    private var isTiimo: Bool {
        settingsStore.alarmThemeStyle.usesTiimoLayoutBranch
    }

    private var ringAccentColor: Color {
        isTiimo ? tiimoWeekdayPurple : alarmRingBlue
    }

    private var ringGradientColors: [Color] {
        [
            ringAccentColor.opacity(0.62),
            ringAccentColor.opacity(0.96),
            ringAccentColor.opacity(0.78),
            ringAccentColor.opacity(0.80)
        ]
    }

    private var innerCircleGradientColors: [Color] {
        if isTiimo {
            return [
                Colors.saleBadgeEnd.opacity(0.98),
                Colors.accentBlue.opacity(0.96),
                Colors.accentTeal.opacity(0.95)
            ]
        }
        return [
            (isLightMode ? Color(hex: "#F4F2FF") : Color(hex: "#C7C4F8")).opacity(0.98),
            (isLightMode ? Color(hex: "#B7B3EE") : Color(hex: "#8E8BC3")).opacity(0.92),
            (isLightMode ? Color(hex: "#807EA8") : Color(hex: "#5B5A86")).opacity(0.90)
        ]
    }

    private var centerAlarmIconColor: Color {
        isTiimo ? .white : Colors.textSecondary
    }

    private var centerTimeTextColor: Color {
        isTiimo ? .white : Colors.textPrimary
    }

    private var topReferenceLabel: String {
        is12HourFormat ? "12AM" : "00"
    }

    private var rightReferenceLabel: String {
        is12HourFormat ? "6AM" : "06"
    }

    private var bottomReferenceLabel: String {
        is12HourFormat ? "12PM" : "12"
    }

    private var leftReferenceLabel: String {
        is12HourFormat ? "6PM" : "18"
    }

    var body: some View {
        VStack(spacing: 36) {
            Text(timeLabel)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(Colors.accentTeal.opacity(0.92))
                .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .stroke(Colors.cardStroke.opacity(isLightMode ? 1.0 : 0.9), lineWidth: ringWidth)
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

                dialReferenceLabels

                Circle()
                    .fill(
                        RadialGradient(
                            colors: innerCircleGradientColors,
                            center: .center,
                            startRadius: 16,
                            endRadius: 110
                        )
                    )
                    .frame(width: ringSize * 0.62, height: ringSize * 0.62)
                    .overlay(
                        Circle()
                            .stroke(Colors.cardStroke, lineWidth: 1.2)
                    )
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(centerAlarmIconColor)
                            Text(centerTimeLabel)
                                .font(.system(size: is12HourFormat ? 34 : 31, weight: .black, design: .monospaced))
                                .foregroundColor(centerTimeTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .frame(maxWidth: ringSize * 0.46)
                            if !periodLabel.isEmpty {
                                Text(periodLabel)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .onTapGesture {
                        showWheelPicker = true
                    }

                knobView

                HStack {
                    formatButton(title: "12H", isSelected: is12HourFormat) {
                        is12HourFormat = true
                    }

                    Spacer()

                    formatButton(title: "24H", isSelected: !is12HourFormat) {
                        is12HourFormat = false
                    }
                }
                .frame(width: ringSize + 160)
            }
            // Keep frame wide enough so side format buttons remain fully tappable.
            .frame(width: ringSize + 170, height: ringSize + 20)
            .overlay {
                // Restrict drag gesture hit-testing to a ring band (not the center)
                // so the center time remains tappable and side 12H/24H buttons work.
                Circle()
                    .stroke(Color.white.opacity(0.001), lineWidth: ringWidth + 28)
                    .frame(width: ringSize + 20, height: ringSize + 20)
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
            }

            Button {
                showWheelPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text("Wake up at")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.accentTeal.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)

                    Text(wakeUpTimeValueLabel)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textSecondary.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: ringSize + 20)
                .lineLimit(1)
            }
            .buttonStyle(.plain)

        }
        .frame(height: 332)
        .sheet(isPresented: $showWheelPicker) {
            focusDialWheelSheet
        }
    }

    private var dialReferenceLabels: some View {
        let axisOffset = ringSize * 0.30
        let sideLabelExtraOffset = ringSize * 0.045

        return ZStack {
            VStack(spacing: 2) {
                Text(topReferenceLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary.opacity(0.92))
                Image(systemName: "moon.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Colors.accentTeal.opacity(0.9))
            }
            .offset(y: -axisOffset)

            Text(leftReferenceLabel)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary.opacity(0.92))
                .offset(x: -(axisOffset + sideLabelExtraOffset), y: 0)

            Text(rightReferenceLabel)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary.opacity(0.92))
                .offset(x: axisOffset + sideLabelExtraOffset, y: 0)

            VStack(spacing: 2) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Colors.accentTeal.opacity(0.9))
                Text(bottomReferenceLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary.opacity(0.92))
            }
            .offset(y: axisOffset)
        }
        .allowsHitTesting(false)
    }

    private var knobView: some View {
        let angle = Angle.degrees((progress * 360) - 90)
        let radius = (ringSize - ringWidth) / 2

        return Circle()
            .fill(ringGradientColors[1].opacity(0.95))
            .frame(width: ringWidth * 0.8, height: ringWidth * 0.8)
            .overlay(
                Image(systemName: "alarm.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Colors.textPrimary.opacity(isDragging ? 1.0 : 0.95))
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
                                .stroke(isSelected ? Colors.accentTeal.opacity(0.45) : Colors.cardStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var focusDialWheelSheet: some View {
        ZStack {
            Colors.bgPrimary
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
                            .background(isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isLightMode ? Color.black.opacity(0.04) : Color.white.opacity(0.08))
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
    private let suggestedEmojis = ["🌞", "⏰", "🔥", "💪", "🚀", "🎯", "⭐️", "😴"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    Button(action: { showEmojiPicker = true }) {
                        Text(emoji)
                            .font(.system(size: 48))
                            .frame(width: 100, height: 100)
                            .background(Colors.cardSurface)
                            .clipShape(Circle())
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    }
                    
                    TextField("Alarm Name", text: $name)
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Emoji (multiple supported)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        TextField("🌞⏰", text: $emoji)
                            .font(.system(size: 22))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                            .foregroundColor(Colors.textPrimary)

                        HStack(spacing: 10) {
                            ForEach(suggestedEmojis, id: \.self) { item in
                                Button(item) {
                                    emoji += item
                                }
                                .font(.system(size: 26))
                            }
                        }

                        Button("Remove Emoji") {
                            emoji = ""
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                    }
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
                .padding(.leading, 12)
                .padding(.trailing, 4)
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
