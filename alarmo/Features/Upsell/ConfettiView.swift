import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    private let pieces: [ConfettiPiece] = (0..<24).map { _ in ConfettiPiece.random() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .rotationEffect(piece.rotation)
                        .position(x: piece.x * geo.size.width, y: piece.y * geo.size.height)
                        .offset(y: animate ? geo.size.height + 80 : -60)
                        .animation(.easeOut(duration: 1.6).delay(piece.delay), value: animate)
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
    let color: Color
    let delay: Double

    static func random() -> ConfettiPiece {
        let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]
        return ConfettiPiece(
            x: CGFloat.random(in: 0.1...0.9),
            y: CGFloat.random(in: 0.0...0.3),
            size: CGSize(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14)),
            rotation: .degrees(Double.random(in: 0...360)),
            color: colors.randomElement() ?? .white,
            delay: Double.random(in: 0.0...0.4)
        )
    }
}
