import SwiftUI

struct QuickAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    let onClose: () -> Void
    
    @StateObject private var viewModel = QuickAlarmViewModel()
    @State private var showSoundPicker = false
    @State private var showWallpaperPicker = false
    
    private let soundPlayer = SoundPlayer() // For previewing sound
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    
    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Card
                VStack(spacing: Spacing.l) {
                    // Header
                    HStack {
                        Spacer()
                        Text("Quick alarm")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .overlay(
                        // Close button is usually top-right, but design shows centered title with X right.
                        // Implemented as HStack above.
                        EmptyView()
                    )
                    
                    // Main Timer Display
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            if viewModel.minutes > 0 {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            
                            Text("\(viewModel.minutes)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(viewModel.minutes > 0 ? .white : Colors.textSecondary)
                            
                            Text("min")
                                .font(.system(size: 32, weight: .bold)) // Design shows bold but smaller than number
                                .foregroundColor(viewModel.minutes > 0 ? .white : Colors.textSecondary)
                            
                            Button(action: {
                                withAnimation { viewModel.reset() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(8)
                                    .background(Colors.bgSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .offset(y: -10)
                        }
                        
                        Text("Ring at \(viewModel.fireDateString)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding(.vertical, Spacing.m)
                    
                    // Presets Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuickPresetButton(label: "1 min", action: { viewModel.setPreset(1) })
                        QuickPresetButton(label: "5 min", action: { viewModel.setPreset(5) })
                        QuickPresetButton(label: "10 min", action: { viewModel.setPreset(10) })
                        QuickPresetButton(label: "15 min", action: { viewModel.setPreset(15) })
                        QuickPresetButton(label: "30 min", action: { viewModel.setPreset(30) })
                        QuickPresetButton(label: "1 hours", action: { viewModel.setPreset(60) })
                    }
                    
                    // Settings
                    VStack(spacing: Spacing.m) {
                        // Sound Row
                        HStack {
                            Text("Sound")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Button(action: { showSoundPicker = true }) {
                                HStack {
                                    Text(viewModel.selectedSoundId)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Colors.textSecondary)
                                }
                            }
                        }
                        
                        // Volume + Vibrate
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(Colors.textSecondary)
                            
                            Slider(value: $viewModel.volume, in: 0...1)
                                .tint(.white)
                            
                            // Vibrate Toggle Icon
                            Button(action: { viewModel.vibrateEnabled.toggle() }) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(10)
                                    .background(Colors.bgSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Checkbox (Visual style from screenshot)
                            Image(systemName: viewModel.vibrateEnabled ? "checkmark.square.fill" : "square")
                                .font(.system(size: 24))
                                .foregroundColor(viewModel.vibrateEnabled ? Colors.accentTeal : Colors.textTertiary)
                                .onTapGesture { viewModel.vibrateEnabled.toggle() }

                        }

                        // Wallpaper Row
                        HStack {
                            Text("Alarm wallpaper")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Button(action: { showWallpaperPicker = true }) {
                                WallpaperThumbnailSmall(id: viewModel.selectedWallpaperId)
                            }
                        }
                    }
                    .padding(.top, Spacing.s)

                    // Footer Save Button
                    PrimaryButton(title: "Save") {
                        viewModel.save(store: alarmStore, scheduler: scheduler)
                        onClose()
                    }
                    .padding(.top, Spacing.m)
                    
                }
                .padding(Spacing.l)
                .background(Colors.bgPrimary)
                .cornerRadius(30, corners: [.topLeft, .topRight])
            }
        }
        .sheet(isPresented: $showSoundPicker) {
            SoundPickerView(selectedSound: $viewModel.selectedSoundId)
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.selectedWallpaperId)
        }
    }
}

struct QuickPresetButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Colors.bgSecondary)
                .cornerRadius(16)
        }
    }
}
