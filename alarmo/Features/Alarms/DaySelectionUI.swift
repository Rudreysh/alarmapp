
import SwiftUI

// MARK: - Day Selection Row (Inline)

struct DaySelectionRow: View {
    @Binding var isDaily: Bool
    @Binding var selectedWeekdays: Set<Int>
    
    // Modern "Squircle" shapes
    private let days = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Toggle Row
            Button(action: toggleRepeatMode) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textPrimary)
                        .frame(width: 24)
                    
                    Text("Daily")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    // Custom Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDaily ? Colors.accentTeal : Color(white: 0.2))
                            .frame(width: 22, height: 22)
                        
                        if isDaily {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // 2. Days Bubbles (Visible only if Repeating)
            if isRepeating {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(1...7, id: \.self) { day in
                            DayBubble(
                                label: days[day - 1],
                                isSelected: isDaySelected(day), 
                                action: { toggleDay(day) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 3. Selected Days Text (New)
                    if !isDaily && !selectedWeekdays.isEmpty {
                        Text(selectedDaysSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.bottom, 4)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
    
    // Helper to generate the summary string (e.g. "Selected Days: Mon, Tue")
    private var selectedDaysSummary: String {
        let sortedDays = selectedWeekdays.sorted()
        let dayNames = sortedDays.map { day -> String in
            // Calendar weekday 1 = Sunday. We want short names.
            // Using standard abbreviation
            return Calendar.current.shortWeekdaySymbols[day - 1]
        }
        return "Selected Days: " + dayNames.joined(separator: ", ")
    }
    
    // Logic helpers
    private var isRepeating: Bool {
        return isDaily || !selectedWeekdays.isEmpty
    }
    
    private func toggleRepeatMode() {
        withAnimation {
            if isDaily {
                // If currently Daily (All), switch to Custom (Today only)
                isDaily = false
                let today = Calendar.current.component(.weekday, from: Date())
                selectedWeekdays = [today]
            } else {
                // If currently Custom or Off, switch to Daily (All)
                isDaily = true
                selectedWeekdays = [] // Model implies isDaily overrides this, or we clear it.
            }
        }
    }
    
    private func isDaySelected(_ day: Int) -> Bool {
        if isDaily { return true }
        return selectedWeekdays.contains(day)
    }
    
    private func toggleDay(_ day: Int) {
        if isDaily {
            // Unchecking a day while in Daily mode -> Switch to Custom
            // Select all others, deselect this one.
            let allDays = Set(1...7)
            selectedWeekdays = allDays
            isDaily = false
            selectedWeekdays.remove(day)
        } else {
            if selectedWeekdays.contains(day) {
                selectedWeekdays.remove(day)
            } else {
                selectedWeekdays.insert(day)
            }
        }
        
        // Auto-switch to Daily if all 7 are manually selected
        if selectedWeekdays.count == 7 {
            isDaily = true
            selectedWeekdays.removeAll()
        }
    }
}

struct DayBubble: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Colors.accentTeal : Color(white: 0.2))
                    .frame(width: 38, height: 38)
                
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
