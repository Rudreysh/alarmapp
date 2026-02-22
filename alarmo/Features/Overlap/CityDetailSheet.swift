import SwiftUI

/// Detail/edit sheet for a city — star, notes, rename, availability, delete.
struct CityDetailSheet: View {
    @State var city: OverlapCity
    @ObservedObject var store: OverlapStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @FocusState private var notesFocused: Bool
    
    @State private var showNotes = false
    @State private var dragFlexBeforeStartOffset: Int? = nil
    @State private var dragFlexAfterStartOffset: Int? = nil
    
    @State private var showTimePicker = false
    @State private var pickerStart: Date = Date()
    @State private var pickerEnd: Date = Date()

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    // Header: City name + Star
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("City name", text: Binding(
                                get: { city.customLabel ?? city.cityName },
                                set: { city.customLabel = $0 }
                            ))
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)

                            // Timezone badge
                            Text(gmtString(for: city))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.08, green: 0.1, blue: 0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }

                        Spacer()

                        Button {
                            city.isStarred.toggle()
                        } label: {
                            Image(systemName: city.isStarred ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundColor(city.isStarred ? .yellow : .white)
                        }
                    }
                    .padding(.top, 24)

                    // Availability Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Availability")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 8)

                        // Main availability hours
                        HStack(spacing: 0) {
                            Text(OverlapStore.formatMinutes(city.availabilityStart))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("  TO  ")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white.opacity(0.7))

                            Text(OverlapStore.formatMinutes(city.availabilityEnd))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3), radius: 10, x: 0, y: 5)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture {
                            let cal = Calendar.current
                            var sComps = DateComponents()
                            sComps.hour = city.availabilityStart / 60
                            sComps.minute = city.availabilityStart % 60
                            pickerStart = cal.date(from: sComps) ?? Date()

                            var eComps = DateComponents()
                            eComps.hour = city.availabilityEnd / 60
                            eComps.minute = city.availabilityEnd % 60
                            pickerEnd = cal.date(from: eComps) ?? Date()

                            showTimePicker = true
                        }

                        // Flexible hours before
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.1, blue: 0.15))
                                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                Capsule(style: .continuous)
                                    .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(city.flexMinutesBefore) / 240.0 + 40)))
                                    .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.2), radius: 6, x: 0, y: 0)

                                Text("Flexible \(formatHours(mins: city.flexMinutesBefore)) before")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if dragFlexBeforeStartOffset == nil {
                                            dragFlexBeforeStartOffset = city.flexMinutesBefore
                                        }
                                        let step = Int(value.translation.width / 15) * 30
                                        city.flexMinutesBefore = max(0, min(360, (dragFlexBeforeStartOffset ?? 0) + step))
                                    }
                                    .onEnded { _ in
                                        dragFlexBeforeStartOffset = nil
                                    }
                            )
                            .onTapGesture {
                                city.flexMinutesBefore = city.flexMinutesBefore >= 240 ? 0 : city.flexMinutesBefore + 30
                            }
                        }
                        .frame(height: 54)

                        // Flexible hours after
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.1, blue: 0.15))
                                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                Capsule(style: .continuous)
                                    .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(city.flexMinutesAfter) / 240.0 + 40)))
                                    .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.2), radius: 6, x: 0, y: 0)

                                Text("and \(formatHours(mins: city.flexMinutesAfter)) after")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if dragFlexAfterStartOffset == nil {
                                            dragFlexAfterStartOffset = city.flexMinutesAfter
                                        }
                                        let step = Int(value.translation.width / 15) * 30
                                        city.flexMinutesAfter = max(0, min(360, (dragFlexAfterStartOffset ?? 0) + step))
                                    }
                                    .onEnded { _ in
                                        dragFlexAfterStartOffset = nil
                                    }
                            )
                            .onTapGesture {
                                city.flexMinutesAfter = city.flexMinutesAfter >= 240 ? 0 : city.flexMinutesAfter + 30
                            }
                        }
                        .frame(height: 54)
                    }

                    if showNotes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.gray)
                            
                            if #available(macOS 13.0, iOS 16.0, *) {
                                TextEditor(text: $city.notes)
                                    .focused($notesFocused)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(red: 0.06, green: 0.08, blue: 0.12))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            } else {
                                TextEditor(text: $city.notes)
                                    .focused($notesFocused)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(red: 0.06, green: 0.08, blue: 0.12))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Spacer()
                    }

                    // Bottom Actions
                    HStack(spacing: 24) {
                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showNotes.toggle()
                                if showNotes {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        notesFocused = true
                                    }
                                } else {
                                    notesFocused = false
                                }
                            }
                        } label: {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(showNotes ? .white : Color.gray)
                                .frame(width: 56, height: 56)
                                .background(showNotes ? LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .shadow(color: showNotes ? Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }

                        Button {
                            city.isStarred.toggle()
                        } label: {
                            Image(systemName: city.isStarred ? "pin.fill" : "pin")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(city.isStarred ? .white : Color.gray)
                                .frame(width: 56, height: 56)
                                .background(city.isStarred ? LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .shadow(color: city.isStarred ? Color.orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        }

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.red.opacity(0.8))
                                .frame(width: 56, height: 56)
                                .background(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }

                        Spacer()
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDragIndicator(.visible)
        .alert("Delete City", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.removeCity(id: city.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(city.displayName) from your overlap view?")
        }
        .onDisappear {
            // Save changes
            store.updateCity(city)
        }
        .sheet(isPresented: $showTimePicker) {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Set Availability")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 24)

                    HStack {
                        Text("Start Time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        DatePicker("", selection: $pickerStart, displayedComponents: .hourAndMinute)
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
                        DatePicker("", selection: $pickerEnd, displayedComponents: .hourAndMinute)
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
                        city.availabilityStart = cal.component(.hour, from: pickerStart) * 60 + cal.component(.minute, from: pickerStart)
                        city.availabilityEnd = cal.component(.hour, from: pickerEnd) * 60 + cal.component(.minute, from: pickerEnd)
                        showTimePicker = false
                    } label: {
                        Text("Save")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(14)
                            .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            #if os(iOS)
            .presentationDetents([.fraction(0.45), .medium])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private func gmtString(for city: OverlapCity) -> String {
        let offsetSeconds = city.timeZone.secondsFromGMT(for: store.adjustedDate)
        let hours = offsetSeconds / 3600
        let minutes = abs(offsetSeconds % 3600) / 60
        if hours == 0 && minutes == 0 { return "GMT" }
        let sign = hours >= 0 ? "+" : ""
        if minutes == 0 {
            return String(format: "GMT%@%d", sign, hours)
        } else {
            return String(format: "GMT%@%d:%02d", sign, hours, minutes)
        }
    }
    
    private func formatHours(mins: Int) -> String {
        if mins == 0 { return "0 hours" }
        let h = mins / 60
        let m = mins % 60
        if m == 0 {
            return "\(h) hour\(h == 1 ? "" : "s")"
        } else if h == 0 {
            return "\(m) min"
        } else {
            return "\(h)h \(m)m"
        }
    }
}
