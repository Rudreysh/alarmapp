import SwiftUI

struct FAQView: View {
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Colors.textSecondary)
                        TextField("Search help", text: $searchText)
                            .foregroundColor(Colors.textPrimary)
                    }
                    .padding()
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // FAQ Categories
                    LazyVStack(spacing: 20, pinnedViews: []) {
                        ForEach(FAQCategory.allCases, id: \.self) { category in
                            let items = categoryItems(for: category)
                            if !items.isEmpty {
                                FAQSectionView(category: category, items: items, expanded: searchText.isEmpty)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func categoryItems(for category: FAQCategory) -> [FAQItem] {
        let all = FAQData.items.filter { $0.category == category }
        if searchText.isEmpty {
            return all
        } else {
            return all.filter {
                $0.question.localizedCaseInsensitiveContains(searchText) ||
                $0.answer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct FAQSectionView: View {
    let category: FAQCategory
    let items: [FAQItem]
    let expanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.headline)
                .foregroundColor(Colors.accentTeal)
                .padding(.horizontal, 20)
            
            VStack(spacing: 1) {
                ForEach(items) { item in
                    FAQRow(item: item)
                    if item.id != items.last?.id {
                        Divider()
                            .background(Colors.cardStroke)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Colors.cardSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}

struct FAQRow: View {
    let item: FAQItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .top) {
                    Text(item.question)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 15))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Data Models

enum FAQCategory: String, CaseIterable {
    case troubleshooting = "Troubleshooting"
    case features = "Features"
    case premium = "Premium & Account"
    case sound = "Sounds & Volume"
}

struct FAQItem: Identifiable {
    let id = UUID()
    let category: FAQCategory
    let question: String
    let answer: String
}

struct FAQData {
    static let items: [FAQItem] = [
        // Troubleshooting
        FAQItem(category: .troubleshooting, question: "My alarm didn't ring", answer: "1. Check if 'Do Not Disturb' or 'Silent Mode' is enabled.\n2. Go to Settings > Sound Output and verify volume.\n3. Check 'Alarm Optimization' guide in settings to prevent iOS from killing the app."),
        FAQItem(category: .troubleshooting, question: "Alarm volume is too weak", answer: "Go to Settings > Sound Output. Ensure 'Fade-in' is disabled or set to a short duration. Check if 'Loud Effect' is enabled."),
        FAQItem(category: .troubleshooting, question: "Can I dismiss the alarm without unlocking?", answer: "No. iOS requires the screen to be unlocked for interactive tasks like Missions."),
        FAQItem(category: .troubleshooting, question: "How to prevent app termination?", answer: "Enabled 'Accountability Shield' in settings. This will track if the app is force-closed or the phone is turned off."),

        // Features
        FAQItem(category: .features, question: "What is Accountability Shield?", answer: "It prevents you from cheating. If you turn off your phone, force-close the app, or delete it while an alarm is active, you will be penalized (lose points or pay a fee)."),
        FAQItem(category: .features, question: "How do Missions work?", answer: "Missions (like Math, Memory, Squats) require you to perform an action to dismiss the alarm. You can configure them in the Alarm Editor."),
        FAQItem(category: .features, question: "What happens if I fail a mission?", answer: "The alarm will continue to ring. If you force-close the app to escape, the Penalty Engine will detect it."),

        // Sounds
        FAQItem(category: .sound, question: "How to add custom sounds?", answer: "In the Sound Picker, go to the 'Custom' tab. You can record audio or import files."),
        FAQItem(category: .sound, question: "Can I use Spotify?", answer: "Yes! In the Alarm Editor > Sound > Spotify. You need a Spotify Premium account."),
        
        // Premium
        FAQItem(category: .premium, question: "How to restore purchase?", answer: "Go to Settings > Pro > Restore Purchase."),
        FAQItem(category: .premium, question: "I'd like to refund my subscription", answer: "Refunds are managed by Apple. Go to reportaproblem.apple.com to request a refund.")
    ]
}
