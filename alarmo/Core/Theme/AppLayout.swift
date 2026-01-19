import SwiftUI

enum AppSpacing {
    static let standard: CGFloat = 20
    static let small: CGFloat = 12
    static let large: CGFloat = 32
    static let cardPadding: CGFloat = 16
}

struct ScreenContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            content
                .padding(.horizontal, AppSpacing.standard)
        }
    }
}

struct BottomActionBar: View {
    let onSecondary: (() -> Void)?
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let primaryTitle: String
    
    init(primaryTitle: String, onPrimary: @escaping () -> Void, secondaryTitle: String? = nil, onSecondary: (() -> Void)? = nil) {
        self.primaryTitle = primaryTitle
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .frame(height: 30)
            
            HStack(spacing: 16) {
                if let secondaryTitle = secondaryTitle, let onSecondary = onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.headline)
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.cardSurface)
                            .cornerRadius(16)
                    }
                }
                
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Colors.accentTeal)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8) // Extra padding for safety
            .background(Colors.bgPrimary)
        }
    }
}
