import SwiftUI

// MARK: - Section Header View
struct SectionHeader: View {
    let title: String
    
    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: isTiimo ? 12 : 13, weight: isTiimo ? .medium : .bold))
                .foregroundColor(isTiimo ? Colors.textTertiary : Colors.textSecondary)
                .tracking(isTiimo ? 0.72 : 1.0) 
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Grouped Card View
struct GroupedSettingsCard<Content: View>: View {
    let content: Content
    
    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Colors.cardSurface)
        .cornerRadius(isTiimo ? 20 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isTiimo ? 20 : 16)
                .stroke(isTiimo ? Colors.cardStroke : Color.clear, lineWidth: isTiimo ? 1 : 0)
        )
        .padding(.horizontal, 16)
    }
}
