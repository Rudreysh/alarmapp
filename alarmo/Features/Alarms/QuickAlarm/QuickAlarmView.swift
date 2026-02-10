import SwiftUI

struct QuickAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    let onClose: () -> Void
    
    @StateObject private var viewModel = QuickAlarmViewModel()
    @State private var showSoundEditor = false
    @State private var showWallpaperPicker = false
    @State private var showTimePicker = false
    @State private var showAccountabilityInfo = false
    
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    private let sectionCardRadius: CGFloat = 18
    private let presetColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 3)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background matching alarm UI
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        // Top Spacer
                        Color.clear.frame(height: Spacing.s)
                        
                        // Main Timer Display - Tappable
                        Button(action: { showTimePicker = true }) {
                            VStack(spacing: Spacing.s) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    // Minutes Display
                                    Text("\(viewModel.minutes)")
                                        .font(.system(size: 68, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                    
                                    Text("min")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    
                                    // Seconds Display
                                    Text("\(viewModel.seconds)")
                                        .font(.system(size: 68, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                    
                                    Text("sec")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    
                                    // Reset Button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) { viewModel.reset() }
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Colors.textPrimary)
                                            .frame(width: 38, height: 38)
                                            .background(Colors.bgSecondary)
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
                            .padding(.vertical, Spacing.l)
                            .padding(.horizontal, Spacing.m)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: sectionCardRadius)
                                    .fill(Colors.cardSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: sectionCardRadius)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.m)
                        
                        // Presets Grid
                        LazyVGrid(columns: presetColumns, spacing: Spacing.s) {
                            QuickPresetButton(label: "1 min", action: { viewModel.setPreset(minutes: 1, seconds: 0) })
                            QuickPresetButton(label: "5 min", action: { viewModel.setPreset(minutes: 5, seconds: 0) })
                            QuickPresetButton(label: "10 min", action: { viewModel.setPreset(minutes: 10, seconds: 0) })
                            QuickPresetButton(label: "15 min", action: { viewModel.setPreset(minutes: 15, seconds: 0) })
                            QuickPresetButton(label: "30 min", action: { viewModel.setPreset(minutes: 30, seconds: 0) })
                            QuickPresetButton(label: "1 hour", action: { viewModel.setPreset(minutes: 60, seconds: 0) })
                        }
                        .padding(.horizontal, Spacing.m)
                        
                        // Settings - Premium Style
                        VStack(spacing: Spacing.s) {
                            // Sound & Behavior Section
                            SectionHeader(title: "Sound & Behavior")
                            QuickSettingsCard {
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
                            QuickSettingsCard {
                                MenuRow(
                                    icon: "photo.fill",
                                    title: "Wallpaper",
                                    value: "Select",
                                    thumbnail: resolvedWallpaperImage
                                ) {
                                    showWallpaperPicker = true
                                }
                            }

                            // Accountability Section
                            SectionHeader(title: "Accountability Shield")
                            QuickSettingsCard {
                                Toggle(isOn: $viewModel.accountabilityEnabled) {
                                    Text("Enable for this quick alarm")
                                        .foregroundColor(Colors.textPrimary)
                                }
                                .padding()

                                if viewModel.accountabilityEnabled {
                                    Divider().padding(.leading, 16).opacity(0.3)

                                    Toggle(isOn: $viewModel.blockAppsEnabled) {
                                        Text("Lock phone while ringing")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)

                                    if viewModel.blockAppsEnabled {
                                        Divider().padding(.leading, 16).opacity(0.3)
                                        BlockedAppsSelectionView()
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                    }

                                    Divider().padding(.leading, 16).opacity(0.3)

                                    Toggle(isOn: $viewModel.penaltyEnabled) {
                                        Text("Use penalty credits")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)

                                    if viewModel.penaltyEnabled {
                                        Divider().padding(.leading, 16).opacity(0.3)
                                        Stepper(
                                            "Penalty Amount (€\(viewModel.penaltyAmountEuro))",
                                            value: $viewModel.penaltyAmountEuro,
                                            in: 1...10
                                        )
                                        .foregroundColor(Colors.textPrimary)
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                    }

                                    Button {
                                        showAccountabilityInfo = true
                                    } label: {
                                        Text("How this works")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Colors.accentTeal)
                                            .padding(.horizontal)
                                            .padding(.bottom, 8)
                                    }
                                }
                            }
                        }
                        .padding(.top, Spacing.s)
                        
                        // Bottom padding
                        Color.clear.frame(height: Spacing.xl)
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
        .sheet(isPresented: $showAccountabilityInfo) {
            AccountabilityInfoView()
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
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Colors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct QuickSettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Spacing.m)
    }
}
