import SwiftUI

struct DurationPickerSheet: View {
    @Binding var focusDuration: Int
    @Binding var isPomodoro: Bool
    @Environment(\.dismiss) var dismiss
    
    // Focus Keeper style values provided
    let availableDurations = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 90, 120]
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                // Header (done inside toolbar mostly, but good to have title if needed)
                
                // Toggle Row
                HStack {
                    Text("Pomodoro (4 sessions with breaks)")
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    Toggle("", isOn: $isPomodoro)
                        .labelsHidden()
                        .tint(Colors.accentRed)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                
                Spacer()
                
                // Picker Area
                HStack(alignment: .center, spacing: 0) {
                    Text("Focus for")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("Duration", selection: $focusDuration) {
                        ForEach(availableDurations, id: \.self) { duration in
                            Text("\(duration)")
                                .font(.system(size: 24, weight: .bold)) // Will be styled by wheel
                                .tag(duration)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 150)
                    .clipped()
                    
                    Text("minutes")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.l)
                
                Spacer()
                
                // Done Button (Big, bottom)
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
    }
}
