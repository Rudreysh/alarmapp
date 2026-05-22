import SwiftUI

struct SecondaryActionButtonsRow: View {
    let theme: PomodoroTheme
    let showBreak: Bool
    let onBreak: () -> Void
    let onDone: () -> Void
    
    var body: some View {
        HStack(spacing: 60) {
            if showBreak {
                ActionButton(
                    icon: "cup.and.saucer.fill",
                    label: "Break",
                    theme: theme,
                    action: onBreak
                )
            }
            
            ActionButton(
                icon: "checkmark",
                label: "Done",
                theme: theme,
                action: onDone
            )
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let theme: PomodoroTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.buttonBg)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
