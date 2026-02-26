import SwiftUI

struct AddCountdownPresetView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: CountdownPresetStore
    
    @State private var name: String = ""
    @State private var emoji: String = "⏱️"
    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
    @State private var selectedColor: Color = TimerPalette.accent
    @State private var autoRepeat: Bool = false
    @State private var repeatCount: Int = 1
    
    let colors: [Color] = [
        TimerPalette.accent,
        Color(red: 0.20, green: 0.50, blue: 0.95), // Blue
        Color(red: 0.60, green: 0.25, blue: 0.92), // Purple
        Color(red: 0.95, green: 0.55, blue: 0.15), // Orange
        Color(red: 0.95, green: 0.25, blue: 0.65), // Pink
        Color(red: 0.20, green: 0.78, blue: 0.45), // Green
        Color(red: 0.88, green: 0.22, blue: 0.22)  // Red
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Emoji & Preview
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(selectedColor.opacity(0.15))
                                    .frame(width: 100, height: 100)
                                
                                Text(emoji)
                                    .font(.system(size: 50))
                            }
                            
                            TextField("Preset Name", text: $name)
                                .font(.system(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Duration Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DURATION")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                            
                            HStack {
                                TimePickerColumn(value: $hours, range: 0...23, suffix: "h")
                                TimePickerColumn(value: $minutes, range: 0...59, suffix: "m")
                                TimePickerColumn(value: $seconds, range: 0...59, suffix: "s")
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                        }
                        .padding(.horizontal)
                        
                        // Color Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COLOR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textTertiary)
                            
                            HStack(spacing: 15) {
                                ForEach(colors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            withAnimation { selectedColor = color }
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Auto-Repeat Toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $autoRepeat) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto-Repeat")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Restart the timer automatically when finished")
                                        .font(.system(size: 13))
                                        .foregroundColor(Colors.textSecondary)
                                }
                            }
                            .tint(selectedColor)
                            
                            if autoRepeat {
                                HStack {
                                    Text("Repeat Times")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Colors.textSecondary)
                                    Spacer()
                                    Stepper("\(repeatCount == 0 ? "Infinite" : "\(repeatCount)")", value: $repeatCount, in: 0...100)
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 100)
                }
                
                // Save Button
                VStack {
                    Spacer()
                    PrimaryButton(title: "Save Preset", style: .blueGlass) {
                        savePreset()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .disabled(name.isEmpty || (hours == 0 && minutes == 0 && seconds == 0))
                    .opacity(name.isEmpty || (hours == 0 && minutes == 0 && seconds == 0) ? 0.5 : 1.0)
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
    }
    
    private func savePreset() {
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)
        
        // Convert Color to CodableColor
        let components = selectedColor.cgColor?.components ?? [0, 0, 0]
        let codableColor = CountdownPreset.CodableColor(r: Double(components[0]), 
                                                        green: Double(components[1]), 
                                                        blue: Double(components[2]))
        
        let newPreset = CountdownPreset(
            name: name,
            emoji: emoji,
            duration: totalSeconds,
            color: codableColor,
            autoRepeat: autoRepeat,
            repeatCount: repeatCount
        )
        
        store.add(newPreset)
        dismiss()
    }
}

struct TimePickerColumn: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    
    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { i in
                    Text("\(i)").tag(i)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            
            Text(suffix)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
