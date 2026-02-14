import SwiftUI

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    let value: String
    var showHotBadge: Bool = false
    var thumbnail: Image? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 24)
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Colors.textPrimary)
                
                // Hot Badge
                if showHotBadge {
                    Text("Hot")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Thumbnail
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                        .clipped()
                }
                
                // Value
                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Digital Time Display
struct DigitalTimeDisplay: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var second: Int
    
    var body: some View {
        SunRayTimePickerView(hour: $hour, minute: $minute, second: $second)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

// MARK: - Sub-Editors (Sheets)

struct LabelSettingsView: View {
    @Binding var name: String
    @Binding var emoji: String
    @Binding var showEmojiPicker: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    Button(action: { showEmojiPicker = true }) {
                        Text(emoji)
                            .font(.system(size: 60))
                            .frame(width: 100, height: 100)
                            .background(Colors.cardSurface)
                            .clipShape(Circle())
                    }
                    
                    TextField("Alarm Name", text: $name)
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
                .navigationTitle("Label")
                .toolbar {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RepeatSettingsView: View {
    @Binding var isDaily: Bool
    @Binding var selectedWeekdays: Set<Int>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                List {
                    Section {
                        Toggle("Daily", isOn: $isDaily)
                            .listRowBackground(Colors.cardSurface)
                    }
                    
                    if !isDaily {
                        Section {
                            ForEach(1...7, id: \.self) { day in
                                Button(action: {
                                    if selectedWeekdays.contains(day) {
                                        selectedWeekdays.remove(day)
                                    } else {
                                        selectedWeekdays.insert(day)
                                    }
                                }) {
                                    HStack {
                                        Text(Calendar.current.weekdaySymbols[day-1])
                                            .foregroundColor(Colors.textPrimary)
                                        Spacer()
                                        if selectedWeekdays.contains(day) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Colors.accentTeal)
                                        }
                                    }
                                }
                                .listRowBackground(Colors.cardSurface)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Repeat")
                .toolbar {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SoundSettingsView: View {
    @Binding var soundName: String
    @Binding var volume: Float
    @Binding var vibrate: Bool
    @Binding var bypassSilentMode: Bool
    // showPicker binding removed; using NavigationLink instead to fix "Two Sheets" bug
    @ObservedObject var soundPlayer: SoundPreviewPlayer
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    
                    // Sound Name Row with Play Button and Navigation
                    HStack(spacing: 12) {
                        // Play/Stop Button
                        Button(action: {
                            if soundPlayer.isPlaying && soundPlayer.playingResourceName == soundName {
                                soundPlayer.stop()
                            } else {
                                soundPlayer.play(resourceName: soundName, volume: volume)
                            }
                        }) {
                            Image(systemName: (soundPlayer.isPlaying && soundPlayer.playingResourceName == soundName) ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Colors.accentTeal)
                        }
                        .buttonStyle(.plain)
                        
                        // Picker Link
                        NavigationLink(destination: SoundPickerView(selectedSound: $soundName, soundPlayer: soundPlayer)) {
                            HStack {
                                Text("Sound")
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                Text(soundName)
                                    .foregroundColor(Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Colors.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                            .padding(.leading)
                        
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(Colors.textSecondary)
                            Slider(value: Binding(
                                get: { volume },
                                set: { newVal in
                                    volume = newVal
                                    if soundPlayer.isPlaying && soundPlayer.playingResourceName == soundName {
                                        soundPlayer.setVolume(newVal) // SoundPreviewPlayer Protocol doesn't have setVolume, checking class...
                                    }
                                }
                            ), in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Toggle(isOn: $vibrate) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(Colors.textPrimary)
                            Text("Vibrate")
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Toggle(isOn: $bypassSilentMode) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(Colors.textPrimary)
                            Text("Ring in Silent Mode")
                                .foregroundColor(Colors.textPrimary)
                        }
                    }
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .navigationTitle("Alarm Sound")
                .toolbar {
                    Button("Done") {
                        soundPlayer.stop()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Mission Slots View (Multi-Mission)

struct MissionSlotsView: View {
    let missions: [AlarmMission]
    // Use fixed 5 slots per request
    let onAdd: () -> Void
    let onEdit: (Int) -> Void
    let onRemove: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
             if !missions.isEmpty {
                 HStack {
                     Spacer()
                     Text("\(missions.count)/4")
                         .font(.caption)
                         .foregroundColor(Colors.textTertiary)
                 }
                 .padding(.horizontal, 4)
             }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // 1. Existing Missions
                    ForEach(Array(missions.enumerated()), id: \.offset) { index, mission in
                        MissionSlotItem(
                            mission: mission,
                            state: .filled,
                            onTap: { onEdit(index) },
                            onRemove: { onRemove(index) }
                        )
                    }
                    
                    // 2. Add Button (if less than 4)
                     if missions.count < 4 {
                        MissionSlotItem(
                             mission: nil,
                             state: .empty,
                             onTap: onAdd,
                             onRemove: {}
                         )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
    }
}

enum MissionSlotState {
    case filled
    case empty
}

struct MissionSlotItem: View {
    let mission: AlarmMission?
    let state: MissionSlotState
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Container
            VStack(spacing: 8) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(state == .filled ? Colors.cardSurface : Color.clear)
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(state == .filled ? Colors.accentTeal.opacity(0.3) : Colors.textTertiary.opacity(0.2), lineWidth: 1.5)
                        )
                        // Dashed border for empty state
                         .overlay(
                            Group {
                                if state == .empty {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                        .foregroundColor(Colors.textTertiary.opacity(0.4))
                                }
                            }
                        )

                    // Icon
                    if let mission = mission {
                        Image(systemName: mission.iconName) 
                            .font(.system(size: 26))
                            .foregroundColor(Colors.accentTeal)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                
                // Label
                Text(state == .filled && mission != nil ? mission!.title : "Add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(state == .filled ? Colors.textPrimary : Colors.textTertiary)
                    .lineLimit(1)
                    .frame(width: 68)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Remove Button (Badge)
            if state == .filled {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Colors.textSecondary)
                        .font(.system(size: 22))
                }
                .offset(x: 6, y: -6)
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
    }
}
