import SwiftUI

struct SunRayTimePickerView: View {
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
    @AppStorage("is12HourFormat") private var is12HourFormat: Bool = true // Persist format preference
    
    // New state for smooth ring dragging
    @State private var dragAngle: Double?
    
    // New state for precision picker
    @State private var showWheelPicker: Bool = false
    
    // Ring glow pulse animation
    @State private var ringGlowPulse: CGFloat = 0.0
    
    // Track if initial time has been set
    @State private var hasSetInitialTime: Bool = false
    
    // Optional timezone for location-based default
    var timeZoneIdentifier: String? = nil
    
    private let size: CGFloat = 240
    private let feedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light) // Stronger click
    
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
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            
            // 12H Button (Left Side)
            Button(action: {
                withAnimation { is12HourFormat = true }
                triggerFeedback()
            }) {
                Text("12H")
                    .font(.system(size: 16, weight: .bold))
                    .fixedSize()
                    .foregroundColor(is12HourFormat ? Colors.accentTeal : Colors.textSecondary.opacity(0.3))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(is12HourFormat ? Colors.accentTeal.opacity(0.15) : Color.clear)
                            .overlay(
                                Capsule().stroke(is12HourFormat ? Colors.accentTeal.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .scaleEffect(is12HourFormat ? 1.05 : 1.0)
            .animation(.spring(), value: is12HourFormat)
            
            ZStack {
                // Background Ticks (Static & Dynamic Color)
                ZStack {
                    // Outer ambient glow circle (subtle)
                    Circle()
                        .stroke(Colors.accentTeal.opacity(0.06 + ringGlowPulse * 0.04), lineWidth: 8)
                        .blur(radius: 6)
                        .frame(width: size + 14, height: size + 14)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: size, height: size)
                    
                    ForEach(0..<60) { i in
                        // Determine if this tick is "active" based on current value
                        let isActiveTick = isTickActive(index: i)
                        
                        Capsule()
                            .fill(isActiveTick ? Colors.accentTeal : Color.white.opacity(i % 5 == 0 ? 0.3 : 0.1))
                            .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? 10 : 6)
                            .offset(y: -(size/2))
                            .rotationEffect(.degrees(Double(i) * 6))
                            .shadow(color: isActiveTick ? Colors.accentTeal.opacity(0.6) : .clear, radius: 4)
                            .animation(.easeInOut(duration: 0.2), value: activeComponent) // Smooth transition
                    }
                    
                    // Hour markers (visual aid when in hour mode)
                    if activeComponent == .hour {
                        ForEach(0..<12) { i in
                            // Always show 1-12 clock face similar to standard analog clock
                            let label = i == 0 ? 12 : i
                            Text("\(label)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isHourMatch(i) ? Colors.accentTeal : Colors.textSecondary)
                                .shadow(color: isHourMatch(i) ? Colors.accentTeal.opacity(0.5) : .clear, radius: 4)
                                .offset(y: -(size/2 - 25))
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                    }
                }
                .frame(width: size, height: size)
                
                // Active Ring Segment — gradient stroke with glow
                Circle()
                    .trim(from: 0.0, to: activeProgress())
                    .stroke(
                        AngularGradient(
                            colors: [Colors.accentTeal.opacity(0.3), Colors.accentTeal, Colors.accentTeal],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * activeProgress())
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: size + 10, height: size + 10)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Colors.accentTeal.opacity(isInteracting ? 0.6 : Double(0.25 + ringGlowPulse * 0.15)), radius: isInteracting ? 10 : 5)
                    .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: activeProgress())
                
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
                                feedback.prepare()
                            }
                            updateTimeFromDrag(value)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isInteracting = false
                                dragAngle = nil // Snap back to nearest tick visually
                            }
                        }
                )
                
                // Digital Time Display (Center)
                VStack(spacing: second != nil ? 6 : 14) {
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
                        highlightColor: Colors.accentTeal,
                        onTap: {
                            activeComponent = .hour
                        },
                        onDoubleTap: {
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
                        .fill(Color.white.opacity(0.12))
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
                        highlightColor: Colors.accentTeal,
                        onTap: {
                            activeComponent = .minute
                        },
                        onDoubleTap: {
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
                            .fill(Color.white.opacity(0.12))
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
                            highlightColor: Colors.accentTeal,
                            onTap: {
                                activeComponent = .second
                            },
                            onDoubleTap: {
                                activeComponent = .second
                                showWheelPicker = true
                            },
                            onScroll: { delta in
                                manualScroll(component: .second, delta: delta)
                            }
                        )
                    }
                    
                    // 12/24 Mode Toggle (Small text button below)
                    // This button is now removed as it's replaced by the side buttons.
                }
                .contentShape(Rectangle())
            }
            .frame(width: size + 30, height: size + 30) // Ensure layout containment
            
            // 24H Button (Right Side)
            Button(action: {
                withAnimation { is12HourFormat = false }
                triggerFeedback()
            }) {
                Text("24H")
                    .font(.system(size: 16, weight: .bold))
                    .fixedSize()
                    .foregroundColor(!is12HourFormat ? Colors.accentTeal : Colors.textSecondary.opacity(0.3))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(!is12HourFormat ? Colors.accentTeal.opacity(0.15) : Color.clear)
                            .overlay(
                                Capsule().stroke(!is12HourFormat ? Colors.accentTeal.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .scaleEffect(!is12HourFormat ? 1.05 : 1.0)
            .animation(.spring(), value: is12HourFormat)
        }
        .padding(.bottom, 4)
        .frame(height: 275)
        .onAppear {
            // Start the breathing glow animation
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                ringGlowPulse = 1.0
            }
            
            // Set initial time to current location time (only once)
            if !hasSetInitialTime {
                hasSetInitialTime = true
                let tz: TimeZone
                if let id = timeZoneIdentifier, let customTZ = TimeZone(identifier: id) {
                    tz = customTZ
                } else {
                    tz = .current
                }
                var cal = Calendar.current
                cal.timeZone = tz
                let now = Date()
                hour = cal.component(.hour, from: now)
                minute = cal.component(.minute, from: now)
                if let secondBinding = second {
                    secondBinding.wrappedValue = cal.component(.second, from: now)
                }
            }
        }
        .sheet(isPresented: $showWheelPicker) {
            ZStack {
                // Dark background matching the app theme
                Color(red: 0.06, green: 0.07, blue: 0.10)
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
                                .background(Color.white.opacity(0.12))
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
                            .fill(Color.white.opacity(0.08))
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
            .colorScheme(.dark)
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
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
        impactFeedback.impactOccurred(intensity: 0.7) // Medium-strong impact
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
             return angle / 360.0
        }
        
        // Otherwise show snapped progress
        switch activeComponent {
            case .hour:
                // Map 0-11 for 12h cycle
                return CGFloat(hour % 12) / 12.0
            case .minute:
                return CGFloat(minute) / 60.0
            case .second:
                return CGFloat(second?.wrappedValue ?? 0) / 60.0
        }
    }
    
    private func isTickActive(index: Int) -> Bool {
        switch activeComponent {
            case .hour:
                // Map 0-11 hour to 0-60 ticks. 1 hour = 5 ticks.
                // 12 -> 0.
                let h = hour % 12
                // Light up the main tick corresponding to hour
                return index == (h * 5)
            case .minute:
                return index == minute
            case .second:
                return index == (second?.wrappedValue ?? -1)
        }
    }
    
    private func isHourMatch(_ i: Int) -> Bool {
        // i is 0..11 label
        return (hour % 12) == (i == 0 ? 0 : i) // Handle 12 vs 0 wraparound if labels are 0-11 vs 1-12
    }
    
    private func updateTimeFromDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: (size + 30) / 2, y: (size + 30) / 2)
        
        let vector = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
        
        // Atan2(y, x). 0 is 3 o'clock clockwise.
        var angle = atan2(vector.y, vector.x) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // Convert to clock-wise degrees starting from 12 o'clock
        var clockAngle = angle + 90
        if clockAngle >= 360 { clockAngle -= 360 }
        
        // Update based on Active Component
        switch activeComponent {
        case .hour:
            // 30 degrees per hour (360 / 12)
            // Determine closest hour index (0-11)
            let newH12 = Int((clockAngle / 30).rounded()) % 12
            
            // Current hour in 24h format
            let currentH24 = hour
            let isPM = currentH24 >= 12
            // Construct new hour maintaining phase
            let newH24 = newH12 + (isPM ? 12 : 0)
            
            if newH24 != hour {
                hour = newH24
                triggerFeedback()
            }
            
        case .minute:
            // 6 degrees per minute (360 / 60)
            let newM = Int((clockAngle / 6).rounded()) % 60
            if newM != minute && newM <= bottomMax {
                minute = newM
                triggerFeedback()
            }
            
        case .second:
            if let secondBinding = second {
                let newS = Int((clockAngle / 6).rounded()) % 60
                if newS != secondBinding.wrappedValue && newS <= tertiaryMax {
                    secondBinding.wrappedValue = newS
                    triggerFeedback()
                }
            }
        }
        
        // Update smooth angle for visualization
        self.dragAngle = clockAngle
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
    var onDoubleTap: () -> Void
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
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? Colors.textPrimary : Colors.textTertiary)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.snappy(duration: 0.25), value: val)
                
                Text(unit)
                    .font(.system(size: unitSize, weight: .medium))
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
            .onTapGesture {
                onTap()
                feedback.selectionChanged()
            }
            .onTapGesture(count: 2) {
                onDoubleTap()
                feedback.selectionChanged()
            }
            
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
