import SwiftUI

struct SwipeableSoundRow<Content: View>: View {
    var onRename: (() -> Void)? = nil
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    // Width for two buttons (64 + 64 + 8 = 136). One button = 64.
    private var maxOffset: CGFloat {
        onRename != nil ? -150 : -72
    }
    private let revealThreshold: CGFloat = -40

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background Action Buttons
            HStack(spacing: 8) {
                Spacer()
                
                if let onRenameAction = onRename {
                    Button(action: {
                        withAnimation { offset = 0 }
                        onRenameAction()
                    }) {
                        ZStack {
                            Colors.accentTeal
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                Button(action: {
                    withAnimation { offset = 0 }
                    onDelete()
                }) {
                    ZStack {
                        Colors.accentRed
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.trailing, 20) // Match list padding

            // Foreground Content
            content()
                .background(Colors.bgPrimary) // Ensure content has background to cover buttons
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            // Only allow left dragging
                            if value.translation.width < 0 {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let total = offset + value.translation.width
                            if total < revealThreshold {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        withAnimation {
                            offset = 0
                        }
                    } else {
                        // Forward tap to content?
                        // Tap gesture on container might consume taps for subviews. 
                        // But SoundRow handles taps via .onTapGesture internally. 
                        // This might get tricky. 
                        // Let's rely on content's hit testing if offset is 0.
                    }
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)
    }
}
