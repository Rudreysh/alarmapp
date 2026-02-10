import SwiftUI

struct TimerDurationPickerView: View {
    let initialMinutes: Int
    let segmentTitle: String
    let onSave: (Int) -> Void
    
    @State private var selectedMinutes: Int
    @Environment(\.dismiss) var dismiss
    
    init(initialMinutes: Int, segmentTitle: String, onSave: @escaping (Int) -> Void) {
        self.initialMinutes = initialMinutes
        self.segmentTitle = segmentTitle
        self.onSave = onSave
        self._selectedMinutes = State(initialValue: initialMinutes)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: Spacing.xl) {
                    Text("\(selectedMinutes) min")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                    
                    Picker(segmentTitle, selection: $selectedMinutes) {
                        ForEach(1...120, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    
                    Spacer()
                    
                    PrimaryButton(title: "Done") {
                        onSave(selectedMinutes)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle(segmentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        dismiss()
                    }
                    .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        onSave(selectedMinutes)
                    }
                    .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}
