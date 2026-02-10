import SwiftUI

struct AddTimerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var iconType: Int = 0 // 0: Icon, 1: Text
    @State private var selectedIcon: String = "smiley"
    @State private var timerMode: TimerMode = .pomo
    @State private var pomoMinutes: Int = 26
    @State private var showMinutesPicker = false
    
    var onSave: ((String, String, TimerMode, Int) -> Void)?
    
    let icons = ["smiley", "dog", "heart", "book", "figure.run", "sun.max", "drop", "cat", "bubble.left", "pencil"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Name Input
                        HStack {
                            TextField("Name", text: $name)
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Image(systemName: "link")
                                .foregroundColor(Colors.textTertiary)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        
                        // Icon Section
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Text("Icon")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                            
                            VStack(spacing: 0) {
                                // Picker placeholder
                                Picker("", selection: $iconType) {
                                    Text("Icon").tag(0)
                                    Text("Text").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .padding(16)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                                    ForEach(icons, id: \.self) { icon in
                                        iconCircle(for: icon)
                                    }
                                }
                                .padding(16)
                            }
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                        }
                        
                        // Timer Mode Section
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Text("Timer mode")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                            
                            VStack(spacing: 0) {
                                radioButton(mode: .pomo, title: "Pomodoro") {
                                    HStack(spacing: 8) {
                                        Button(action: { showMinutesPicker = true }) {
                                            Text("\(pomoMinutes)")
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Colors.bgSecondary)
                                                .cornerRadius(4)
                                                .foregroundColor(Colors.textPrimary)
                                        }
                                        Text("Minutes")
                                    }
                                }
                                Divider().background(Colors.cardStroke)
                                radioButton(mode: .stopwatch, title: "Stopwatch") {
                                    EmptyView()
                                }
                            }
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                        }
                    }
                    .padding(Spacing.l)
                }
            }
            .navigationTitle("Add Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let finalName = name.isEmpty ? (timerMode == .pomo ? "Focus" : "Stopwatch") : name
                        onSave?(finalName, selectedIcon, timerMode, pomoMinutes)
                        dismiss()
                    }
                    .foregroundColor(Colors.accentRed)
                }
            }
            .sheet(isPresented: $showMinutesPicker) {
                FocusWheelPickerView(title: "Pomodoro Duration", selection: $pomoMinutes, range: 1...60, suffix: "mins") {
                    showMinutesPicker = false
                }
            }
        }
    }
    
    private func iconCircle(for icon: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.3)) // Random color placeholder
                .frame(width: 44, height: 44)
            
            Image(systemName: icon)
                .foregroundColor(.white)
            
            if selectedIcon == icon {
                Circle()
                    .stroke(Colors.accentRed, lineWidth: 2)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Colors.accentRed)
                    .background(Circle().fill(Colors.textPrimary))
                    .offset(x: 16, y: 16)
            }
        }
        .onTapGesture {
            selectedIcon = icon
        }
    }
    
    private func radioButton<Content: View>(mode: TimerMode, title: String, @ViewBuilder extra: () -> Content) -> some View {
        Button(action: { timerMode = mode }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(timerMode == mode ? Colors.accentRed : Colors.textTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if timerMode == mode {
                        Circle()
                            .fill(Colors.accentRed)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                extra()
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
    }
}
