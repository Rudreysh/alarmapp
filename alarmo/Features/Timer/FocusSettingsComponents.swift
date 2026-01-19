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
                .bodyText()
                .foregroundColor(Colors.textSecondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Colors.textSecondary)
        }
        .padding(.vertical, 12)
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
        .padding(.vertical, 12)
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
                .tint(Colors.accentRed)
        }
        .padding(.vertical, 8)
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
                .captionText()
                .fontWeight(.bold)
                .foregroundColor(Colors.textTertiary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(Colors.cardSurface)
            .cornerRadius(16)
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
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                Text(title)
                    .screenTitle()
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                
                ZStack {
                    HStack(spacing: 12) {
                        Picker("", selection: $selection) {
                            ForEach(range, id: \.self) { value in
                                Text("\(value)")
                                    .font(.title) 
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: 150)
                        
                        if !suffix.isEmpty {
                            Text(suffix)
                                .cardTitle()
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 20)
                
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                 BottomActionBar(
                    primaryTitle: "Done",
                    onPrimary: { onClose() },
                    secondaryTitle: "Cancel",
                    onSecondary: { onClose() }
                 )
            }
        }
    }
}

