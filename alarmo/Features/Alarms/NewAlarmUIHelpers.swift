import SwiftUI

// MARK: - Section Header View
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textSecondary)
                .tracking(1.0) 
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
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Colors.cardSurface)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
