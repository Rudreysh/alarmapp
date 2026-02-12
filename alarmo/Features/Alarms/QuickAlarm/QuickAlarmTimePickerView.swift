import SwiftUI

struct QuickAlarmTimePickerView: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    SunRayTimePickerView(hour: $minutes, minute: $seconds, topUnit: "min", bottomUnit: "sec", topMax: 59)
                        .padding(.vertical, 40)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Set Duration")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}
