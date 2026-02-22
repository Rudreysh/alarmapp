import SwiftUI
import Combine

struct OverlapView: View {
    @StateObject private var store = OverlapStore.shared
    @State private var showCitySearch = false
    @State private var showOverlapAnalysis = false
    @State private var editingCity: OverlapCity?
    @State private var showArrowHint = true
    @State private var arrowAnimationPhase: CGFloat = 0
    @State private var isDragging = false
    @State private var dragStartOffset: Int = 0
    @State private var swipingCityId: UUID? = nil

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.04, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                overlapHeader

                // City List with global horizontal swipe
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(store.sortedCities) { city in
                            SwipeableCityRow(
                                cityId: city.id,
                                onDelete: {
                                    withAnimation(.spring()) {
                                        store.removeCity(id: city.id)
                                        swipingCityId = nil
                                    }
                                },
                                swipingId: $swipingCityId
                            ) {
                                if city.isMinimized {
                                    minimizedCityRow(city)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .transition(.opacity)
                                        .onTapGesture(count: 2) {
                                            withAnimation(.spring(response: 0.3)) {
                                                store.toggleMinimized(id: city.id)
                                            }
                                            #if os(iOS)
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            #endif
                                        }
                                } else {
                                    CityCardView(
                                        city: city,
                                        referenceTimeZone: store.referenceTimeZone,
                                        adjustedDate: store.adjustedDate
                                    )
                                    .onTapGesture(count: 2) {
                                        editingCity = city
                                    }
                                    .onLongPressGesture(minimumDuration: 0.6) {
                                        withAnimation(.spring(response: 0.3)) {
                                            store.toggleMinimized(id: city.id)
                                        }
                                        #if os(iOS)
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        #endif
                                    }
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                }
                            }
                        }

                        Spacer(minLength: 200)
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if swipingCityId != nil { return } // Mutated to ignore when swiping a card
                            if abs(value.translation.width) > abs(value.translation.height) + 10 {
                                if !isDragging {
                                    isDragging = true
                                    dragStartOffset = store.timeOffsetMinutes
                                    showArrowHint = false
                                }
                                let delta = Int(-value.translation.width / 2)
                                store.timeOffsetMinutes = dragStartOffset + delta
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )

