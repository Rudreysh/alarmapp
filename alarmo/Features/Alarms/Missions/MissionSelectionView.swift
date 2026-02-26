import SwiftUI

struct MissionSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showUpsell = false
    let onSelect: (AlarmMission) -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Mission")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        // Reward section (top bit in IMG_0)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.red.opacity(0.2)).frame(width: 40, height: 40)
                                Image(systemName: "hand.tap.fill").foregroundColor(.red)
                            }
                            VStack(alignment: .leading) {
                                Text("Tap for Lucky ticket").font(.system(size: 16, weight: .bold))
                                Text("REWARD").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 20)

                        missionSection(title: "Popular mission") {
                            missionRow(title: "Household Item Hunt", subtitle: "AI", icon: "magnifyingglass", iconBg: Color.red.opacity(0.3), type: .off)
                            missionRow(title: "Tap for Lucky ticket", subtitle: "REWARD", icon: "hand.tap.fill", iconBg: Color.red.opacity(0.3), type: .off)
                        }
                        
                        missionSection(title: "Wake your brain") {
                            missionRow(title: "Find Color Tiles", icon: "square.grid.2x2.fill", iconBg: Color.cyan.opacity(0.3), type: .findColorTiles)
                            missionRow(title: "Memory Match", icon: "brain.head.profile", iconBg: Color.cyan.opacity(0.3), type: .memoryMatch)
                            missionRow(title: "Tic Tac Toe", icon: "xmark.square.fill", iconBg: Color.cyan.opacity(0.3), type: .ticTacToe)
                            missionRow(title: "Typing", icon: "keyboard.fill", iconBg: Color.cyan.opacity(0.3), type: .typing)
                            missionRow(title: "Math", icon: "plus.forwardslash.minus", iconBg: Color.cyan.opacity(0.3), type: .math)
                            missionRow(title: "Missing Symbol", subtitle: "Coming Soon", icon: "square.grid.3x3.fill", iconBg: Color.cyan.opacity(0.3), type: .off)
                        }
                        
                        missionSection(title: "Wake your body") {
                            missionRow(title: "Step", icon: "figure.walk", iconBg: Color.purple.opacity(0.3), type: .step)
                            missionRow(title: "QR/Barcode", icon: "barcode.viewfinder", iconBg: Color.purple.opacity(0.3), type: .qrBarcode)
                            missionRow(title: "Shake", icon: "iphone.radiowaves.left.and.right", iconBg: Color.purple.opacity(0.3), type: .shake)
                            missionRow(title: "Photo", icon: "camera.fill", iconBg: Color.purple.opacity(0.3), type: .off)
                            missionRow(title: "Squat", subtitle: "Coming Soon", icon: "figure.strengthtraining.traditional", iconBg: Color.purple.opacity(0.3), type: .off)
                        }
                    }
                    .padding(.bottom, 100) // Increased padding to ensure bottom items are easily accessible
                }
                .scrollIndicators(.visible) // Force scroll indicators to be visible
            }
        }
        .fullScreenCover(isPresented: $showUpsell) {
            ProUpsellFlowView()
        }
    }
    
    private func missionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 20) {
                content()
            }
        }
    }
    
    private func missionRow(title: String, subtitle: String? = nil, icon: String, iconBg: Color, type: WakeUpMissionType) -> some View {
        Button(action: {
            if type != .off {
                if type.isProFeature && !subManager.isPro {
                    showUpsell = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    onSelect(AlarmMission(type: type))
                }
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(title == "Household Item Hunt" ? .white : iconBg.opacity(1)) // Adjustment for contrast
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subtitle == "AI" ? Color.orange.opacity(0.3) : (subtitle == "Coming Soon" ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)))
                        .foregroundColor(subtitle == "AI" ? .orange : (subtitle == "Coming Soon" ? .blue : .orange))
                        .cornerRadius(4)
                } else if type.isProFeature {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Colors.accentTeal.opacity(0.3))
                        .foregroundColor(Colors.accentTeal)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}
