import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
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
                    .rotationEffect(piece.rotation)
                    .position(x: piece.x * geo.size.width, y: piece.y * geo.size.height)
                    .offset(y: animate ? geo.size.height + 100 : -60)
                    .animation(.easeOut(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGSize
    let rotation: Angle
    let delay: Double
    let duration: Double
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
            x: CGFloat.random(in: -0.1...1.1),
            y: CGFloat.random(in: -0.1...0.3),
            size: CGSize(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14)),
            rotation: .degrees(Double.random(in: 0...360)),
            delay: Double.random(in: 0.0...0.8),
            duration: Double.random(in: 1.6...2.8),
            type: type
        )
    }
}
