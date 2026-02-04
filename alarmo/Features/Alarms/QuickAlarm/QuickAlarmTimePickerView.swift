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
                    
                    // Time Pickers
                    HStack(spacing: 20) {
                        // Minutes Picker
                        VStack(spacing: 8) {
                            Text("Minutes")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .textCase(.uppercase)
                            
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0...59, id: \.self) { value in
                                    Text("\(value)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 180)
                            .clipped()
                        }
                        
                        // Seconds Picker
                        VStack(spacing: 8) {
                            Text("Seconds")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .textCase(.uppercase)
                            
                            Picker("Seconds", selection: $seconds) {
                                ForEach(0...59, id: \.self) { value in
                                    Text("\(value)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 180)
                            .clipped()
                        }
                    }
                    
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
