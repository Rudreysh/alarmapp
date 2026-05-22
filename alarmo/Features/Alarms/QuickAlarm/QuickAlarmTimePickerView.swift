import SwiftUI

struct QuickAlarmTimePickerView: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var alarmName: String
    @Binding var saveAsPreset: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settingsStore = SettingsStore.shared

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
        ZStack {
            Colors.bgPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Cancel, Title, Save)
                HStack(alignment: .center) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    Text("Quick Alarm")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        onSave()
                        dismiss()
                    }) {
                        Text("Save")
                            .foregroundColor(Colors.accentTeal)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                        TextField("", text: $alarmName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.08))
                    )
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        Text("Save as Preset")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(1)
                        Toggle("", isOn: $saveAsPreset)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                
                Spacer()
                
                // Wheel Picker Area
                ZStack {
                    // Frosted selection bar behind the selected row
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isLightMode ? Color.black.opacity(0.04) : Color.white.opacity(0.08))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(height: 48)
                    
                    HStack(spacing: 0) {
                        // Minute Picker
                        Picker("Minute", selection: $minutes) {
                            ForEach(0..<100) { m in
                                Text(String(format: "%02d", m))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("m")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .offset(y: 2)
                        
                        // Second Picker
                        Picker("Second", selection: $seconds) {
                            ForEach(0..<60) { s in
                                Text(String(format: "%02d", s))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("s")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .offset(y: 2)
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .presentationDetents([.height(395)])
        .presentationDragIndicator(.visible)
    }
}