                // Time offset indicator + Arrow hints
                timeOffsetBar
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if swipingCityId != nil { return }
                                if !isDragging {
                                    isDragging = true
                                    dragStartOffset = store.timeOffsetMinutes
                                    showArrowHint = false
                                }
                                let delta = Int(-value.translation.width / 2)
                                store.timeOffsetMinutes = dragStartOffset + delta
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )

                // Bottom Toolbar
                overlapToolbar
            }
            .padding(.bottom, AppConstants.tabBarHeight + 8)
        }
        .onReceive(timer) { _ in
            store.objectWillChange.send()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatCount(3, autoreverses: true)) {
                arrowAnimationPhase = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { showArrowHint = false }
            }
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet(store: store)
        }
        .sheet(item: $editingCity) { city in
            CityDetailSheet(city: city, store: store)
        }
        .sheet(isPresented: $showOverlapAnalysis) {
            OverlapAnalysisSheet(store: store)
        }
    }

    // MARK: - Header

    private var overlapHeader: some View {
        HStack {
            Text("Events")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Minimized City Row (e.g. London in user example)

    private func minimizedCityRow(_ city: OverlapCity) -> some View {
        let dateInZone = formattedDateComponents(
            for: city.timeZone,
            at: store.adjustedDate
        )
        let isToday = Calendar.current.isDateInToday(store.adjustedDate)
        
        return HStack {
            Text(city.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            if !isToday {
                Text(dateInZone.dateString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                    .textCase(.uppercase)
                    .padding(.trailing, 4)
            }

            Text(dateInZone.timeString)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .onLongPressGesture(minimumDuration: 0.6) {
            withAnimation(.spring(response: 0.3)) {
                store.toggleMinimized(id: city.id)
            }
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    // MARK: - Time Offset Bar

    private var timeOffsetBar: some View {
        VStack(spacing: 8) {
            if showArrowHint {
                // Animated arrows <- ->
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .offset(x: -arrowAnimationPhase * 16)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentTeal.opacity(0.6))
                        .offset(x: -arrowAnimationPhase * 10)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentTeal.opacity(0.6))
                        .offset(x: arrowAnimationPhase * 10)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .offset(x: arrowAnimationPhase * 16)
                }
                .padding(.horizontal, 40)
                .transition(.opacity)
            }

            // Offset label or NOW button
            if store.timeOffsetMinutes == 0 {
                Text("NOW")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.15, green: 0.17, blue: 0.22))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            } else {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        store.resetToNow()
                    }
                } label: {
                    let absMin = abs(store.timeOffsetMinutes)
                    let direction = store.timeOffsetMinutes > 0 ? "FROM" : "BEFORE"
                    let timeText: String = {
                        if absMin < 60 {
                            return "\(absMin) MINUTES"
                        } else {
                            let h = absMin / 60
                            let m = absMin % 60
                            if m == 0 {
                                return "\(h) HOUR\(h > 1 ? "S" : "")"
                            }
                            return "\(h)H \(m)M"
                        }
                    }()

                    HStack(spacing: 6) {
                        Text(timeText)
                            .font(.system(size: 13, weight: .heavy))
                        Text(direction)
                            .font(.system(size: 13, weight: .medium))
                        Text("NOW")
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.15, green: 0.17, blue: 0.22))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Bottom Toolbar

    private var overlapToolbar: some View {
        HStack(spacing: 0) {
            // Add City
            Button { showCitySearch = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }

            // Overlap Analysis (sinusoidal icon)
            Button { showOverlapAnalysis = true } label: {
                Image(systemName: "waveform.path")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }

            // Share text representation
            ShareLink(item: generateShareText()) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    /// Generates text to share current city times
    private func generateShareText() -> String {
        let date = store.adjustedDate
        var cities = store.sortedCities
        guard let baseCity = cities.first else { return "" }
        
        let formatter = DateFormatter()
        formatter.timeZone = baseCity.timeZone
        
        formatter.dateFormat = "EEEE, d. MMMM yyyy"
        let baseDateStr = formatter.string(from: date)
        
        formatter.dateFormat = "HH:mm"
        let baseTimeStr = formatter.string(from: date)
        
        formatter.dateFormat = "z"
        let baseTzStr = formatter.string(from: date)
        
        var text = "How's \(baseDateStr) at \(baseTimeStr) (\(baseTzStr))?\n"
        
        if cities.count > 1 {
            let otherCities = cities.dropFirst()
            var otherTimes: [String] = []
            
            for city in otherCities {
                formatter.timeZone = city.timeZone
                formatter.dateFormat = "HH:mm"
                let timeStr = formatter.string(from: date)
                otherTimes.append("\(timeStr) for \(city.displayName)")
            }
            
            if otherTimes.count == 1 {
                text += "That's \(otherTimes[0])."
            } else if otherTimes.count == 2 {
                text += "That's \(otherTimes[0]) and \(otherTimes[1])."
            } else {
                let last = otherTimes.removeLast()
                let joined = otherTimes.joined(separator: ", ")
                text += "That's \(joined), and \(last)."
            }
        }
        
        return text
    }

    struct DateComponents {
        let timeString: String
        let dateString: String
        let dayOfWeek: String
    }

    func formattedDateComponents(for tz: TimeZone, at date: Date) -> DateComponents {
        let timeFmt = DateFormatter()
        timeFmt.timeZone = tz
        timeFmt.dateFormat = "HH:mm"

        let dateFmt = DateFormatter()
        dateFmt.timeZone = tz
        dateFmt.dateFormat = "EEE d. MMM"

        let dayFmt = DateFormatter()
        dayFmt.timeZone = tz
        dayFmt.dateFormat = "EEEE, d. MMMM"

        return DateComponents(
            timeString: timeFmt.string(from: date),
            dateString: dateFmt.string(from: date),
            dayOfWeek: dayFmt.string(from: date)
        )
    }
}

// MARK: - City Card View

struct CityCardView: View {
    let city: OverlapCity
    let referenceTimeZone: TimeZone
    let adjustedDate: Date

    private var offsetHours: Double {
        city.offsetHours(from: referenceTimeZone, at: adjustedDate)
    }

    private var cardGradient: LinearGradient {
        // Diverse gradients purely based on offset to give each card a distinct look
        let offsets = [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]
        let closest = offsets.min(by: { abs($0 - offsetHours) < abs($1 - offsetHours) }) ?? 0.0

        let colors: [Color]
        switch closest {
        case -12.0 ... -8.0:
            colors = [Color(red: 0.1, green: 0.2, blue: 0.35), Color(red: 0.05, green: 0.1, blue: 0.2)] // Deep Oceaan
        case -4.0:
            colors = [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.1, green: 0.05, blue: 0.15)] // Purple Dusk
        case 0.0:
            colors = [Color(red: 0.15, green: 0.18, blue: 0.25), Color(red: 0.08, green: 0.1, blue: 0.15)] // Slate reference
        case 4.0:
            colors = [Color(red: 0.25, green: 0.15, blue: 0.1), Color(red: 0.15, green: 0.08, blue: 0.05)] // Amber Night
        case 8.0 ... 12.0:
            colors = [Color(red: 0.1, green: 0.3, blue: 0.25), Color(red: 0.05, green: 0.15, blue: 0.1)] // Forest Dark
        default:
            colors = [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.06, green: 0.08, blue: 0.12)]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func formattedDateComponents(for tz: TimeZone, at date: Date) -> OverlapView.DateComponents {
        let timeFmt = DateFormatter()
        timeFmt.timeZone = tz
        timeFmt.dateFormat = "HH:mm"

        let dateFmt = DateFormatter()
        dateFmt.timeZone = tz
        dateFmt.dateFormat = "EEE d. MMM"

        let dayFmt = DateFormatter()
        dayFmt.timeZone = tz
        dayFmt.dateFormat = "EEEE, d. MMMM"

        return OverlapView.DateComponents(
            timeString: timeFmt.string(from: date),
            dateString: dateFmt.string(from: date),
            dayOfWeek: dayFmt.string(from: date)
        )
    }

    var body: some View {
        let dateComps = formattedDateComponents(for: city.timeZone, at: adjustedDate)

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(city.displayName)
                    .font(.system(size: 20, weight: .bold)) // slightly smaller font
                    .foregroundColor(.white)

                let offsetStr = city.offsetString(from: referenceTimeZone, at: adjustedDate)
                Text(offsetStr == "+0" ? "HOME TZ" : "\(offsetStr) HRS")
                    .font(.system(size: 11, weight: .semibold)) // slightly smaller font
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(dateComps.timeString)
                    .font(.system(size: 36, weight: .bold, design: .rounded)) // smaller time
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text(dateComps.dayOfWeek.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14) // Reduced height padding roughly ~30% smaller
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct SwipeableCityRow<Content: View>: View {
    let cityId: UUID
    let onDelete: () -> Void
    @Binding var swipingId: UUID?
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let maxOffset: CGFloat = -90
    private let revealThreshold: CGFloat = -50

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.trailing, 16)
            .padding(.top, 8)

            content()
                .overlay(
                    Group {
                        if offset < 0 {
                            Color.black.opacity(0.001)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        offset = 0
                                        swipingId = nil
                                    }
                                }
                        }
                    }
                )
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.width < 0 || offset < 0 {
                                state = value.translation.width
                            }
                        }
                        .onChanged { value in
                            if swipingId == nil || swipingId == cityId {
                                if value.translation.width < -10 {
                                    swipingId = cityId
                                }
                            }
                        }
                        .onEnded { value in
                            let total = offset + value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if total < revealThreshold {
                                    offset = maxOffset
                                } else {
                                    offset = 0
                                    swipingId = nil
                                }
                            }
                        }
                )
        }
        .animation(.easeInOut(duration: 0.18), value: offset)
    }
}
