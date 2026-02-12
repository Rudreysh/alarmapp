import SwiftUI

struct AnytimePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    
    // We can use a Date binding or simple Ints if we just want a time.
    // The screenshot shows a wheel with Hour | Minute | AM/PM
    @State private var selectedDate = Date()
    
    var body: some View {
        ZStack {
            TimerGlassBackground()
            
            VStack(spacing: Spacing.xl) {
                // Drag Indicator area handled by sheet presentation
                
                Spacer()
                
                // The Time Wheel
                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // Force text color if needed, but wheel usually adapts to scheme
                    .colorScheme(.dark) 
                
                Spacer()
                
                // Done Button
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
