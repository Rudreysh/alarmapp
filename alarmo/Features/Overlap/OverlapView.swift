import SwiftUI
import Combine

struct OverlapView: View {
    let preferences: AppPreferences
    @StateObject private var store = OverlapStore.shared
    @State private var showOverlapAnalysis = false
    @State private var showCoachMark = false
    @State private var showTimeTravelCoachMark = false
    @State private var showOverlapAnalysisCoachMark = false
    @State private var showOverlapShareCoachMark = false
    
    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
    }
    @State private var editingCity: OverlapCity?
    @State private var showArrowHint = true
    @State private var arrowAnimationPhase: CGFloat = 0
    @State private var isDragging = false
    @State private var dragStartOffset: Int = 0
    @State private var swipingCityId: UUID? = nil
    
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showUpsell = false

    // Inline search
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                overlapHeader

                // Inline Search Bar
                inlineSearchBar

                // City list or search results
                if isSearching {
                    searchResultsList
                } else {
                    // City List with Drag & Drop Reordering
                    List {
                        ForEach(store.sortedCities) { city in
                            Group {
                                if city.isMinimized {
                                    minimizedCityRow(city)
                                        .onTapGesture(count: 2) {
                                            withAnimation(.spring(response: 0.3)) {
                                                store.toggleMinimized(id: city.id)
                                            }
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
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .contextMenu {
                                Button {
                                    let fmt = DateFormatter()
                                    fmt.timeZone = city.timeZone
                                    fmt.dateFormat = "HH:mm"
                                    let timeStr = fmt.string(from: store.adjustedDate)
                                    UIPasteboard.general.string = "\(city.displayName): \(timeStr)"
                                } label: {
                                    Label("Copy Time", systemImage: "doc.on.doc")
                                }
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        store.toggleMinimized(id: city.id)
                                    }
                                } label: {
                                    Label(city.isMinimized ? "Expand" : "Minimize", systemImage: city.isMinimized ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                                }
                                Button {
                                    editingCity = city
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    withAnimation(.spring()) {
                                        store.removeCity(id: city.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { from, to in
                            store.moveCity(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { offsets in
                            offsets.map { store.sortedCities[$0].id }.forEach { id in
                                store.removeCity(id: id)
                            }
                        }
                        
                        // Bottom spacing
                        Color.clear
                            .frame(height: 200)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
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
                                if preferences.hasSeenOverlapTimeTravelTooltip == false {
                                    preferences.hasSeenOverlapTimeTravelTooltip = true
                                    showTimeTravelCoachMark = false
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
                                if preferences.hasSeenOverlapTimeTravelTooltip == false {
                                    preferences.hasSeenOverlapTimeTravelTooltip = true
                                    showTimeTravelCoachMark = false
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
                } // end else (not searching)
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
            if !preferences.hasSeenOverlapTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showCoachMark = true }
                }
            } else if !preferences.hasSeenOverlapTimeTravelTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showTimeTravelCoachMark = true }
                }
            } else if !preferences.hasSeenOverlapAnalysisTooltip && !store.cities.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showOverlapAnalysisCoachMark = true }
                }
            } else if !preferences.hasSeenOverlapContextMenuTooltip && !store.cities.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showOverlapShareCoachMark = true }
                }
            }
        }
        .sheet(item: $editingCity) { city in
            CityDetailSheet(city: city, store: store)
        }
        .sheet(isPresented: $showOverlapAnalysis) {
            OverlapAnalysisSheet(store: store)
        }
        .fullScreenCover(isPresented: $showUpsell) {
            ProUpsellFlowView()
        }
        .onChange(of: showCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenOverlapTooltip {
                preferences.hasSeenOverlapTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showTimeTravelCoachMark = true }
            }
        }
        .onChange(of: showTimeTravelCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenOverlapTimeTravelTooltip {
                preferences.hasSeenOverlapTimeTravelTooltip = true
                if !store.cities.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showOverlapAnalysisCoachMark = true }
                }
            }
        }
        .onChange(of: showOverlapAnalysisCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenOverlapAnalysisTooltip {
                preferences.hasSeenOverlapAnalysisTooltip = true
                if !store.cities.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showOverlapShareCoachMark = true }
                }
            }
        }
        .onChange(of: showOverlapShareCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenOverlapContextMenuTooltip {
                preferences.hasSeenOverlapContextMenuTooltip = true
            }
        }
    }

    // MARK: - Header

    private var overlapHeader: some View {
        HStack {
            Text("Events")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            EditButton()
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.accentTeal)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Inline Search Bar (iOS Weather style)

    private var inlineSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.gray)

                TextField("Search cities...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .onChange(of: searchFocused) { _, focused in
                        if focused {
                            withAnimation(.spring(response: 0.3)) {
                                isSearching = true
                            }
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSearching ? Colors.accentTeal.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )

            if isSearching {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isSearching = false
                        searchText = ""
                        searchFocused = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Search Results

    private var addedIdentifiers: Set<String> {
        Set(store.cities.map(\.timeZoneIdentifier))
    }

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SUGGESTED CITIES")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .kerning(1)
                            .foregroundColor(Colors.textTertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 12)

                        ForEach(WorldCityDatabase.majorCities.prefix(30)) { entry in
                            searchRow(for: entry)
                        }
                    }
                } else {
                    ForEach(WorldCityDatabase.search(searchText)) { entry in
                        searchRow(for: entry)
                    }
                }
            }
        }
    }

    private func searchRow(for entry: WorldCityDatabase.CityEntry) -> some View {
        let isAdded = addedIdentifiers.contains(entry.timeZoneIdentifier)
        let flag = flagForTimezone(entry.timeZoneIdentifier)

        return VStack(spacing: 0) {
            Button {
                addCityFromSearch(entry)
            } label: {
                HStack(spacing: 12) {
                    Text(flag)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.cityName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(isAdded ? Colors.accentTeal : .white)

                        HStack(spacing: 6) {
                            Text(entry.country)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.gray)

                            if let tz = TimeZone(identifier: entry.timeZoneIdentifier) {
                                Text(tz.abbreviation() ?? "")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.gray.opacity(0.6))
                            }
                        }
                    }

                    Spacer()

                    if isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAdded)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.leading, 56)
        }
    }

    private func flagForTimezone(_ tz: String) -> String {
        let map: [String: String] = [
            "Asia/Kolkata": "🇮🇳", "Asia/Shanghai": "🇨🇳", "Asia/Tokyo": "🇯🇵",
            "Asia/Seoul": "🇰🇷", "Asia/Dubai": "🇦🇪", "Asia/Singapore": "🇸🇬",
            "Asia/Hong_Kong": "🇭🇰", "Asia/Bangkok": "🇹🇭", "Asia/Taipei": "🇹🇼",
            "Asia/Manila": "🇵🇭", "Asia/Jakarta": "🇮🇩", "Asia/Ho_Chi_Minh": "🇻🇳",
            "Asia/Kuala_Lumpur": "🇲🇾", "Asia/Qatar": "🇶🇦", "Asia/Riyadh": "🇸🇦",
            "Europe/London": "🇬🇧", "Europe/Berlin": "🇩🇪", "Europe/Paris": "🇫🇷",
            "Europe/Rome": "🇮🇹", "Europe/Madrid": "🇪🇸", "Europe/Amsterdam": "🇳🇱",
            "Europe/Moscow": "🇷🇺", "Europe/Istanbul": "🇹🇷", "Europe/Dublin": "🇮🇪",
            "Europe/Zurich": "🇨🇭", "Europe/Vienna": "🇦🇹", "Europe/Stockholm": "🇸🇪",
            "Europe/Warsaw": "🇵🇱", "Europe/Prague": "🇨🇿", "Europe/Lisbon": "🇵🇹",
            "America/New_York": "🇺🇸", "America/Chicago": "🇺🇸",
            "America/Los_Angeles": "🇺🇸", "America/Denver": "🇺🇸",
            "America/Toronto": "🇨🇦", "America/Vancouver": "🇨🇦",
            "America/Sao_Paulo": "🇧🇷", "America/Argentina/Buenos_Aires": "🇦🇷",
            "America/Mexico_City": "🇲🇽", "America/Bogota": "🇨🇴",
            "Africa/Johannesburg": "🇿🇦", "Africa/Nairobi": "🇰🇪",
            "Africa/Lagos": "🇳🇬", "Africa/Cairo": "🇪🇬",
            "Australia/Sydney": "🇦🇺", "Australia/Melbourne": "🇦🇺",
            "Pacific/Auckland": "🇳🇿",
        ]
        return map[tz] ?? "🌐"
    }

    private func addCityFromSearch(_ entry: WorldCityDatabase.CityEntry) {
        let city = OverlapCity(
            cityName: entry.cityName,
            timeZoneIdentifier: entry.timeZoneIdentifier
        )
        store.addCity(city)

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        withAnimation(.spring(response: 0.3)) {
            searchText = ""
            isSearching = false
            searchFocused = false
        }
    }

    // MARK: - Minimized City Row (e.g. London in user example)

    private func minimizedCityRow(_ city: OverlapCity) -> some View {
        let dateInZone = formattedDateComponents(
            for: city.timeZone,
            at: store.adjustedDate
        )
        let isToday = Calendar.current.isDateInToday(store.adjustedDate)
        let isDay = city.isDaytime(at: store.adjustedDate)
        
        return HStack(spacing: 8) {
            Text(city.flagEmoji)
                .font(.system(size: 16))
            
            Text(city.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            Image(systemName: isDay ? "sun.min.fill" : "moon.fill")
                .font(.system(size: 10))
                .foregroundColor(isDay ? Color.yellow : Color.purple.opacity(0.7))

            Spacer()

            if !isToday {
                Text(dateInZone.dateString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Colors.textSecondary)
                    .textCase(.uppercase)
                    .padding(.trailing, 4)
            }

            Text(dateInZone.timeString)
                .font(.system(size: 18, weight: .black, design: .monospaced))
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
        .contextMenu {
            Button {
                let fmt = DateFormatter()
                fmt.timeZone = city.timeZone
                fmt.dateFormat = "HH:mm"
                let timeStr = fmt.string(from: store.adjustedDate)
                UIPasteboard.general.string = "\(city.displayName): \(timeStr)"
            } label: {
                Label("Copy Time", systemImage: "doc.on.doc")
            }
            Button {
                withAnimation(.spring(response: 0.3)) {
                    store.toggleMinimized(id: city.id)
                }
            } label: {
                Label("Expand", systemImage: "rectangle.expand.vertical")
            }
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
                    .coachMark(
                        title: "Time Travel",
                        subtitle: "Swipe to see other times.",
                        isVisible: $showTimeTravelCoachMark,
                        alignment: .top,
                        pointDirection: .bottom,
                        arrowAlignment: .center,
                        arrowOffsetX: 0,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -64
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
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text(timeText)
                            .font(.system(size: 13, weight: .heavy))
                        Text(direction)
                            .font(.system(size: 13, weight: .medium))
                        Text("NOW")
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.0, green: 0.55, blue: 0.4))
                    )
                    .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3), radius: 6, y: 3)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Bottom Toolbar

    private var overlapToolbar: some View {
        HStack(spacing: 0) {
            // Add City (focuses search)
            Button { 
                withAnimation(.spring(response: 0.3)) {
                    isSearching = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFocused = true
                }
                if preferences.hasSeenOverlapTooltip == false {
                    preferences.hasSeenOverlapTooltip = true
                    showCoachMark = false
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .coachMark(
                        title: "Add City",
                        subtitle: "Search for cities.",
                        isVisible: $showCoachMark,
                        alignment: .top,
                        pointDirection: .bottom,
                        arrowAlignment: .center,
                        arrowOffsetX: 0,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -80,
                        color: .red
                    )
            }

            // Overlap Analysis (sinusoidal icon)
            Button { 
                preferences.hasSeenOverlapAnalysisTooltip = true
                showOverlapAnalysisCoachMark = false
                showOverlapAnalysis = true 
            } label: {
                Image(systemName: "waveform.path")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .coachMark(
                        title: "Analyze",
                        subtitle: "Find best meeting times.",
                        isVisible: $showOverlapAnalysisCoachMark,
                        alignment: .top,
                        pointDirection: .bottom,
                        arrowAlignment: .center,
                        arrowOffsetX: 0,
                        bubbleOffsetX: 0,
                        bubbleOffsetY: -80,
                        color: .red
                    )
            }

            // Share text representation
            ShareLink(item: generateShareText()) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .coachMark(
                        title: "Share",
                        subtitle: "Send times to others.",
                        isVisible: $showOverlapShareCoachMark,
                        alignment: .topTrailing,
                        pointDirection: .bottom,
                        arrowAlignment: .trailing,
                        arrowOffsetX: -24,
                        bubbleOffsetX: -16,
                        bubbleOffsetY: -80,
                        color: .red
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    /// Generates text to share current city times
    private func generateShareText() -> String {
        let date = store.adjustedDate
        let cities = store.sortedCities
        guard !cities.isEmpty else { return "" }
        
        let formatter = DateFormatter()
        
        // Header with date
        formatter.timeZone = cities.first!.timeZone
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        let dateStr = formatter.string(from: date)
        
        var text = "🌍 Times across cities — \(dateStr)\n\n"
        
        for city in cities {
            formatter.timeZone = city.timeZone
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: date)
            
            formatter.dateFormat = "z"
            let tzStr = formatter.string(from: date)
            
            text += "\(city.flagEmoji) \(city.displayName): \(timeStr) (\(tzStr))\n"
        }
        
        text += "\nShared from Alarmo"
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
        let isDay = city.isDaytime(at: adjustedDate)

        HStack(spacing: 0) {
            // LEFT: Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(city.flagEmoji)
                        .font(.system(size: 16))
                    Text(city.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                let offsetStr = city.offsetString(from: referenceTimeZone, at: adjustedDate)
                Text(offsetStr == "+0" ? "HOME TZ" : "\(offsetStr) HRS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Colors.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Colors.accentTeal.opacity(0.12))
                    .cornerRadius(6)
            }

            Spacer()

            // RIGHT: Time
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dateComps.timeString)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDay ? Color.yellow : Colors.accentTeal)
                }

                Text(dateComps.dayOfWeek.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(0.5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                cardGradient
                
                // Subtle teal glow for active/day cities
                if isDay {
                    LinearGradient(
                        colors: [Colors.accentTeal.opacity(0.08), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isDay ? Colors.accentTeal.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
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
