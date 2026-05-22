import SwiftUI

struct StepsMissionSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var steps: Int = 20
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
                missionTitle: "Step",
                missionIcon: "figure.walk"
            ) {
                showAlarmPreview = false
                showGamePreview = true
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
            StepsMissionView(
                viewModel: StepsMissionViewModel(
                    targetSteps: steps,
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
                    .foregroundColor(.white)
            }
            Spacer()
            Text("Step")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
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
                .fill(Color.white.opacity(0.1))
                .aspectRatio(16/9, contentMode: .fit)
            
            VStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                Text("Walk to dismiss")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var pickerSection: some View {
        VStack {
            Picker("Steps", selection: $steps) {
                ForEach([10, 15, 20, 25, 30, 40, 50, 100], id: \.self) { i in
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(i)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        if i == steps {
                            Text("Steps")
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
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(32)
                }
                
                Button(action: {
                    onSave(steps)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.78, blue: 0.92),
                                    Color(red: 0.05, green: 0.66, blue: 0.84)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3), radius: 15, x: 0, y: 10)
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
