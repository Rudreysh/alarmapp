import SwiftUI

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .padding(.horizontal, 16)
    }
}

struct SettingsActionRow: View {
    let title: String
    var subtitle: String? = nil
    var trailingText: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    var isLast: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                if let icon = icon {
                    ZStack {
                        Circle()
                            .fill(iconColor?.opacity(0.2) ?? Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor ?? .white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                if let trailingText = trailingText {
                    Text(trailingText)
                        .font(.system(size: 17))
                        .foregroundColor(trailingText == "Not subscribed" ? .red : (trailingText == "off" ? Colors.textTertiary : Colors.textSecondary))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay(
                VStack {
                    if !isLast {
                        Spacer()
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, icon != nil ? 64 : 16)
                    }
                }
            )
        }
    }
}

struct SettingsRadioRow: View {
    let title: String
    var iconImage: String? = nil // For theme icons
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                if let iconImage = iconImage {
                    Image(iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .overlay(
                VStack {
                    if !isLast {
                        Spacer()
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.leading, 16)
                    }
                }
            )
        }
    }
}

struct SettingsCardToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    .labelsHidden()
                    .onChange(of: isOn) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }
}
