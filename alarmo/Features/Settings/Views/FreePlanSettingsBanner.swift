import SwiftUI

struct FreePlanSettingsBanner: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Faint seal icon on the right (approximated with SF Symbols)
                ZStack {
                    Image(systemName: "laurel.leading")
                        .font(.system(size: 80, weight: .ultraLight))
                        .offset(x: -25)
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 80, weight: .ultraLight))
                        .offset(x: 25)
                    Image(systemName: "hexagon")
                        .font(.system(size: 40, weight: .light))
                }
                .foregroundColor(Colors.textSecondary.opacity(0.1))
                .offset(x: 10, y: -20)
                .clipped()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're on a Free Plan")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("Upgrade to focus better with")
                            .font(.system(size: 15))
                            .foregroundColor(Colors.textSecondary)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Colors.textPrimary)
                        Text("Pro")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    Text("Try for 0,00 €")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.65, green: 0.82, blue: 1.0), Colors.accentTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .padding(.top, 12)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Colors.cardSurface)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Colors.bgPrimary.ignoresSafeArea()
        FreePlanSettingsBanner(action: {})
    }
}
