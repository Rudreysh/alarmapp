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
                        missionSection(title: "Popular mission") {
                            missionRow(title: "Household Item Hunt", subtitle: "AI", icon: "magnifyingglass", iconBg: Color.red.opacity(0.3), type: .householdItemHunt)
                        }
                        
                        missionSection(title: "Wake your brain") {
                            missionRow(title: "Find Color Tiles", icon: "square.grid.2x2.fill", iconBg: Color.cyan.opacity(0.3), type: .findColorTiles)
                            missionRow(title: "Memory Match", icon: "brain.head.profile", iconBg: Color.cyan.opacity(0.3), type: .memoryMatch)
                            missionRow(title: "Tic Tac Toe", icon: "xmark.square.fill", iconBg: Color.cyan.opacity(0.3), type: .ticTacToe)
                            missionRow(title: "Typing", icon: "keyboard.fill", iconBg: Color.cyan.opacity(0.3), type: .typing)
                            missionRow(title: "Math", icon: "plus.forwardslash.minus", iconBg: Color.cyan.opacity(0.3), type: .math)
                        }
                        
                        missionSection(title: "Wake your body") {
                            missionRow(title: "Step", icon: "figure.walk", iconBg: Color.purple.opacity(0.3), type: .step)
                            missionRow(title: "QR/Barcode", icon: "barcode.viewfinder", iconBg: Color.purple.opacity(0.3), type: .qrBarcode)
                            missionRow(title: "Shake", icon: "iphone.radiowaves.left.and.right", iconBg: Color.purple.opacity(0.3), type: .shake)
                            missionRow(title: "Squat", icon: "figure.strengthtraining.traditional", iconBg: Color.purple.opacity(0.3), type: .squat)
                            missionRow(title: "Push-ups", icon: "figure.strengthtraining.functional", iconBg: Color.purple.opacity(0.3), type: .pushups)
                        }

                        missionSection(title: "Religion") {
                            missionRow(title: "Bible Verse", icon: "book.closed", iconBg: Color.orange.opacity(0.25), type: .bibleVerse)
                            missionRow(title: "Quran Verse", icon: "moon.stars", iconBg: Color.green.opacity(0.25), type: .quranVerse)
                            missionRow(title: "Bhagavad Gita Verse", icon: "book.pages", iconBg: Color.indigo.opacity(0.25), type: .bhagavadGitaVerse)
                            missionRow(title: "Affirmation", icon: "quote.bubble", iconBg: Color.pink.opacity(0.25), type: .affirmation)
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
