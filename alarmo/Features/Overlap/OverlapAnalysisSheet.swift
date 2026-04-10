import SwiftUI

/// Overlap Analysis — finds overlapping availability windows across selected cities.
/// This is the "sinusoidal" icon feature showing when selected cities overlap.
struct OverlapAnalysisSheet: View {
    @ObservedObject var store: OverlapStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCityIds: Set<UUID> = []
    @State private var showMeetingSuggestions = false
    
    // Feature: Interactive Scrubber
    @State private var scrubMinutes: Double? = nil
    @State private var showCopiedBanner = false

    // Feature: Custom Overlap Duration
    @State private var customOverlapStart: Int? = nil
    @State private var customOverlapEnd: Int? = nil
    @State private var showOverlapTimePicker = false
    @State private var overlapPickerStart: Date = Date()
    @State private var overlapPickerEnd: Date = Date()

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // City selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT CITIES TO COMPARE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.gray)
                            .kerning(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.visibleCities) { city in
                                    let isSelected = selectedCityIds.contains(city.id)
                                    Button {
                                        if isSelected {
                                            selectedCityIds.remove(city.id)
                                        } else {
                                            selectedCityIds.insert(city.id)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 14))
                                            }
                                            Text(city.displayName)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(isSelected ? .white : Color.gray)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color(red: 0.0, green: 0.7, blue: 0.5) : Color(red: 0.12, green: 0.14, blue: 0.20))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)

                    if selectedCityIds.count >= 2 {
                        // Visual timeline comparison
                        ScrollView {
                            VStack(spacing: 24) {
                                // Timeline bars for each selected city
                                ForEach(store.visibleCities.filter { selectedCityIds.contains($0.id) }) { city in
                                    cityTimelineBar(city)
                                }

                                // Overlap result
                                overlapResultView

                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal)

                                // Super Feature: Interactive Time Scrubber
                                timeScrubberSection

                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal)

                                // Best Meeting Times
                                bestMeetingTimesSection
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "waveform.path")
                                .font(.system(size: 48))
                                .foregroundColor(Color.gray.opacity(0.6))

                            Text("Select at least 2 cities\nto see their overlap")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Overlap Analysis")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                }
            }
        }
        .onAppear {
            // Default: select all visible cities
            selectedCityIds = Set(store.visibleCities.map(\.id))
        }
        .onChange(of: selectedCityIds) { oldValue, newValue in
            customOverlapStart = nil
            customOverlapEnd = nil
        }
        .sheet(isPresented: $showOverlapTimePicker) {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Customize Meeting Time")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 24)

                    HStack {
                        Text("Start Time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        DatePicker("", selection: $overlapPickerStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(Color(red: 0.0, green: 0.7, blue: 0.5))
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.1, blue: 0.15))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    HStack {
                        Text("End Time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        DatePicker("", selection: $overlapPickerEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(Color(red: 0.0, green: 0.7, blue: 0.5))
                    }
                    .padding()
                    .background(Color(red: 0.08, green: 0.1, blue: 0.15))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    Spacer()

                    Button {
                        let cal = Calendar.current
                        customOverlapStart = cal.component(.hour, from: overlapPickerStart) * 60 + cal.component(.minute, from: overlapPickerStart)
                        customOverlapEnd = cal.component(.hour, from: overlapPickerEnd) * 60 + cal.component(.minute, from: overlapPickerEnd)
                        showOverlapTimePicker = false
                    } label: {
                        Text("Set Custom Time")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(14)
                            .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    if customOverlapStart != nil || customOverlapEnd != nil {
                        Button {
                            withAnimation {
                                customOverlapStart = nil
                                customOverlapEnd = nil
                                showOverlapTimePicker = false
                            }
                        } label: {
                            Text("Reset to Maximum Overlap")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.gray)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            #if os(iOS)
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    // MARK: - Timeline Bar for a city

    @ViewBuilder
    private func cityTimelineBar(_ city: OverlapCity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(city.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(OverlapStore.formatMinutes(city.availabilityStart)) – \(OverlapStore.formatMinutes(city.availabilityEnd))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.gray)
            }

            // 24-hour timeline bar
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let minuteWidth = totalWidth / 1440.0

                ZStack(alignment: .leading) {
                    // Background (full 24 hours)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.18))
                        .frame(height: 28)

                    // Flex before
                    let flexStartPos = CGFloat(city.availabilityStart - city.flexMinutesBefore) * minuteWidth
                    let flexEndPos = CGFloat(city.availabilityEnd + city.flexMinutesAfter) * minuteWidth
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.2))
                        .frame(width: max(0, flexEndPos - flexStartPos), height: 28)
                        .offset(x: flexStartPos)

                    // Availability window
                    let startPos = CGFloat(city.availabilityStart) * minuteWidth
                    let endPos = CGFloat(city.availabilityEnd) * minuteWidth
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.7))
                        .frame(width: max(0, endPos - startPos), height: 28)
                        .offset(x: startPos)

                    // Hour markers
                    ForEach([0, 6, 12, 18], id: \.self) { hour in
                        let x = CGFloat(hour * 60) * minuteWidth
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 1, height: 28)
                        }
                        .offset(x: x)
                    }

                    // Current time indicator
                    let refCity = city
                    let nowInCity = currentMinutes(in: refCity.timeZone, at: store.adjustedDate)
                    let nowX = CGFloat(nowInCity) * minuteWidth
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2, height: 28)
                        .offset(x: min(max(0, nowX), totalWidth - 2))

                    // Scrubber line overlay (if activated)
                    if let sMins = scrubMinutes {
                        let offsetSeconds = city.timeZone.secondsFromGMT(for: store.adjustedDate) - store.referenceTimeZone.secondsFromGMT(for: store.adjustedDate)
                        let offsetMinutes = Int(offsetSeconds / 60)
                        let cityMins = (Int(sMins) + offsetMinutes)
                        let normalizedCityMins = ((cityMins % 1440) + 1440) % 1440
                        let scrubX = CGFloat(normalizedCityMins) * minuteWidth

                        Rectangle()
                            .fill(Color.yellow) // The explorer line
                            .frame(width: 3, height: 28)
                            .offset(x: min(max(0, scrubX), totalWidth - 3))
                            .shadow(color: .yellow, radius: 4, x: 0, y: 0)
                    }
                }
            }
            .frame(height: 28)

            // Time labels
            HStack {
                Text("00:00")
                Spacer()
                Text("06:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("18:00")
                Spacer()
                Text("24:00")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Color.gray.opacity(0.6))
        }
    }

    // MARK: - Overlap Result

    @ViewBuilder
    private var overlapResultView: some View {
        let selectedIds = Array(selectedCityIds)
        if let baseOverlap = store.findOverlap(for: selectedIds) {
            let actualStart = customOverlapStart ?? baseOverlap.start
            let actualEnd = customOverlapEnd ?? baseOverlap.end

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(customOverlapStart != nil ? "Meeting Proposal" : "Overlap Found!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                let selectedNames = store.visibleCities
                    .filter { selectedCityIds.contains($0.id) }
                    .map(\.displayName)
                    .joined(separator: ", ")

                Text("Overlap for \(selectedNames)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.gray)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(OverlapStore.formatMinutes(actualStart))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                        Text("START")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.gray)
                    }

                    Text("—")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.gray)

                    VStack(spacing: 4) {
                        Text(OverlapStore.formatMinutes(actualEnd))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                        Text("END")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.gray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.15), radius: 10, x: 0, y: 5)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                        .background(Circle().fill(Color(red: 0.12, green: 0.15, blue: 0.22)))
                        .offset(x: 10, y: -10)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    let cal = Calendar.current
                    var sComps = DateComponents()
                    sComps.hour = actualStart / 60
                    sComps.minute = actualStart % 60
                    overlapPickerStart = cal.date(from: sComps) ?? Date()

                    var eComps = DateComponents()
                    eComps.hour = actualEnd / 60
                    eComps.minute = actualEnd % 60
                    overlapPickerEnd = cal.date(from: eComps) ?? Date()

                    showOverlapTimePicker = true
                }

                let durationMin = actualEnd - actualStart
                let displayDuration = durationMin < 0 ? durationMin + 1440 : durationMin
                Text(customOverlapStart != nil ? "\(displayDuration / 60)h \(displayDuration % 60)m selected" : "\(displayDuration / 60)h \(displayDuration % 60)m overlap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                // Show what time it is in each city during the overlap
                VStack(alignment: .leading, spacing: 8) {
                    Text("During this overlap:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gray)

                    ForEach(store.visibleCities.filter { selectedCityIds.contains($0.id) }) { city in
                        let offsetSeconds = city.timeZone.secondsFromGMT(for: store.adjustedDate) - store.referenceTimeZone.secondsFromGMT(for: store.adjustedDate)
                        let offsetMin = offsetSeconds / 60
                        let cityStart = actualStart + offsetMin
                        let cityEnd = actualEnd + offsetMin

                        HStack {
                            Text(city.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(OverlapStore.formatMinutes(cityStart)) – \(OverlapStore.formatMinutes(cityEnd))")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.08, green: 0.10, blue: 0.16))
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.08, blue: 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.2), lineWidth: 1)
            )
        } else if selectedCityIds.count >= 2 {
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.red.opacity(0.7))

                Text("No Overlap")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("The selected cities' availability hours don't overlap.\nTry adjusting availability in city settings.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Best Meeting Times

    @ViewBuilder
    private var bestMeetingTimesSection: some View {
        let slots = store.bestMeetingSlots(for: Array(selectedCityIds))
        if !slots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                    Text("Best Meeting Times")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                ForEach(slots.prefix(5)) { slot in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            scrubMinutes = Double(slot.startMinutes)
                        }
                    } label: {
                        HStack {
                            HStack(spacing: 4) {
                                Text(slot.startFormatted)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text("–")
                                Text(slot.endFormatted)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundColor(.white)

                            Spacer()

                            // Quality indicator
                            HStack(spacing: 3) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(Double(i) < slot.score * 5 ? Color(red: 0.0, green: 0.7, blue: 0.5) : Color.white.opacity(0.1))
                                        .frame(width: 6, height: 6)
                                }
                            }

                            Text(slot.score >= 0.9 ? "Ideal" : slot.score >= 0.6 ? "Good" : "Flex")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(slot.score >= 0.9 ? .green : slot.score >= 0.6 ? Color(red: 0.0, green: 0.7, blue: 0.5) : .orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(scrubMinutes == Double(slot.startMinutes) ? Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.1) : Color(red: 0.08, green: 0.10, blue: 0.16))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers
    
    @ViewBuilder
    private var timeScrubberSection: some View {
        let slots = store.bestMeetingSlots(for: Array(selectedCityIds))
        let proposalRefMinutes = scrubMinutes.map(Int.init) ?? slots.first?.startMinutes
        
        VStack(alignment: .leading, spacing: 12) {
            if let proposalRefMinutes {
                meetingPlannerCard(for: proposalRefMinutes)
            }
            
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
                Text("Interactive Explorer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let mins = scrubMinutes {
                    Text(OverlapStore.formatMinutes(Int(mins)))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.0, green: 0.7, blue: 0.5).opacity(0.2))
                        .cornerRadius(6)
                } else {
                    Text("Off")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.gray)
                }
            }
            
            Slider(value: Binding(
                get: { scrubMinutes ?? 720 },
                set: { scrubMinutes = $0 }
            ), in: 0...1440, step: 15)
            .tint(Color(red: 0.0, green: 0.7, blue: 0.5))
            
            HStack {
                Text("Drag to preview and copy meeting times across timezones.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)
                
                Spacer()
                
                if scrubMinutes != nil {
                    Button("Clear") {
                        withAnimation { scrubMinutes = nil }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                }
            }
            
            if let mins = scrubMinutes {
                Text("Precision tuning \(OverlapStore.formatMinutes(Int(mins)))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.7, blue: 0.5))
            }
        }
    }
    
    private func meetingPlannerCard(for refMinutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meeting Proposal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    copyMeetingPlan(for: refMinutes)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedBanner ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(showCopiedBanner ? "Copied" : "Copy")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(showCopiedBanner ? .green : Color(red: 0.0, green: 0.7, blue: 0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.visibleCities.filter { selectedCityIds.contains($0.id) }) { city in
                    let offsetSeconds = city.timeZone.secondsFromGMT(for: store.adjustedDate) - store.referenceTimeZone.secondsFromGMT(for: store.adjustedDate)
                    let offsetMinutes = Int(offsetSeconds / 60)
                    let cityMins = (refMinutes + offsetMinutes)
                    let normalizedCityMins = ((cityMins % 1440) + 1440) % 1440
                    
                    // Basic Check If Awake
                    let isAvailable = (normalizedCityMins >= city.availabilityStart && normalizedCityMins <= city.availabilityEnd)
                    let isFlex = (normalizedCityMins >= city.availabilityStart - city.flexMinutesBefore && normalizedCityMins <= city.availabilityEnd + city.flexMinutesAfter)
                    
                    let statusIcon = isAvailable ? "🟢" : (isFlex ? "🟡" : "🌙")
                    
                    HStack {
                        Text(statusIcon)
                            .font(.system(size: 10))
                        Text(city.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.gray)
                        Spacer()
                        Text(OverlapStore.formatMinutes(normalizedCityMins))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(isAvailable ? .white : Color.gray.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private func copyMeetingPlan(for refMinutes: Int) {
        var text = "📅 Let's meet at:\n\n"
        for city in store.visibleCities.filter({ selectedCityIds.contains($0.id) }) {
            let offsetSeconds = city.timeZone.secondsFromGMT(for: store.adjustedDate) - store.referenceTimeZone.secondsFromGMT(for: store.adjustedDate)
            let offsetMinutes = Int(offsetSeconds / 60)
            let cityMins = (refMinutes + offsetMinutes)
            let normalizedCityMins = ((cityMins % 1440) + 1440) % 1440
            text += "\(city.displayName): \(OverlapStore.formatMinutes(normalizedCityMins))\n"
        }
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        
        withAnimation { showCopiedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedBanner = false }
        }
    }

    private func currentMinutes(in tz: TimeZone, at date: Date) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = tz
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }
}
