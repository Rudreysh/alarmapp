import SwiftUI

/// Search and add cities to the Overlap view.
struct CitySearchSheet: View {
    @ObservedObject var store: OverlapStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredCities: [WorldCityDatabase.CityEntry] {
        if searchText.isEmpty {
            return WorldCityDatabase.suggestedCities
        }
        return WorldCityDatabase.search(searchText)
    }

    /// Already-added city identifiers so we can mark them
    private var addedIdentifiers: Set<String> {
        Set(store.cities.map(\.timeZoneIdentifier))
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Colors.textSecondary)
                        TextField("Search city...", text: $searchText)
                            .foregroundColor(Colors.textPrimary)
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Colors.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // Results
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if searchText.isEmpty {
                                Text("Suggested Popular Cities")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Colors.textTertiary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                    .padding(.bottom, 8)
                            }
                            ForEach(filteredCities) { entry in
                                let isAdded = addedIdentifiers.contains(entry.timeZoneIdentifier)

                                Button {
                                    if !isAdded {
                                        addCity(entry)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.cityName)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(isAdded ? Colors.accentTeal : Colors.textPrimary)

                                        HStack(spacing: 8) {
                                            Text(entry.timeZoneIdentifier)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(Colors.textSecondary)

                                            if let tz = TimeZone(identifier: entry.timeZoneIdentifier) {
                                                Text(tz.abbreviation() ?? "")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Colors.textTertiary)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                    .background(Color.clear)
                                }
                                .disabled(isAdded)

                                if entry.id != filteredCities.last?.id {
                                    Divider()
                                        .background(Colors.cardStroke)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { isSearchFocused = true }
        }
        .presentationDragIndicator(.visible)
    }

    private func addCity(_ entry: WorldCityDatabase.CityEntry) {
        let city = OverlapCity(
            cityName: entry.cityName,
            timeZoneIdentifier: entry.timeZoneIdentifier
        )
        store.addCity(city)

        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        dismiss()
    }
}
