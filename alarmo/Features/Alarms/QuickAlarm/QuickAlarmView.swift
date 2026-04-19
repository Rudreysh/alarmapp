import SwiftUI

struct QuickAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    let onClose: () -> Void
    
    @StateObject private var viewModel = QuickAlarmViewModel()
    @State private var showSoundEditor = false
    @State private var showWallpaperPicker = false
    @State private var showTimePicker = false
    @State private var showAccountabilityInfo = false
    @State private var showGentleWakeUpPicker = false
    @State private var showWakeUpCheck = false
    @State private var showTimeZonePicker = false
    @State private var showPresetEditor = false
    
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background matching alarm UI
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Main Timer Display
                        Button(action: { showTimePicker = true }) {
                            VStack(spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(viewModel.minutes)")
                                        .font(.system(size: 72, weight: .bold, design: .rounded))
                                        .foregroundColor(Colors.accentTeal)
                                    Text("m")
                                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                                        .foregroundColor(Colors.textSecondary)
                                    
                                    Text("\(viewModel.seconds)")
                                        .font(.system(size: 72, weight: .bold, design: .rounded))
                                        .foregroundColor(Colors.accentTeal)
                                        .padding(.leading, 8)
                                    Text("s")
                                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                                        .foregroundColor(Colors.textSecondary)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 13))
                                    Text("Ring at \(viewModel.fireDateString)")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                            }
                            .padding(.vertical, 32)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Colors.cardSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                            )
                            // Reset button in the top-right
                            .overlay(alignment: .topTrailing) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) { viewModel.reset() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Colors.textSecondary)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.white.opacity(0.06)))
                                }
                                .padding(16)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        
                        // Presets Section
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Colors.accentTeal)
                                Text("Quick Presets")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Button("Edit") {
                                    showPresetEditor = true
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.accentTeal)
                            }
                            .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(viewModel.presets) { preset in
                                    QuickPresetTile(
                                        icon: preset.iconName,
                                        color: colorForPreset(preset.colorKey),
                                        title: preset.title,
                                        timeStr: preset.timeLabel,
                                        action: { viewModel.setPreset(preset) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Settings Section
                        VStack(spacing: 24) {
                            
                            // SOUND & BEHAVIOR
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SOUND & BEHAVIOR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.leading, 16)
                                
                                QuickSettingsCardView {
                                    MenuRow(
                                        icon: "bell.fill",
                                        title: "Alarm Sound",
                                        value: viewModel.selectedSoundId
                                    ) {
                                        showSoundEditor = true
                                    }
                                    
                                    Divider().padding(.leading, 52).opacity(0.3)
                                    
                                    MenuRow(
                                        icon: "sun.max.fill",
                                        title: "Gentle Wake-Up",
                                        value: viewModel.gentleWakeUpSeconds == 0 ? "Off" : "\(viewModel.gentleWakeUpSeconds) seconds"
                                    ) {
                                        showGentleWakeUpPicker = true
                                    }
                                    
                                    Divider().padding(.leading, 52).opacity(0.3)
                                    
                                    MenuRow(
                                        icon: "checkmark.shield.fill",
                                        title: "Wake-Up Check",
                                        value: viewModel.wakeUpCheckEnabled ? "On" : "Off"
                                    ) {
                                        showWakeUpCheck = true
                                    }
                                }
                            }
                            
                            // TIME ZONE ANCHOR
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TIME ZONE ANCHOR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.leading, 16)
                                
                                QuickSettingsCardView {
                                    Toggle(isOn: Binding(
                                        get: { viewModel.timeZoneMode == .custom },
                                        set: { isOn in
                                            viewModel.timeZoneMode = isOn ? .custom : .local
                                            if isOn && viewModel.timeZoneIdentifier == nil {
                                                viewModel.timeZoneIdentifier = TimeZone.current.identifier
                                            }
                                        }
                                    )) {
                                        Text("Anchor to Time Zone")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding()
                                    
                                    if viewModel.timeZoneMode == .custom {
                                        Divider().padding(.leading, 16).opacity(0.3)
                                        
                                        MenuRow(
                                            icon: "globe",
                                            title: "Time Zone",
                                            value: viewModel.timeZoneCity ?? viewModel.timeZoneIdentifier ?? "Select"
                                        ) {
                                            showTimeZonePicker = true
                                        }
                                    }
                                }
                            }
                            
                            // ALARM LOCK
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ALARM LOCK")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.leading, 16)
                                
                                QuickSettingsCardView {
                                    Toggle(isOn: $viewModel.blockAppsEnabled) {
                                        Text("Block all apps until mission is solved")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding()

                                    Divider().padding(.leading, 16).opacity(0.3)
                                    Toggle(isOn: $viewModel.shutdownProtectionEnabled) {
                                        Text("Disable app delete/switch off")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding()
                                }
                            }
                            
                            // WALLPAPER
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WALLPAPER")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.leading, 16)
                                
                                QuickSettingsCardView {
                                    MenuRow(
                                        icon: "photo.fill",
                                        title: "Wallpaper",
                                        value: "Select",
                                        thumbnail: resolvedWallpaperImage
                                    ) {
                                        showWallpaperPicker = true
                                    }
                                    
                                    Divider().padding(.leading, 16).opacity(0.3)
                                    
                                    Toggle(isOn: $viewModel.dailyMotivationEnabled) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "quote.bubble.fill")
                                                .foregroundColor(Colors.accentTeal)
                                            Text("Daily Motivation")
                                                .foregroundColor(Colors.textPrimary)
                                        }
                                    }
                                    .padding()

                                    if viewModel.dailyMotivationEnabled {
                                        Text("Displays a new motivational quote each day when the alarm rings.")
                                            .font(.caption)
                                            .foregroundColor(Colors.textSecondary)
                                            .padding(.horizontal)
                                            .padding(.bottom, 8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Bottom spacer
                        Color.clear.frame(height: 40)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onClose)
                        .foregroundColor(Colors.textSecondary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Quick Alarm")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        onClose()
                        DispatchQueue.main.async {
                            viewModel.save(store: alarmStore, scheduler: scheduler)
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.accentTeal)
                    }
                }
            }
        }
        .sheet(isPresented: $showSoundEditor) {
            SoundSettingsView(
                soundName: $viewModel.selectedSoundId,
                volume: $viewModel.volume,
                vibrate: $viewModel.vibrateEnabled,
                bypassSilentMode: $viewModel.bypassSilentMode,
                soundPlayer: soundPlayer
            )
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.selectedWallpaperId)
        }
        .sheet(isPresented: $showTimePicker) {
            QuickAlarmTimePickerView(
                minutes: $viewModel.minutes,
                seconds: $viewModel.seconds
            )
        }
        .sheet(isPresented: $showPresetEditor) {
            QuickPresetManagerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAccountabilityInfo) {
            AccountabilityInfoView()
        }
        .sheet(isPresented: $showGentleWakeUpPicker) {
            GentleWakeUpPickerView(
                selectedSeconds: $viewModel.gentleWakeUpSeconds,
                maxVolume: $viewModel.volume,
                soundName: viewModel.selectedSoundId,
                soundPlayer: soundPlayer
            )
        }
        .sheet(isPresented: $showWakeUpCheck) {
            WakeUpCheckView(isEnabled: $viewModel.wakeUpCheckEnabled)
        }
        .sheet(isPresented: $showTimeZonePicker) {
            TimeZonePickerView(
                selectedIdentifier: $viewModel.timeZoneIdentifier,
                selectedCity: $viewModel.timeZoneCity,
                selectedMode: $viewModel.timeZoneMode
            )
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                soundPlayer.stop()
            }
        }
    }
    
    var resolvedWallpaperImage: Image? {
        guard let uiImage = WallpaperImageResolver.resolveImage(for: viewModel.selectedWallpaperId) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private func colorForPreset(_ key: String) -> Color {
        switch key {
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        default: return Colors.accentTeal
        }
    }
}

