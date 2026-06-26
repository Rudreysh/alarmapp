import SwiftUI
import AudioToolbox

struct SunRayTimePickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Binding var hour: Int
    @Binding var minute: Int
    var second: Binding<Int>? = nil // Optional 3rd value
    
    var topUnit: String = "hr"
    var bottomUnit: String = "min"
    var tertiaryUnit: String = "sec"
    
    var topMax: Int = 23
    var bottomMax: Int = 59
    var tertiaryMax: Int = 59
    
    @State private var hourOffset: CGFloat = 0
    @State private var minuteOffset: CGFloat = 0
    @State private var secondOffset: CGFloat = 0
    
    @State private var isInteracting: Bool = false
    
    @State private var activeComponent: TimeComponent = .hour
    @AppStorage("is12HourFormat") private var is12HourFormat: Bool = false // Persist format preference
    
    // New state for smooth ring dragging
    @State private var dragAngle: Double?
    @State private var lastRawDragAngle: Double?
    
    // New state for precision picker
    @State private var showWheelPicker: Bool = false
    
    // Ring glow pulse animation
    @State private var ringGlowPulse: CGFloat = 0.0
    @State private var lastTickSoundAt: CFAbsoluteTime = 0
    var sizeMultiplier: CGFloat = 1.0
    private var tiimoWeekdayPurple: Color { Colors.accentBlue }
    
    // Base Sunray size. Final size can be increased by `sizeMultiplier`.
    private let baseSize: CGFloat = 214
    private var size: CGFloat { baseSize * max(0.8, sizeMultiplier) }
    private let feedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum TimeComponent {
        case hour
        case minute
        case second
    }
    
    // Computed properties for 12h/24h
    private var isPM: Bool {
        return hour >= 12
    }
    
    private var displayHour: Int {
        if is12HourFormat {
            let h = hour % 12
            return h == 0 ? 12 : h
        } else {
            return hour
        }
    }

    private var hourDialDivisions: Int {
        is12HourFormat ? 12 : 24
    }

    private var accentSunYellow: Color {
        Color(red: 0.98, green: 0.84, blue: 0.30)
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

    private var dialFrameWidth: CGFloat { size + 30 }
    
    var body: some View {
        GeometryReader { geo in
            let sideSlotWidth = max(56, (geo.size.width - dialFrameWidth) / 2)

            HStack(alignment: .center, spacing: 0) {
                twelveHourButton
                    .frame(width: sideSlotWidth)

                VStack(spacing: 8) {
                // Small preview at top (Matching attachment style)
                let hStr = String(format: "%02d", displayHour)
                let mStr = String(format: "%02d", minute)
                let sStr = second != nil ? ":\(String(format: "%02d", second!.wrappedValue))" : ""
                
                let amPm = is12HourFormat ? ( hour >= 12 ? " PM" : " AM" ) : ""
                
                Text("\(hStr):\(mStr)\(sStr)\(amPm)")
                    .font(.system(size: second != nil ? 14 : 18, weight: .heavy, design: .monospaced))
                    .foregroundColor((isTiimo ? tiimoWeekdayPurple : Colors.accentTeal).opacity(0.8))
                    .offset(y: -4) // Slight adjustment to sit just above the ticks

                ZStack {
                    // Background Ticks (Static & Dynamic Color)
                    ZStack {
                        // Outer ambient glow circle (subtle)
                        if !isTiimo {
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [
                                            Colors.accentBlue.opacity(0.10 + ringGlowPulse * 0.05),
                                            Colors.accentTeal.opacity(0.12 + ringGlowPulse * 0.06),
                                            accentSunYellow.opacity(0.09 + ringGlowPulse * 0.04),
                                            Colors.accentBlue.opacity(0.10 + ringGlowPulse * 0.05)
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: 8
                                )
                                .blur(radius: 6)
                                .frame(width: size + 14, height: size + 14)
                        }
                        
                        Circle()
                            .stroke(isTiimo ? Colors.saleBadgeStart : Colors.cardStroke, lineWidth: 1)
                            .frame(width: size, height: size)
                        
                        ForEach(0..<60) { i in
                            // Determine if this tick is "active" based on current value
                            let isActiveTick = isTickActive(index: i)
                            
                            Capsule()
                                .fill(
                                    isActiveTick
                                    ? (isTiimo ? tiimoWeekdayPurple : Colors.accentTeal)
                                    : (isTiimo ? Colors.cardStroke : (isLightMode ? Colors.textSecondary.opacity(i % 5 == 0 ? 0.28 : 0.14) : Color.white.opacity(i % 5 == 0 ? 0.3 : 0.1)))
                                )
                                .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? 10 : 6)
                                .offset(y: -(size/2))
                                .rotationEffect(.degrees(Double(i) * 6))
                                .shadow(color: (isActiveTick && !isTiimo) ? Colors.accentTeal.opacity(0.6) : .clear, radius: 4)
                                .animation(.easeInOut(duration: 0.2), value: activeComponent) // Smooth transition
                        }
                        
                        // Hour markers switch between 12h and 24h layouts.
                        if activeComponent == .hour {
                            ForEach(0..<hourDialDivisions, id: \.self) { i in
                                let angleStep = 360.0 / Double(hourDialDivisions)
                                let label = is12HourFormat
                                    ? (i == 0 ? "12" : "\(i)")
                                    : String(format: "%02d", i)
                                let isCompactLabel = isCompactHourLabel(i)
                                let labelSize: CGFloat = is12HourFormat ? 14 : (isCompactLabel ? 8.5 : 10)
                                let labelLift: CGFloat = is12HourFormat ? 25 : (isCompactLabel ? 24 : 22)

                                Text(label)
                                    .font(.system(size: labelSize, weight: .heavy, design: .monospaced))
                                    .foregroundColor(isHourMatch(i) ? (isTiimo ? tiimoWeekdayPurple : Colors.accentTeal) : Colors.textSecondary)
                                    .shadow(color: (isHourMatch(i) && !isTiimo) ? Colors.accentTeal.opacity(0.5) : .clear, radius: 4)
                                    .scaleEffect(isCompactLabel ? 0.92 : 1.0)
                                    .offset(y: -(size / 2 - labelLift))
                                    .rotationEffect(.degrees(Double(i) * angleStep))
                            }
                        }
                    }
                    .frame(width: size, height: size)
                    
                    // Active Ring Segment — gradient stroke with glow
                    if isTiimo {
                        Circle()
                            .trim(from: 0.0, to: activeProgress())
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        tiimoWeekdayPurple.opacity(0.96),
                                        tiimoWeekdayPurple.opacity(0.94),
                                        Color(hex: "#F6D98A").opacity(0.36),
                                        tiimoWeekdayPurple.opacity(0.95)
                                    ],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                style: StrokeStyle(lineWidth: 6.24, lineCap: .round)
                            )
                            .frame(width: size + 10, height: size + 10)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Color(hex: "#F6D98A").opacity(0.15), radius: 2, x: 0, y: 0)
                            .animation(isInteracting ? .none : .interactiveSpring(response: 0.22, dampingFraction: 0.88), value: activeProgress())
                    } else {
                        Circle()
                            .trim(from: 0.0, to: activeProgress())
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        Colors.accentBlue.opacity(0.62),
                                        Colors.accentTeal.opacity(0.96),
                                        accentSunYellow.opacity(0.10),
                                        Colors.accentBlue.opacity(0.80)
                                    ],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360 * activeProgress())
                                ),
                                style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
                            )
                            .frame(width: size + 10, height: size + 10)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Colors.accentTeal.opacity(isInteracting ? 0.6 : Double(0.25 + ringGlowPulse * 0.15)), radius: isInteracting ? 10 : 5)
                            .animation(isInteracting ? .none : .interactiveSpring(response: 0.22, dampingFraction: 0.88), value: activeProgress())
                    }
                    
                    // User Interaction Layer (Transparent)
                    ZStack {
                        Color.white.opacity(0.001)
                    }
                    .frame(width: size + 30, height: size + 30)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isInteracting {
                                    isInteracting = true
                                    dragAngle = nil
                                    lastRawDragAngle = nil
                                    feedback.prepare()
                                }
                                updateTimeFromDrag(value)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isInteracting = false
                                    dragAngle = nil // Snap back to nearest tick visually
                                    lastRawDragAngle = nil
                                }
                            }
                    )

                    // Rotating hand to make radial selection direction explicit.
                    ZStack {
                        Rectangle()
                            .fill(
                                isTiimo
                                ? LinearGradient(colors: [Colors.saleBadgeStart, tiimoWeekdayPurple], startPoint: .bottom, endPoint: .top)
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.92),
                                        Colors.accentTeal.opacity(0.9),
                                        accentSunYellow.opacity(0.7)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: size * 0.35)
                            .offset(y: -(size * 0.175))
                            .shadow(color: isTiimo ? .clear : Colors.accentTeal.opacity(0.45), radius: 5)

                        Circle()
                            .fill(
                                isTiimo
                                ? LinearGradient(
                                    colors: [Colors.saleBadgeStart, Colors.saleBadgeEnd, tiimoWeekdayPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(isTiimo ? Colors.saleBadgeStart.opacity(0.95) : Color.clear, lineWidth: isTiimo ? 1 : 0)
                            )
                            .shadow(color: isTiimo ? .clear : Color.white.opacity(0.8), radius: 4)
                    }
                    .rotationEffect(.degrees(lineRotationDegrees))
                    .animation(isInteracting ? .none : .interactiveSpring(response: 0.22, dampingFraction: 0.88), value: lineRotationDegrees)
                    .allowsHitTesting(false)
                    
                    // Digital Time Display (Center)
                    VStack(spacing: second != nil ? 6 : 10) {
                        // Top Selector (Hour)
                        UnitSelector(
                            val: Binding(get: { displayHour }, set: { _ in }), // Read-only for display here, updated via drag/tap logic
                            unit: is12HourFormat ? (isPM ? "PM" : "AM") : "", // Hide unit in 24h mode
                            maxVal: topMax, // Not used strictly for display click
                            offset: $hourOffset,
                            isInteracting: $isInteracting,
                            feedback: feedback,
                            fontSize: second != nil ? 32 : 46,
                            unitSize: second != nil ? 14 : 16,
                            isActive: activeComponent == .hour,
                            highlightColor: isTiimo ? tiimoWeekdayPurple : Colors.accentTeal,
                            onTap: {
                                activeComponent = .hour
                                showWheelPicker = true
                            },
                            onScroll: { delta in
                                manualScroll(component: .hour, delta: delta)
                            },
                            onUnitTap: {
                                if is12HourFormat {
                                    if isPM { setAM() } else { setPM() }
                                    triggerFeedback()
                                }
                            }
                        )
                        
                        // Divider
                        Rectangle()
                            .fill(Colors.cardStroke)
                            .frame(width: 80, height: 1)
                        
                        // Middle Selector (Minute)
                        UnitSelector(
                            val: $minute,
                            unit: bottomUnit,
                            maxVal: bottomMax,
                            offset: $minuteOffset,
                            isInteracting: $isInteracting,
                            feedback: feedback,
                            fontSize: second != nil ? 32 : 46,
                            unitSize: second != nil ? 14 : 16,
                            isActive: activeComponent == .minute,
                            highlightColor: isTiimo ? tiimoWeekdayPurple : Colors.accentTeal,
                            onTap: {
                                activeComponent = .minute
                                showWheelPicker = true
                            },
                            onScroll: { delta in
                                manualScroll(component: .minute, delta: delta)
                            }
                        )
                        
                        if let secondBinding = second {
                            // Divider
                            Rectangle()
                                .fill(Colors.cardStroke)
                                .frame(width: 80, height: 1)
                            
                            // Bottom Selector (Second)
                            UnitSelector(
                                val: secondBinding,
                                unit: tertiaryUnit,
                                maxVal: tertiaryMax,
                                offset: $secondOffset,
                                isInteracting: $isInteracting,
                                feedback: feedback,
                                fontSize: 32,
                                unitSize: 14,
                                isActive: activeComponent == .second,
                                highlightColor: isTiimo ? tiimoWeekdayPurple : Colors.accentTeal,
                                onTap: {
                                    activeComponent = .second
                                    showWheelPicker = true
                                },
                                onScroll: { delta in
                                    manualScroll(component: .second, delta: delta)
                                }
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeComponent = .hour
                        showWheelPicker = true
                        triggerFeedback()
                    }
                }
                .frame(width: dialFrameWidth, height: dialFrameWidth)
                }

                twentyFourHourButton
                    .frame(width: sideSlotWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        // Keep enough vertical room so the larger dial never overlaps following UI.
        .frame(height: size + 92)
        .onAppear {
            // Start the breathing glow animation
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                ringGlowPulse = 1.0
            }
        }
        .sheet(isPresented: $showWheelPicker) {
            ZStack {
                Colors.bgPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Close button top-right
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
                    
                    // Wheel Picker Area
                    ZStack {
                        // Frosted selection bar behind the selected row
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isLightMode ? Color.black.opacity(0.04) : Color.white.opacity(0.08))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .frame(height: 44)
                        
                        HStack(spacing: 0) {
                            // Hour Picker
                            Picker("Hour", selection: $hour) {
                                ForEach(0..<24) { h in
                                    Text(String(format: "%02d", h))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            .onChange(of: hour) { _, _ in triggerFeedback() }
                            
                            // Minute Picker
                            Picker("Minute", selection: $minute) {
                                ForEach(0..<60) { m in
                                    Text(String(format: "%02d", m))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            .clipped()
                            .onChange(of: minute) { _, _ in triggerFeedback() }
                            
                            // Second Picker (if available)
                            if let secondBinding = second {
                                Picker("Second", selection: secondBinding) {
                                    ForEach(0..<60) { s in
                                        Text(String(format: "%02d", s))
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                            .tag(s)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                                .clipped()
                                .onChange(of: secondBinding.wrappedValue) { _, _ in triggerFeedback() }
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
    }

    private var twelveHourButton: some View {
        Button(action: {
            withAnimation { is12HourFormat = true }
            triggerFeedback()
        }) {
            Text("12H")
                .font(.system(size: 16, weight: .bold))
                .fixedSize()
                .foregroundColor(is12HourFormat ? (isTiimo ? tiimoWeekdayPurple : Colors.accentTeal) : Colors.textSecondary.opacity(0.3))
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(is12HourFormat ? (isTiimo ? Colors.pillGreen : Colors.accentTeal.opacity(0.15)) : Color.clear)
                        .overlay(
                            Capsule().stroke(is12HourFormat ? (isTiimo ? tiimoWeekdayPurple.opacity(0.5) : Colors.accentTeal.opacity(0.5)) : Colors.cardStroke, lineWidth: 1)
                        )
                )
        }
        .scaleEffect(is12HourFormat ? 1.05 : 1.0)
        .animation(.spring(), value: is12HourFormat)
    }

    private var twentyFourHourButton: some View {
        Button(action: {
            withAnimation { is12HourFormat = false }
            triggerFeedback()
        }) {
            Text("24H")
                .font(.system(size: 16, weight: .bold))
                .fixedSize()
                .foregroundColor(!is12HourFormat ? (isTiimo ? tiimoWeekdayPurple : Colors.accentTeal) : Colors.textSecondary.opacity(0.3))
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(!is12HourFormat ? (isTiimo ? Colors.pillGreen : Colors.accentTeal.opacity(0.15)) : Color.clear)
                        .overlay(
                            Capsule().stroke(!is12HourFormat ? (isTiimo ? tiimoWeekdayPurple.opacity(0.5) : Colors.accentTeal.opacity(0.5)) : Colors.cardStroke, lineWidth: 1)
                        )
                )
        }
        .scaleEffect(!is12HourFormat ? 1.05 : 1.0)
        .animation(.spring(), value: is12HourFormat)
    }
    
    // MARK: - Helpers
    
    private func manualScroll(component: TimeComponent, delta: Int) {
        if activeComponent != component {
            activeComponent = component
        }
        
        switch component {
        case .hour:
            if is12HourFormat {
                // Keep AM/PM state while scrolling
                let wasPM = hour >= 12
                let h12 = hour % 12
                var newH12 = h12 + delta
                
                // Wrap around 0-11
                newH12 = (newH12 % 12 + 12) % 12
                
                let newH = newH12 + (wasPM ? 12 : 0)
                
                withAnimation(.snappy) {
                    hour = newH
                }
            } else {
                var newH = hour + delta
                if newH > topMax { newH = 0 }
                if newH < 0 { newH = topMax }
                withAnimation(.snappy) {
                    hour = newH
                }
            }
            triggerFeedback()
        case .minute:
            var newM = minute + delta
            if newM > bottomMax { newM = 0 }
            if newM < 0 { newM = bottomMax }
            withAnimation(.snappy) {
                minute = newM
            }
            triggerFeedback()
        case .second:
            if let secondBinding = second {
                var newS = secondBinding.wrappedValue + delta
                if newS > tertiaryMax { newS = 0 }
                if newS < 0 { newS = tertiaryMax }
                withAnimation(.snappy) {
                    secondBinding.wrappedValue = newS
                }
                triggerFeedback()
            }
        }
    }
    
    private func triggerFeedback() {
        feedback.selectionChanged()
        impactFeedback.impactOccurred(intensity: 0.7)
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTickSoundAt > 0.02 {
            AudioServicesPlaySystemSound(1104) // Smooth keyboard click sound
            lastTickSoundAt = now
        }
    }
    
    private func setAM() {
        if hour >= 12 {
            hour -= 12
        }
    }
    
    private func setPM() {
        if hour < 12 {
            hour += 12
        }
    }
    
    private func activeProgress() -> CGFloat {
        // If actively dragging the ring, show smooth progress
        if isInteracting, let angle = dragAngle {
             return CGFloat(normalizedDegrees(angle) / 360.0)
        }
        
        // Otherwise show snapped progress
        switch activeComponent {
            case .hour:
                if is12HourFormat {
                    return CGFloat(hour % 12) / 12.0
                } else {
                    return CGFloat(hour) / 24.0
                }
            case .minute:
                return CGFloat(minute) / 60.0
            case .second:
                return CGFloat(second?.wrappedValue ?? 0) / 60.0
        }
    }
    
    private func isTickActive(index: Int) -> Bool {
        switch activeComponent {
            case .hour:
                let currentHourIndex = is12HourFormat ? (hour % 12) : hour
                let markerFraction = Double(currentHourIndex) / Double(hourDialDivisions)
                let markerTick = Int(round(markerFraction * 60.0)) % 60
                return index == markerTick
            case .minute:
                return index == minute
            case .second:
                return index == (second?.wrappedValue ?? -1)
        }
    }
    
    private func isHourMatch(_ i: Int) -> Bool {
        if is12HourFormat {
            return (hour % 12) == i
        } else {
            return hour == i
        }
    }

    private func isCompactHourLabel(_ index: Int) -> Bool {
        guard !is12HourFormat else { return false }
        return index == 5 || index == 18
    }

    private func updateTimeFromDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: (size + 30) / 2, y: (size + 30) / 2)
        
        let vector = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
        
        // Atan2(y, x). 0 is 3 o'clock clockwise.
        var angle = atan2(vector.y, vector.x) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // Convert to clockwise degrees starting from 12 o'clock.
        var clockAngle = angle + 90
        if clockAngle >= 360 { clockAngle -= 360 }

        // Keep a continuous drag angle so crossing 359 -> 0 does not create a reverse jump.
        if let previousAngle = lastRawDragAngle {
            var delta = clockAngle - previousAngle
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            dragAngle = (dragAngle ?? previousAngle) + delta
        } else {
            dragAngle = clockAngle
        }
        lastRawDragAngle = clockAngle

        let selectionAngle = normalizedDegrees(dragAngle ?? clockAngle)
        
        // Update based on Active Component
        switch activeComponent {
        case .hour:
            if is12HourFormat {
                // Keep AM/PM state while selecting within a 12-hour dial.
                let newH12 = Int((selectionAngle / 30).rounded()) % 12
                let currentH24 = hour
                let isPM = currentH24 >= 12
                let newH24 = newH12 + (isPM ? 12 : 0)

                if newH24 != hour {
                    hour = newH24
                    triggerFeedback()
                }
            } else {
                // 24-hour dial: full 0...23 mapping around the circle.
                let stepAngle = 360.0 / 24.0
                let newH24 = Int((selectionAngle / stepAngle).rounded()) % 24
                if newH24 != hour {
                    hour = newH24
                    triggerFeedback()
                }
            }
            
        case .minute:
            // 6 degrees per minute (360 / 60)
            let newM = Int((selectionAngle / 6).rounded()) % 60
            if newM != minute && newM <= bottomMax {
                minute = newM
                triggerFeedback()
            }
            
        case .second:
            if let secondBinding = second {
                let newS = Int((selectionAngle / 6).rounded()) % 60
                if newS != secondBinding.wrappedValue && newS <= tertiaryMax {
                    secondBinding.wrappedValue = newS
                    triggerFeedback()
                }
            }
        }
    }

    private var lineRotationDegrees: Double {
        if isInteracting, let angle = dragAngle {
            return angle
        }
        return Double(activeProgress()) * 360.0
    }

    private func normalizedDegrees(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}

struct ArrowPointer: View {
    var color: Color
    var length: CGFloat
    var width: CGFloat = 6
    
    var body: some View {
        VStack {
             Spacer()
             Triangle()
                .fill(color)
                .frame(width: width, height: 15)
             Rectangle()
                .fill(color)
                .frame(width: 2, height: length)
             Spacer()
        }
        .offset(y: -length/2)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct UnitSelector: View {
    @Binding var val: Int
    var unit: String
    var maxVal: Int
    @Binding var offset: CGFloat // Tracks drag translation
    @Binding var isInteracting: Bool
    var feedback: UISelectionFeedbackGenerator
    var fontSize: CGFloat
    var unitSize: CGFloat
    
    var isActive: Bool
    var highlightColor: Color
    var onTap: () -> Void
    var onScroll: (Int) -> Void
    var onUnitTap: (() -> Void)? = nil
    
    // State to track accumulated drag for smooth continuous scrolling
    @State private var dragStepIndex: Int = 0
    
    var body: some View {
        let stepHeight: CGFloat = 22.0 // Wheel-like stable stepping distance
        
        VStack(spacing: 2) {
             Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isActive ? highlightColor : Colors.textSecondary.opacity(0.3))
                .offset(y: isInteracting ? -5 : 0)
                .opacity(isActive ? 1.0 : 0.0)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%02d", val))
                    .font(.system(size: fontSize, weight: .black, design: .monospaced))
                    .foregroundColor(isActive ? Colors.textPrimary : Colors.textTertiary)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.snappy(duration: 0.25), value: val)
                
                Text(unit)
                    .font(.system(size: unitSize, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? highlightColor : Colors.textTertiary.opacity(0.5))
                    .onTapGesture {
                        if let onUnitTap = onUnitTap {
                            onUnitTap()
                        } else {
                            onTap()
                        }
                    }
            }
            .contentShape(Rectangle())
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isActive ? highlightColor : Colors.textSecondary.opacity(0.3))
                .offset(y: isInteracting ? 5 : 0)
                .opacity(isActive ? 1.0 : 0.0)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isActive { onTap() }
                    if !isInteracting {
                        isInteracting = true
                        dragStepIndex = 0
                        feedback.prepare()
                    }

                    // Stable wheel-like step mapping: one discrete change per vertical step.
                    // This avoids oscillation from small drag jitter around thresholds.
                    let step = Int((-value.translation.height / stepHeight).rounded(.towardZero))
                    let delta = step - dragStepIndex
                    if delta != 0 {
                        onScroll(delta)
                        dragStepIndex = step
                    }

                    // Keep a subtle live offset for visual motion between step snaps.
                    let snapped = CGFloat(step) * stepHeight
                    withAnimation(.linear(duration: 0.06)) {
                        offset = value.translation.height - snapped
                    }
                }
                .onEnded { _ in
                    // DragGesture(minimumDistance: 0) captures taps too.
                    // Treat near-zero movement as a tap so the numeric selector always responds.
                    if dragStepIndex == 0 && abs(offset) < 4 {
                        onTap()
                        feedback.selectionChanged()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isInteracting = false
                        offset = 0
                    }
                    dragStepIndex = 0
                }
        )
    }
}

// Modifier for visual vertical offset with masking/clipping if desired
struct RollingEffect: ViewModifier {
    var offset: CGFloat
    var active: Bool
    
    func body(content: Content) -> some View {
        content
            // Ensure no offset applied but keep modifier for backward compatibility
            .offset(y: 0)
    }
}
