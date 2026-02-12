import SwiftUI

struct PomoDurationPickerSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var minutes: Int = 25
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("Pomodoro Duration")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.bottom, 60)
                
                ZStack {
                    // Selection highlight
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Colors.cardSurface)
                        .frame(width: 120, height: 44)
                        .offset(x: -25)
                    
                    HStack(spacing: 12) {
                        Picker("", selection: $minutes) {
                            ForEach(1...180, id: \.self) { i in
                                Text("\(i)")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(i)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 200)
                        
                        Text("mins")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.bgSecondary)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        let seconds = TimeInterval(minutes * 60)
                        viewModel.setPomoDuration(seconds)
                        dismiss()
                    }) {
                        Text("Start") // Changed to Start or Set
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TimerPalette.accent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            minutes = Int(viewModel.pomoDurationSeconds / 60)
        }
    }
}