// Reusable preset tile styled exactly like preset buttons in Quick Settings
struct QuickPresetTile: View {
    let icon: String
    let color: Color
    let title: String
    let timeStr: String
    let action: () -> Void
    
    private var displayIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "alarm.fill" : trimmed
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: displayIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .cornerRadius(12)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                    Text(timeStr)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Colors.accentTeal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Colors.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Colors.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// Standardized list row / card pattern
private struct QuickSettingsCardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(16)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct QuickPresetManagerSheet: View {
    @ObservedObject var viewModel: QuickAlarmViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingPreset: QuickAlarmPreset?
    @State private var showCreatePreset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Your Presets") {
                    ForEach(viewModel.presets) { preset in
                        HStack(spacing: 12) {
                            Image(systemName: preset.iconName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Colors.cardStroke.opacity(0.9)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(preset.timeLabel)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(Colors.accentTeal)
                            }

                            Spacer()

                            Button("Edit") {
                                editingPreset = preset
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.accentTeal)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Colors.cardSurface)
                    }
                    .onDelete(perform: viewModel.deletePresets)
                }

                Section {
                    Button {
                        showCreatePreset = true
                    } label: {
                        Label("Add Custom Preset", systemImage: "plus.circle.fill")
                            .foregroundColor(Colors.accentTeal)
                    }
                    .listRowBackground(Colors.cardSurface)
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.resetPresetsToDefault()
                    } label: {
                        Label("Reset to Default Presets", systemImage: "arrow.counterclockwise")
                    }
                    .listRowBackground(Colors.cardSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Colors.bgPrimary.ignoresSafeArea())
            .navigationTitle("Edit Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $editingPreset) { preset in
            QuickPresetEditor(
                title: "Edit Preset",
                initialName: preset.title,
                initialMinutes: preset.minutes,
                initialSeconds: preset.seconds
            ) { name, minutes, seconds in
                viewModel.updatePreset(id: preset.id, title: name, minutes: minutes, seconds: seconds)
            }
        }
        .sheet(isPresented: $showCreatePreset) {
            QuickPresetEditor(
                title: "New Preset",
                initialName: "",
                initialMinutes: 10,
                initialSeconds: 0
            ) { name, minutes, seconds in
                viewModel.addCustomPreset(title: name, minutes: minutes, seconds: seconds)
            }
        }
    }
}

private struct QuickPresetEditor: View {
    let title: String
    let initialName: String
    let initialMinutes: Int
    let initialSeconds: Int
    let onSave: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var minutes: Int
    @State private var seconds: Int

    init(
        title: String,
        initialName: String,
        initialMinutes: Int,
        initialSeconds: Int,
        onSave: @escaping (String, Int, Int) -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.initialMinutes = initialMinutes
        self.initialSeconds = initialSeconds
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _minutes = State(initialValue: initialMinutes)
        _seconds = State(initialValue: initialSeconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("Enter name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Time") {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...180)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, minutes, seconds)
                        dismiss()
                    }
                }
            }
        }
    }
}
