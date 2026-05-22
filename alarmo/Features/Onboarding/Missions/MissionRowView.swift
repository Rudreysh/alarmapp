import SwiftUI

struct MissionRowView: View {
    let option: MissionOption
    let isSelected: Bool
    let onTap: () -> Void
    var onPreview: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            if option.id == .off {
                fullWidthRow
            } else {
                gridCard
            }
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text("Mission: \(option.title)"))
        .accessibilityValue(Text(isSelected ? "Selected" : ""))
    }
    
    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                if let icon = option.icon, let background = option.iconBackground {
                    ZStack {
                        Circle()
                            .fill(background)
                            .frame(width: 33, height: 33)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isSelected ? Colors.accentTeal : Colors.textPrimary)
                    }
                }
                Spacer()
                
                // Top-right selection circle checkmark
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: 2)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Colors.accentTeal)
                            .frame(width: 9, height: 9)
                    }
                }
            }
            
            Spacer()
            
            Text(option.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Spacing.xs)
                
            if let onPreview = onPreview {
                Button(action: onPreview) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Preview")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Colors.accentTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Colors.accentTeal.opacity(0.15))
                    .cornerRadius(10)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .background(isSelected ? Colors.accentTeal.opacity(0.12) : Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(14)
        .appShadow(Shadows.card)
    }
    
    private var fullWidthRow: some View {
        HStack(spacing: Spacing.m) {
            if let icon = option.icon, let background = option.iconBackground {
                ZStack {
                    Circle()
                        .fill(background)
                        .frame(width: 33, height: 33)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isSelected ? Colors.accentTeal : Colors.textPrimary)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Colors.bgPrimary)
                        .frame(width: 33, height: 33)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isSelected ? Colors.accentTeal : Colors.textSecondary)
                }
            }
            
            Text(option.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                
            Spacer()
            
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: 2)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Circle()
                        .fill(Colors.accentTeal)
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(isSelected ? Colors.accentTeal.opacity(0.12) : Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(14)
        .appShadow(Shadows.card)
    }
}
