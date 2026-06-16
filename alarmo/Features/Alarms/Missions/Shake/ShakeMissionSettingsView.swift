import SwiftUI

struct ShakeMissionSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var shakeCount: Int = 30
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    
    let onSave: (Int) -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 32) {
                        previewCard
                        pickerSection
                        Spacer().frame(height: 120)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
            }
            
            footerButtons
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "Shake",
                missionIcon: "iphone.radiowaves.left.and.right"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            ShakeMissionView(
                viewModel: ShakeMissionViewModel(
                    targetShakes: shakeCount,
                    onComplete: {
                        showGamePreview = false
                    }
                )
            )
        }
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Text("Shake")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Colors.bgPrimary)
    }
    
    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(MissionTheme.softFill)
                .aspectRatio(16/9, contentMode: .fit)
            
            VStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(Colors.textPrimary)
                Text("Shake to dismiss")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(MissionTheme.softStroke, lineWidth: 1)
        )
    }
    
    private var pickerSection: some View {
        VStack {
            Picker("Shakes", selection: $shakeCount) {
                ForEach([10, 15, 20, 25, 30, 40, 50, 75, 100], id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        if i == shakeCount {
                            Text("Shakes")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
        }
        .background(Colors.cardSurface)
        .cornerRadius(24)
    }
    
    private var footerButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button(action: { showAlarmPreview = true }) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MissionTheme.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.secondaryButtonFill)
                        .cornerRadius(32)
                }
                
                Button(action: {
                    onSave(shakeCount)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.primaryButtonGradient)
                        .cornerRadius(32)
                        .shadow(color: MissionTheme.primaryButtonShadow, radius: 15, x: 0, y: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(y: -40)
                .allowsHitTesting(false)
            )
        }
    }
}
