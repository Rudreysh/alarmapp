import SwiftUI

struct FocusSettingsRow: View {
    let title: String
    let value: String
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Colors.textSecondary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct FocusSettingsNavigationRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .bodyText()
                    .foregroundColor(Colors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Colors.textSecondary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct FocusSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(TimerPalette.accent)
        }
        .padding(.vertical, 10)
    }
}

struct FocusSettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textSecondary.opacity(0.95))
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .timerGlassCard(cornerRadius: 16)
        }
    }
}

struct FocusWheelPickerView: View {
    let title: String
    @Binding var selection: Int
    let range: ClosedRange<Int>
    let suffix: String
    let onClose: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                Text(title)
                    .screenTitle()
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal)
                    .padding(.bottom, 26)
                
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(height: 300)
                        .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 10)
                    
                    HStack(spacing: 12) {
                        Picker("", selection: $selection) {
                            ForEach(range, id: \.self) { value in
                                Text("\(value)")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: 170)
                        
                        if !suffix.isEmpty {
                            Text(suffix)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 28)
                
                Spacer()

                HStack(spacing: 14) {
                    Button("Cancel") {
                        onClose()
                    }
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                    Button("Done") {
                        onClose()
                    }
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.20, green: 0.86, blue: 0.93),
                                        Color(red: 0.05, green: 0.72, blue: 0.82)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}
