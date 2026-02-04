import SwiftUI

struct QuickAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    let onClose: () -> Void
    
    @StateObject private var viewModel = QuickAlarmViewModel()
    @State private var showSoundEditor = false
    @State private var showWallpaperPicker = false
    @State private var showTimePicker = false
    
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background matching alarm UI
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Top Spacer
                        Color.clear.frame(height: 12)
                        
                        // Main Timer Display - Tappable
                        Button(action: { showTimePicker = true }) {
                            VStack(spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    // Minutes Display
                                    Text("\(viewModel.minutes)")
                                        .font(.system(size: 72, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                    
                                    Text("min")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    
                                    // Seconds Display
                                    Text("\(viewModel.seconds)")
                                        .font(.system(size: 72, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                    
                                    Text("sec")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    
                                    // Reset Button
                                    Button(action: {
                                        withAnimation { viewModel.reset() }
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Colors.textSecondary)
                                            .frame(width: 36, height: 36)
                                            .background(Colors.cardSurface)
                                            .clipShape(Circle())
                                    }
                                    .offset(y: -8)
                                }
                                
                                // Total seconds display
                                Text("\(viewModel.totalSeconds) seconds")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Colors.textTertiary)
                                
                                // Ring at time
                                Text("Ring at \(viewModel.fireDateString)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            .padding(.vertical, 24)
                        }
                        .buttonStyle(.plain)
                        
                        // Presets Grid
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                QuickPresetButton(label: "1 min", action: { viewModel.setPreset(minutes: 1, seconds: 0) })
                                QuickPresetButton(label: "5 min", action: { viewModel.setPreset(minutes: 5, seconds: 0) })
                                QuickPresetButton(label: "10 min", action: { viewModel.setPreset(minutes: 10, seconds: 0) })
                            }
                            HStack(spacing: 12) {
                                QuickPresetButton(label: "15 min", action: { viewModel.setPreset(minutes: 15, seconds: 0) })
                                QuickPresetButton(label: "30 min", action: { viewModel.setPreset(minutes: 30, seconds: 0) })
                                QuickPresetButton(label: "1 hour", action: { viewModel.setPreset(minutes: 60, seconds: 0) })
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Settings - Premium Style
                        VStack(spacing: 0) {
                            // Sound & Behavior Section
                            SectionHeader(title: "Sound & Behavior")
                            GroupedSettingsCard {
                                MenuRow(
                                    icon: "bell.fill",
                                    title: "Alarm Sound",
                                    value: viewModel.selectedSoundId
                                ) {
                                    showSoundEditor = true
                                }
                            }
                            
                            // Wallpaper Section
                            SectionHeader(title: "Wallpaper")
                            GroupedSettingsCard {
                                MenuRow(
                                    icon: "photo.fill",
                                    title: "Wallpaper",
                                    value: "Select",
                                    thumbnail: resolvedWallpaperImage
                                ) {
                                    showWallpaperPicker = true
                                }
                            }
                        }
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onClose)
                        .foregroundColor(Colors.textPrimary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Quick alarm")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.save(store: alarmStore, scheduler: scheduler)
                        onClose()
                    }) {
                        Text("Save")
                            .font(.headline)
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
        .onDisappear {
            soundPlayer.stop()
        }
    }
    
    var resolvedWallpaperImage: Image? {
        let id = viewModel.selectedWallpaperId
        
        for category in WallpaperConfig.categories {
            if id.hasPrefix(category.id + "-") {
                let filename = String(id.dropFirst(category.id.count + 1))
                if category.imageNames.contains(filename) {
                     let nameWithoutExt = (filename as NSString).deletingPathExtension
                     if let path = Bundle.main.path(forResource: nameWithoutExt, ofType: (filename as NSString).pathExtension) {
                         if let uiImage = UIImage(contentsOfFile: path) {
                             return Image(uiImage: uiImage)
                         }
                     }
                     if let path = Bundle.main.path(forResource: filename, ofType: nil, inDirectory: "BundledWallpapers/\(category.id)") {
                         if let uiImage = UIImage(contentsOfFile: path) {
                             return Image(uiImage: uiImage)
                         }
                     }
                }
            }
        }
        return nil
    }
}

struct QuickPresetButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Colors.cardSurface)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
