import SwiftUI

struct AddFocusRecordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var task: String = "Design"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var type: Int = 0 // 0: Pomo, 1: Stopwatch
    @State private var pomoNumber: Int = 1
    @State private var note: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Info Card
                        VStack(spacing: 0) {
                            navigationRow(title: "Task", value: task)
                            Divider().background(Colors.cardStroke)
                            navigationRow(title: "Start from", value: "Today 21:14")
                            Divider().background(Colors.cardStroke)
                            navigationRow(title: "End at", value: "Today 21:39")
                        }
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        
                        // Type Segment
                        Picker("", selection: $type) {
                            Text("Pomodoro Timer").tag(0)
                            Text("Stopwatch").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .background(Colors.cardSurface)
                        .cornerRadius(8)
                        
                        if type == 0 {
                            // Pomo Number
                            HStack {
                                Text("Pomodoro Count")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Spacer()
                                HStack(spacing: 16) {
                                    Button(action: { if pomoNumber > 1 { pomoNumber -= 1 } }) {
                                        Image(systemName: "minus")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                    Text("\(pomoNumber)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Colors.textPrimary)
                                    Button(action: { pomoNumber += 1 }) {
                                        Image(systemName: "plus")
                                            .foregroundColor(Colors.textPrimary)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                        }
                        
                        // Note Area
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus Note")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                            
                            TextEditor(text: $note)
                                .frame(height: 150)
                                .padding(12)
                                .background(Colors.cardSurface)
                                .cornerRadius(12)
                                .foregroundColor(Colors.textPrimary)
                                .overlay(
                                    Group {
                                        if note.isEmpty {
                                            Text("What do you have in mind?")
                                                .foregroundColor(Colors.textTertiary)
                                                .padding(.top, 20)
                                                .padding(.leading, 16)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(Spacing.l)
                }
            }
            .navigationTitle("Add Focus Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss() }
                        .foregroundColor(Colors.accentRed)
                }
            }
        }
    }
    
    private func navigationRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(Colors.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textTertiary)
        }
        .padding(16)
    }
}
