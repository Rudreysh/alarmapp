import SwiftUI

struct FrequentlyUsedPomoSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgSecondary.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                Text("Your Frequently-Used Pomodoro")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, Spacing.l)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.savedPresets) { preset in
                        durationTile(for: preset)
                    }
                    
                    addButton
                }
                .padding(.horizontal, Spacing.l)
                
                Spacer()
                
                Text("Long press the duration to change")
                    .font(.system(size: 14))
                    .foregroundColor(Colors.textTertiary)
                    .padding(.bottom, Spacing.l)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func durationTile(for preset: TimerPreset) -> some View {
        let isSelected = viewModel.pomoDurationSeconds == preset.duration && viewModel.selectedFocusMode == preset.name
        
        return Button(action: {
            viewModel.applyPreset(preset)
            dismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .bold))
                    
                    if preset.mode == .pomo {
                        Text("\(Int(preset.duration / 60)) min")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    } else {
                        Text("Stopwatch")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Colors.cardSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Colors.accentRed : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var addButton: some View {
        Button(action: {
            viewModel.showFrequentlyUsedPomo = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewModel.showAddTimer = true
            }
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Preset")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Colors.cardSurface)
            .cornerRadius(12)
        }
    }
}
