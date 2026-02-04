import SwiftUI

struct TimeZonePickerView: View {
    @Binding var selectedIdentifier: String?
    @Binding var selectedCity: String?
    @Binding var selectedMode: AlarmTimeZoneMode
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var allItems: [CityTimeItem] = []
    
    // Haptic Generator
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var filteredItems: [CityTimeItem] {
        if searchText.isEmpty {
            return allItems
        } else {
            return allItems.filter { $0.searchKey.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stylish Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                        
                        TextField("Search city...", text: $searchText)
                            .foregroundColor(Colors.textPrimary)
                            .font(.system(size: 16, weight: .medium))
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation { searchText = "" }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Colors.cardSurface.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if searchText.isEmpty {
                                // Current Location Section
                                CityPickerRow(
                                    title: "Current Location",
                                    subtitle: "Local Time",
                                    isSelected: selectedMode == .local,
                                    isCurrentLocation: true
                                ) {
                                    triggerSelection {
                                        selectedMode = .local
                                        selectedIdentifier = nil
                                        selectedCity = nil
                                    }
                                }
                                .padding(.top, 4)
                            }

                            ForEach(filteredItems) { item in
                                let isSelected = (selectedMode == .custom && selectedIdentifier == item.identifier && (selectedCity == nil || selectedCity == item.city))
                                
                                CityPickerRow(
                                    title: item.city,
                                    subtitle: item.detail,
                                    isSelected: isSelected
                                ) {
                                    triggerSelection {
                                        selectedMode = .custom
                                        selectedIdentifier = item.identifier
                                        selectedCity = item.city
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Choose a City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Colors.cardSurface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .onAppear {
            loadItems()
            feedback.prepare()
        }
    }
    
    private func triggerSelection(action: () -> Void) {
        feedback.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            action()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }
    
    private func loadItems() {
        var items: [CityTimeItem] = []
        for city in WorldClockData.allCities {
            guard let tz = TimeZone(identifier: city.timeZoneId) else { continue }
            let gmtOffset = tz.secondsFromGMT()
            let hours = gmtOffset / 3600
            let minutes = abs(gmtOffset / 60) % 60
            let sign = hours >= 0 ? "+" : "-"
            let offsetString = String(format: "GMT%@%d:%02d", sign, abs(hours), minutes)
            let detail = "\(city.country), \(offsetString)"
            items.append(CityTimeItem(identifier: city.timeZoneId, city: city.city, region: city.country, detail: detail, searchKey: city.searchKey))
        }
        items.sort { $0.city < $1.city }
        self.allItems = items
    }
}

// MARK: - Stylish Row Component
private struct CityPickerRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var isCurrentLocation: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isCurrentLocation ? Colors.accentTeal : Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Colors.accentTeal.opacity(0.12) : Colors.cardSurface.opacity(0.5))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Colors.accentTeal.opacity(0.4), lineWidth: 1.5)
                    }
                }
            )
        }
        .buttonStyle(RowSelectionButtonStyle())
    }
}

// MARK: - Haptic & Visual Button Style
struct RowSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CityTimeItem: Identifiable {
    let id = UUID()
    let identifier: String
    let city: String
    let region: String
    let detail: String
    let searchKey: String
}

