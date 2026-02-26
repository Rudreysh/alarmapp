import SwiftUI

struct GentleWakeUpPickerView: View {
    private enum PreviewMode {
        case gentleWake
        case volumeTest
    }

    @Binding var selectedSeconds: Int
    @Binding var maxVolume: Float
    let soundName: String
    @ObservedObject var soundPlayer: SoundPreviewPlayer
    
    @State private var isFadeEnabled: Bool = false
    @State private var duration: Double = 60
    @State private var activePreviewMode: PreviewMode? = nil
    @Environment(\.dismiss) var dismiss

    init(selectedSeconds: Binding<Int>, maxVolume: Binding<Float>, soundName: String, soundPlayer: SoundPreviewPlayer) {
        _selectedSeconds = selectedSeconds
        _maxVolume = maxVolume
        self.soundName = soundName
        self.soundPlayer = soundPlayer
        _isFadeEnabled = State(initialValue: selectedSeconds.wrappedValue > 0)
        _duration = State(initialValue: Double(max(10, selectedSeconds.wrappedValue)))
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    Text("Alarm volume")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: {
                        updateSeconds()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // Gentle Wake Up Toggle + Preview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Gentle wake up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $isFadeEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                            .onChange(of: isFadeEnabled) { updateSeconds() }
                    }
                    
                    Text("Increase the alarm volume gradually up to the maximum level below.")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: toggleGentleWakeUpPreview) {
                        HStack(spacing: 8) {
                            Image(systemName: isGentleWakePreviewPlaying ? "stop.circle.fill" : "play.circle.fill")
                            Text(isGentleWakePreviewPlaying ? "Stop preview" : "Preview gentle wake up")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Colors.bgPrimary)
                        .cornerRadius(18)
                    }

                    Text(isFadeEnabled
                         ? "Preview uses a shortened ramp based on your selected duration."
                         : "Preview plays at the selected maximum volume when Gentle wake up is off.")
                        .font(.caption2)
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Colors.cardSurface)
                .cornerRadius(16)
                
                // Volume Card
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Maximum volume")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Text("\(Int(maxVolume * 100))%")
                            .font(.system(size: 18))
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    Slider(value: $maxVolume, in: 0...1)
                        .accentColor(Colors.textPrimary)
                    
                    HStack {
                        // Test Button
                        Button(action: toggleVolumeTestPreview) {
                            HStack {
                                Image(systemName: isVolumeTestPreviewPlaying ? "stop.circle.fill" : "play.circle.fill")
                                Text(isVolumeTestPreviewPlaying ? "Stop" : "Test")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Colors.bgPrimary) // Darker pill inside card
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding()
                .background(Colors.cardSurface)
                .cornerRadius(16)
                
                // Duration Picker (Only if Fade Enabled)
                if isFadeEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gentle wake up duration: \(Int(duration)) sec")
                            .font(.subheadline)
                            .foregroundColor(Colors.textSecondary)
                            
                        Slider(value: $duration, in: 10...120, step: 10)
                            .accentColor(Colors.accentTeal)
                            .onChange(of: duration) { updateSeconds() }
                    }
                    .padding()
                    .background(Colors.cardSurface)
                    .cornerRadius(16)
                }
                
                // Note
                Text("NOTE\nAudio alarms will use the speakers on your iPhone, iPad or an external speaker, but they cannot use the Apple Watch.")
                    .font(.caption)
                    .foregroundColor(Colors.accentOrange) // Orange warning color
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(Spacing.l)
        }
        .onDisappear {
            updateSeconds()
            soundPlayer.stop()
            activePreviewMode = nil
        }
        .onChange(of: soundPlayer.isPlaying) { isPlaying in
            if !isPlaying {
                activePreviewMode = nil
            }
        }
    }
    
    private func updateSeconds() {
        if isFadeEnabled {
            selectedSeconds = Int(duration)
        } else {
            selectedSeconds = 0
        }
    }

    private var gentleWakePreviewDuration: TimeInterval {
        guard isFadeEnabled else { return 0 }
        // Keep the preview short while still demonstrating the ramp shape.
        return max(3, min(10, duration * 0.2))
    }

    private var isGentleWakePreviewPlaying: Bool {
        activePreviewMode == .gentleWake && soundPlayer.isPlaying
    }

    private var isVolumeTestPreviewPlaying: Bool {
        activePreviewMode == .volumeTest && soundPlayer.isPlaying
    }

    private func toggleGentleWakeUpPreview() {
        if isGentleWakePreviewPlaying {
            soundPlayer.stop()
            activePreviewMode = nil
            return
        }
        activePreviewMode = .gentleWake
        soundPlayer.playWithFade(
            resourceName: soundName,
            duration: gentleWakePreviewDuration,
            maxVolume: maxVolume
        )
    }

    private func toggleVolumeTestPreview() {
        if isVolumeTestPreviewPlaying {
            soundPlayer.stop()
            activePreviewMode = nil
            return
        }
        activePreviewMode = .volumeTest
        soundPlayer.playWithFade(
            resourceName: soundName,
            duration: 0,
            maxVolume: maxVolume
        )
    }
}
