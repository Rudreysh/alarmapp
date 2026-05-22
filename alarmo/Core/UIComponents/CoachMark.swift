import SwiftUI

struct CoachMarkModifier: ViewModifier {
    var title: String
    var subtitle: String?
    @Binding var isVisible: Bool
    var alignment: Alignment
    var pointDirection: Edge
    var arrowAlignment: HorizontalAlignment
    var arrowOffsetX: CGFloat
    var bubbleOffsetX: CGFloat
    var bubbleOffsetY: CGFloat
    var color: Color = Color.red // Default to Red as per request
    
    @State private var isBouncing = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if isVisible {
                    Group {
                        if pointDirection == .top {
                            VStack(alignment: arrowAlignment, spacing: 4) {
                                arrowUp.offset(x: arrowOffsetX)
                                bubble
                            }
                        } else if pointDirection == .bottom {
                            VStack(alignment: arrowAlignment, spacing: 4) {
                                bubble
                                arrowDown.offset(x: arrowOffsetX)
                            }
                        } else if pointDirection == .leading {
                            HStack(spacing: 4) {
                                arrowLeading.offset(y: arrowOffsetX) // Reuse arrowOffsetX for Y offset in horizontal mode
                                bubble
                            }
                        } else {
                            HStack(spacing: 4) {
                                bubble
                                arrowTrailing.offset(y: arrowOffsetX)
                            }
                        }
                    }
                    .fixedSize()
                    .offset(x: bubbleOffsetX, y: isBouncing ? (pointDirection == .top ? bubbleOffsetY - 6 : bubbleOffsetY + 6) : bubbleOffsetY) 
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isBouncing = true
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVisible = false
                        }
                    }
                    .zIndex(100)
                }
            }
    }
    
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Colors.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
    
    private var arrowDown: some View {
        Image(systemName: "hand.point.down.fill")
            .font(.system(size: 38))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 4)
    }
    
    private var arrowUp: some View {
        Image(systemName: "hand.point.up.fill")
            .font(.system(size: 38))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: -4)
    }

    private var arrowLeading: some View {
        Image(systemName: "hand.point.left.fill")
            .font(.system(size: 38))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.4), radius: 6, x: -4, y: 0)
    }
    
    private var arrowTrailing: some View {
        Image(systemName: "hand.point.right.fill")
            .font(.system(size: 38))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.4), radius: 6, x: 4, y: 0)
    }
}

extension View {
    func coachMark(
        title: String,
        subtitle: String? = nil,
        isVisible: Binding<Bool>,
        alignment: Alignment = .top,
        pointDirection: Edge = .bottom,
        arrowAlignment: HorizontalAlignment = .center,
        arrowOffsetX: CGFloat = 0,
        bubbleOffsetX: CGFloat = 0,
        bubbleOffsetY: CGFloat = -80,
        color: Color = Color.red
    ) -> some View {
        self.modifier(CoachMarkModifier(
            title: title,
            subtitle: subtitle,
            isVisible: isVisible,
            alignment: alignment,
            pointDirection: pointDirection,
            arrowAlignment: arrowAlignment,
            arrowOffsetX: arrowOffsetX,
            bubbleOffsetX: bubbleOffsetX,
            bubbleOffsetY: bubbleOffsetY,
            color: color
        ))
    }
}
