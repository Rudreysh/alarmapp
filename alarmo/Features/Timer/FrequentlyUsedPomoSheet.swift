import SwiftUI

struct FrequentlyUsedPomoSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgSecondary.ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                Text("Your Frequently-Used Pomo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, Spacing.l)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.frequentDurations, id: \.self) { duration in
                        durationTile(for: duration)
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
    
    private func durationTile(for duration: TimeInterval) -> some View {
        let minutes = Int(duration / 60)
        let isSelected = viewModel.pomoDurationSeconds == duration
        let index = viewModel.frequentDurations.firstIndex(of: duration)
        
        return Button(action: {
            viewModel.setPomoDuration(duration)
            dismiss()
        }) {
            Text("\(minutes):00")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Colors.accentRed : Color.clear, lineWidth: 2)
                )
        }
        .onLongPressGesture {
            viewModel.isAddingNewDuration = false
            viewModel.editingDurationIndex = index
            viewModel.showFrequentlyUsedPomo = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewModel.showPomoDurationPicker = true
            }
        }
    }
    
    private var addButton: some View {
        Button(action: {
            viewModel.isAddingNewDuration = true
            viewModel.editingDurationIndex = nil
            viewModel.showFrequentlyUsedPomo = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewModel.showPomoDurationPicker = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Colors.cardSurface)
                .cornerRadius(12)
        }
    }
}
