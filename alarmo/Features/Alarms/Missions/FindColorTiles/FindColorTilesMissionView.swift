import SwiftUI

struct FindColorTilesMissionView: View {
    @StateObject var viewModel: FindColorTilesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(viewModel.roundIndex)/\(viewModel.totalRounds)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { viewModel.soundEnabled.toggle() }) {
                        Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Target Indicator
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.targetColor)
                            .frame(width: 32, height: 32)
                        
                        Text("\(viewModel.remainingTargets) left")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Find the color tiles")
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.bottom, 40)
                
                // Grid
                GeometryReader { geo in
                    let size = min(geo.size.width - 40, geo.size.height - 40)
                    let gridSize = viewModel.difficulty.gridSize
                    let spacing: CGFloat = 8
                    let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: gridSize)
                    
                    VStack {
                        Spacer()
                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(0..<viewModel.tiles.count, id: \.self) { index in
                                if index < viewModel.tiles.count {
                                    // Calculate dynamic tile height based heavily on width to keep square aspect ratio
                                    // LazyVGrid doesn't enforce aspect ratio automatically easily without GeometryReader on item
                                    // But since we want square, we can use AspectRatio
                                    
                                    ActualMissionTileView(
                                        tile: viewModel.tiles[index],
                                        targetColor: viewModel.targetColor,
                                        isShowingPattern: viewModel.isShowingPattern,
                                        size: (size - CGFloat(gridSize - 1) * spacing) / CGFloat(gridSize) // Pass estimated size for icon scaling
                                    ) {
                                        viewModel.handleTap(on: index)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                        .frame(maxWidth: size)
                        Spacer()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .padding(.horizontal, 20)
                
                Spacer()

                if viewModel.isPreviewMode {
                    Text("PREVIEW MODE")
                        .captionText()
                        .fontWeight(.black)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
            }
            .blur(radius: viewModel.showSuccessOverlay ? 10 : 0)
            
            // Success Overlay
            if viewModel.showSuccessOverlay {
                MissionSuccessOverlay(roundIndex: viewModel.roundIndex)
                    .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
    }
}

struct ActualMissionTileView: View {
    let tile: Tile
    let targetColor: Color
    let isShowingPattern: Bool
    let size: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill((isShowingPattern && tile.isTarget) || tile.state == .found ? targetColor : Color(white: 0.25))
                .opacity(tile.state == .found ? 0.7 : 1.0)
            
            if tile.state == .wrongMarked {
                ZStack {
                    Circle()
                        .fill(Color.red)
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.4, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(size * 0.1)
                .transition(.scale.combined(with: .opacity))
            }
        }
        // Removed fixed frame, let it fill grid item
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tile.state)
    }
}

struct MissionSuccessOverlay: View {
    let roundIndex: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Round \(roundIndex)")
                    .heroTitle()
                    .foregroundColor(.white)
                
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}
