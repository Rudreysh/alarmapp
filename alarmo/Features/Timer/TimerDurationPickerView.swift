import SwiftUI

struct TimerDurationPickerView: View {
    let initialTotalSeconds: Int
    let segmentTitle: String
    let onSave: (Int) -> Void
    
    @State private var selectedMinutes: Int
    @State private var selectedSeconds: Int
    @Environment(\.dismiss) var dismiss
    
    init(initialTotalSeconds: Int, segmentTitle: String, onSave: @escaping (Int) -> Void) {
        self.initialTotalSeconds = initialTotalSeconds
        self.segmentTitle = segmentTitle
        self.onSave = onSave
        self._selectedMinutes = State(initialValue: initialTotalSeconds / 60)
        self._selectedSeconds = State(initialValue: initialTotalSeconds % 60)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TimerGlassBackground()
                
                VStack(spacing: 20) {
                    // Time Display & Title Area
                    VStack(spacing: 4) {
                        Text(String(format: "%02d:%02d", selectedMinutes, selectedSeconds))
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(TimerPalette.accent)
                        
                        Text(segmentTitle.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .kerning(1.5)
                    }
                    .padding(.top, 24)
                    
                    HStack(spacing: 0) {
                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(0...120, id: \.self) { i in
                                Text("\(i) m").tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        Picker("Seconds", selection: $selectedSeconds) {
                            ForEach(0..<60, id: \.self) { i in
                                Text("\(i) s").tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 180)
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        let total = (selectedMinutes * 60) + selectedSeconds
                        onSave(max(1, total)) 
                        dismiss()
                    }
                    .foregroundColor(TimerPalette.accent)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
