import SwiftUI

/// Simple detail sheet for a city — rename, working hours, star, notes, delete.
struct CityDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @State var city: OverlapCity
    @ObservedObject var store: OverlapStore
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @FocusState private var notesFocused: Bool
    
    @State private var pickerStart: Date = Date()
    @State private var pickerEnd: Date = Date()

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

    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // ── City Name & Star ──
                            HStack(alignment: .center) {
                                TextField("City name", text: Binding(
                                    get: { city.customLabel ?? city.cityName },
                                    set: { city.customLabel = $0 }
                                ))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(Colors.textPrimary)
                                .textFieldStyle(.plain)

                                Spacer()

                                Button {
                                    withAnimation(.spring()) { city.isStarred.toggle() }
                                } label: {
                                    Image(systemName: city.isStarred ? "star.fill" : "star")
                                        .font(.system(size: 22))
                                        .foregroundColor(city.isStarred ? .yellow : Colors.textTertiary)
                                }
                            }
                            .padding(.top, 28)

                            // ── Timezone Badge ──
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 13))
                                Text(gmtString(for: city))
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .foregroundColor(Colors.textSecondary)
                            .padding(.top, -12)

                            // ── Working Hours ──
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Working Hours")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .textCase(.uppercase)

                                VStack(spacing: 16) {
                                    // Start Time
                                    HStack {
                                        Label("Start", systemImage: "sunrise.fill")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Colors.textPrimary)
                                        Spacer()
                                        DatePicker("", selection: $pickerStart, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .colorScheme(isLightMode ? .light : .dark)
                                            .tint(Color(red: 0.0, green: 0.7, blue: 0.5))
                                    }

                                    Divider().background(Colors.cardStroke)

                                    // End Time
                                    HStack {
                                        Label("End", systemImage: "sunset.fill")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Colors.textPrimary)
                                        Spacer()
                                        DatePicker("", selection: $pickerEnd, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .colorScheme(isLightMode ? .light : .dark)
                                            .tint(Color(red: 0.0, green: 0.7, blue: 0.5))
                                    }
                                }
                                .padding(16)
                                .background(Colors.cardSurface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Colors.cardStroke, lineWidth: 1))
                            }

                            // ── Notes ──
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notes")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .textCase(.uppercase)

                                if #available(iOS 16.0, *) {
                                    TextEditor(text: $city.notes)
                                        .focused($notesFocused)
                                        .font(.system(size: 15))
                                        .foregroundColor(Colors.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .padding(12)
                                        .frame(height: 100)
                                        .background(Colors.cardSurface)
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Colors.cardStroke, lineWidth: 1))
                                } else {
                                    TextEditor(text: $city.notes)
                                        .focused($notesFocused)
                                        .font(.system(size: 15))
                                        .foregroundColor(Colors.textPrimary)
                                        .padding(12)
                                        .frame(height: 100)
                                        .background(Colors.cardSurface)
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Colors.cardStroke, lineWidth: 1))
                                }
                            }

                            // ── Delete Button ──
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                    Text("Remove City")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.15), lineWidth: 1))
                            }
                            .padding(.top, 8)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 24)
                    }

                    // ── Save Button ──
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.6, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.55)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 0.0, green: 0.6, blue: 0.4).opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            syncPickersFromCity()
        }
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
            syncCityFromPickers()
            store.updateCity(city)
        }
    }

    // MARK: - Helpers

    private func syncPickersFromCity() {
        let cal = Calendar.current
        var sComps = DateComponents()
        sComps.hour = city.availabilityStart / 60
        sComps.minute = city.availabilityStart % 60
        pickerStart = cal.date(from: sComps) ?? Date()

        var eComps = DateComponents()
        eComps.hour = city.availabilityEnd / 60
        eComps.minute = city.availabilityEnd % 60
        pickerEnd = cal.date(from: eComps) ?? Date()
    }

    private func syncCityFromPickers() {
        let cal = Calendar.current
        city.availabilityStart = cal.component(.hour, from: pickerStart) * 60 + cal.component(.minute, from: pickerStart)
        city.availabilityEnd = cal.component(.hour, from: pickerEnd) * 60 + cal.component(.minute, from: pickerEnd)
    }

    private func saveAndDismiss() {
        syncCityFromPickers()
        store.updateCity(city)
        dismiss()
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
}
