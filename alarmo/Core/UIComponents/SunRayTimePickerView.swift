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
    
    @State private var activeComponent: TimeComponent = .minute
    @AppStorage("is12HourFormat") private var is12HourFormat: Bool = true // Persist format preference
    
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
                                .offset(y: -(size/2 - 25))
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                    }
                }
                .frame(width: size, height: size)
                
                // Active Ring Segment (Arc for Hour/Minute/Second progress)
                Circle()
                    .trim(from: 0.0, to: activeProgress())
                    .stroke(Colors.accentTeal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 10, height: size + 10) // Slightly outside
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: activeProgress())

                
                // User Interaction Layer (Transparent)
                ZStack {
                    Color.white.opacity(0.001)
                }
                .frame(width: size + 30, height: size + 30)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isInteracting { isInteracting = true }
                            updateTimeFromDrag(value)
                        }
                        .onEnded { _ in
                            isInteracting = false
                        }
                )
                
                // Digital Time Display (Center)
                VStack(spacing: second != nil ? 6 : 14) {
                    // Top Selector (Hour)
                    UnitSelector(
                        val: Binding(get: { displayHour }, set: { _ in }), // Read-only for display here, updated via drag/tap logic
                        unit: is12HourFormat ? (isPM ? "PM" : "AM") : topUnit,
                        maxVal: topMax, // Not used strictly for display click
                        offset: $hourOffset,
                        isInteracting: $isInteracting,
                        feedback: feedback,
                        fontSize: second != nil ? 32 : 46,
                        unitSize: second != nil ? 14 : 16,
                        isActive: activeComponent == .hour,
                        highlightColor: Colors.accentTeal,
                        onTap: { activeComponent = .hour },
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
                        onTap: { activeComponent = .minute },
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
                            onTap: { activeComponent = .second },
                            onScroll: { delta in
                                manualScroll(component: .second, delta: delta)
                            }
                        )
                    }
                    
                    // 12/24 Mode Toggle (Small text button below)
                    // This button is now removed as it's replaced by the side buttons.
                }
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
        .padding(.bottom, 60)
        .frame(height: 300)
    }
    
    // MARK: - Helpers
    
    private func manualScroll(component: TimeComponent, delta: Int) {
        if activeComponent != component {
            activeComponent = component
        }
        
        switch component {
        case .hour:
            var newH = hour + delta
            if newH > topMax { newH = 0 }
            if newH < 0 { newH = topMax }
            hour = newH
            triggerFeedback()
        case .minute:
            var newM = minute + delta
            if newM > bottomMax { newM = 0 }
            if newM < 0 { newM = bottomMax }
            minute = newM
            triggerFeedback()
        case .second:
            if let secondBinding = second {
                var newS = secondBinding.wrappedValue + delta
                if newS > tertiaryMax { newS = 0 }
                if newS < 0 { newS = tertiaryMax }
                secondBinding.wrappedValue = newS
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
        switch activeComponent {
            case .hour:
                // Map 0-11 for 12h cycle or 0-23/24? 
                // Ring usually visualizes 12h face since markers are 12h.
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
            var newH24 = newH12 + (isPM ? 12 : 0)
            
            if newH24 > topMax {
               // Clamp or Wrap logic if needed
               // Standard clock: user rotates safely.
            }
            
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
    @State private var accumulatedOffset: CGFloat = 0
    
    var body: some View {
        let dragThreshold: CGFloat = 15.0 // Sensitivity
        
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
                    .modifier(RollingEffect(offset: offset, active: isActive))
                
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
                    if !isInteracting { isInteracting = true }
                    
                    // Cumulative drag logic
                    let currentTranslation = value.translation.height
                    let diff = currentTranslation - accumulatedOffset
                    
                    // Update visual offset
                    offset += diff
                    accumulatedOffset = currentTranslation
                    
                    // Check threshold
                    if offset > dragThreshold {
                        // Dragging down -> Decrement
                        while offset > dragThreshold {
                            onScroll(-1)
                            offset -= dragThreshold * 1.25 // Smooth snap back, slightly larger to avoid double triggers
                        }
                    } else if offset < -dragThreshold {
                        // Dragging up -> Increment
                        while offset < -dragThreshold {
                            onScroll(1)
                            offset += dragThreshold * 1.25
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isInteracting = false
                        offset = 0
                    }
                    accumulatedOffset = 0
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
            .offset(y: offset)
            .animation(.interactiveSpring(), value: offset)
    }
}
