import SwiftUI

struct ConfettiView: View {
    @State private var phase: CGFloat = -0.35
    private let pieces: [ConfettiPiece] = (0..<96).map { _ in ConfettiPiece.random() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Group {
                        switch piece.type {
                        case .rectangle(let color):
                            Rectangle()
                                .fill(color)
                                .frame(width: piece.size.width, height: piece.size.height)
                        case .emoji(let symbol):
                            Text(symbol)
                                .font(.system(size: max(piece.size.width, piece.size.height) * 1.8))
                        }
                    }
                    .rotationEffect(piece.rotation + .degrees(Double(phase) * piece.spinDegrees))
                    .position(
                        x: (piece.startX + piece.driftX * phase) * geo.size.width,
                        y: (piece.startY + piece.fallDistance * phase) * geo.size.height
                    )
                    .opacity(piece.opacity)
                }
            }
            .onAppear {
                phase = -0.35
                withAnimation(.linear(duration: 5.8).repeatForever(autoreverses: false)) {
                    phase = 1.15
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let driftX: CGFloat
    let fallDistance: CGFloat
    let size: CGSize
    let rotation: Angle
    let spinDegrees: Double
    let opacity: Double
    let type: PieceType
    
    enum PieceType {
        case rectangle(Color)
        case emoji(String)
    }

    static func random() -> ConfettiPiece {
        let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]
        let emojis = ["🎉", "🎊"]
        
        // 25% chance of being an emoji, 75% chance of being an original rectangle
        let isEmoji = Double.random(in: 0...100) < 25
        let type: PieceType = isEmoji ? .emoji(emojis.randomElement()!) : .rectangle(colors.randomElement() ?? .white)
        
        return ConfettiPiece(
            startX: CGFloat.random(in: -0.08...1.08),
            startY: CGFloat.random(in: -0.55...0.08),
            driftX: CGFloat.random(in: -0.08...0.08),
            fallDistance: CGFloat.random(in: 1.55...2.3),
            size: CGSize(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14)),
            rotation: .degrees(Double.random(in: 0...360)),
            spinDegrees: Double.random(in: 90...420),
            opacity: Double.random(in: 0.78...1.0),
            type: type
        )
    }
}
