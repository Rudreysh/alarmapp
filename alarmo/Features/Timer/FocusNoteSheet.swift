import SwiftUI

struct FocusNoteSheet: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: Spacing.xl) {
                Text("Focus Note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, Spacing.l)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.focusNote)
                        .frame(height: 140)
                        .padding(Spacing.s)
                        .timerGlassCard(cornerRadius: 12)
                        .foregroundColor(Colors.textPrimary)
                        .focused($isNoteFocused)
                    
                    if viewModel.focusNote.isEmpty {
                        Text("What do you have in mind?")
                            .font(.system(size: 16))
                            .foregroundColor(Colors.textTertiary)
                            .padding(.top, 20)
                            .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, Spacing.l)
                
                HStack(spacing: Spacing.m) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .timerGlassCard(cornerRadius: Radii.button)
                    .foregroundColor(Colors.textPrimary)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .timerNeonFill(cornerRadius: Radii.button)
                    .foregroundColor(Colors.textPrimary)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.l)
            }
        }
        .onAppear {
            isNoteFocused = true
        }
    }
}
