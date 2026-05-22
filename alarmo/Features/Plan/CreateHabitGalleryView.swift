import SwiftUI
import SwiftData

struct CreateHabitGalleryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var selectedCategory: HabitCategory = .suggested
    @State private var selectedTemplateItem: PlanItem?
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool
    
    private var filteredHabits: [HabitTemplate] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return HabitTemplate.allHabits.filter { habit in
            habit.title.lowercased().contains(query) ||
            habit.subtitle.lowercased().contains(query) ||
            habit.category.rawValue.lowercased().contains(query) ||
            habit.goalUnit.lowercased().contains(query)
        }
    }
    
    private var groupedSearchResults: [(category: HabitCategory, habits: [HabitTemplate])] {
        var groups: [(HabitCategory, [HabitTemplate])] = []
        for category in HabitCategory.allCases {
            let habits = filteredHabits.filter { $0.category == category }
            if !habits.isEmpty {
                groups.append((category, habits))
            }
        }
        return groups
    }

    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(searchQuery.isEmpty ? PlanPalette.textSecondary : PlanPalette.accent)
                            .font(.system(size: 15))
                        
                        TextField("Search habits...", text: $searchQuery)
                            .font(.system(size: 15))
                            .foregroundColor(PlanPalette.textPrimary)
                            .focused($isSearchFocused)
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(PlanPalette.textSecondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.2))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSearchFocused ? PlanPalette.accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Search Results
                        searchResultsView
                    } else {
                        // Category Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(HabitCategory.allCases, id: \.self) { category in
                                    CategoryTabButton(
                                        title: category.rawValue,
                                        isSelected: selectedCategory == category,
                                        action: { withAnimation { selectedCategory = category } }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.15))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        
                        // Habits List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                let habits = habitsForCategory(selectedCategory)
                                ForEach(habits) { habit in
                                    HabitCard(habit: habit) {
                                        createHabit(from: habit)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 80)
                        }
                    }
                }
                
                // Bottom Button
                VStack {
                    Spacer()
                    PrimaryButton(title: "Create a new habit", style: .blueGlass) {
                        createCustomHabit()
                    }
                    .padding()
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(PlanPalette.accent)
                        .fontWeight(.bold)
                }
            }
            }
            .sheet(item: $selectedTemplateItem) { item in
                 CreatePlanItemView(templateItem: item, onSave: { newItem in
                     _ = newItem
                     dismiss()
                 })
            }
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredHabits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(PlanPalette.textSecondary.opacity(0.5))
                        Text("No habits found")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(PlanPalette.textSecondary)
                        Text("Try a different search term")
                            .font(.system(size: 14))
                            .foregroundColor(PlanPalette.textSecondary.opacity(0.7))
                    }
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(groupedSearchResults, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.category.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PlanPalette.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            ForEach(group.habits) { habit in
                                HabitCard(habit: habit) {
                                    createHabit(from: habit)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 80)
        }
    }
    
    private func habitsForCategory(_ category: HabitCategory) -> [HabitTemplate] {
        return HabitTemplate.allHabits.filter { $0.category == category }
    }
    
    private func createHabit(from template: HabitTemplate) {
        // Logic to create a PlanItem from the template
        let newItem = PlanItem(
            title: template.title,
            subtitle: template.subtitle,
            iconName: template.icon,
            tintKey: template.colorKey,
            type: .habit,

            anytime: false
        )
        newItem.scheduledDate = Date()
        
        // Default Duration if set
        if let duration = template.defaultDurationSeconds {
            newItem.defaultDurationSeconds = duration
        }
        
        // Set repeat rule for habit (e.g. daily default)
        var rule = RepeatRule()
        rule.frequency = .daily
        newItem.repeatRule = rule
        
        // Don't insert yet. Present for editing.
        // Don't insert yet. Present for editing.
        
        // Map new fields
        newItem.habitIntent = template.habitIntent
        newItem.metricKind = template.metricKind
        let preferredDistanceUnit = SettingsStore.shared.preferredHabitDistanceUnit
        let (resolvedGoalValue, resolvedGoalUnit) = resolvedDistanceGoal(
            value: template.goalValue,
            unit: template.goalUnit,
            preferredUnit: preferredDistanceUnit
        )
        newItem.goalValue = resolvedGoalValue
        newItem.goalUnit = resolvedGoalUnit
        newItem.autoHealthTracking = inferredHealthTracking(for: template)
        
        selectedTemplateItem = newItem
    }

    private func resolvedDistanceGoal(value: Double, unit: String, preferredUnit: String) -> (Double, String) {
        let lowerUnit = unit.lowercased()
        let isKm = lowerUnit == "km" || lowerUnit.contains("kilometer") || lowerUnit.contains("kilometre")
        let isMi = lowerUnit == "mi" || lowerUnit.contains("mile")

        guard isKm || isMi else { return (value, unit) }

        if isKm && preferredUnit == "mi" {
            return ((value * 0.621371).rounded(toPlaces: 1), "mi")
        }
        if isMi && preferredUnit == "km" {
            return ((value / 0.621371).rounded(toPlaces: 1), "km")
        }
        return (value, preferredUnit)
    }
    
    private func createCustomHabit() {
        // Just create a generic empty habit for now and let user edit, or maybe open a creation sheet?
        // User asked to mimic the screen, button says "Create a new habit".
        // We'll treat it as creating a blank habit plan item for editing.
        let newItem = PlanItem(
            title: "New Habit",
            iconName: "flame.fill",
            type: .habit,
            anytime: false
        )
        newItem.scheduledDate = Date()
        
        // Set default daily repeat for custom habit too
        var rule = RepeatRule()
        rule.frequency = .daily
        newItem.repeatRule = rule
        
        // Don't insert yet. Present for editing.
        selectedTemplateItem = newItem
    }

    private func inferredHealthTracking(for template: HabitTemplate) -> String? {
        let title = template.title.lowercased()
        let unit = template.goalUnit.lowercased()

        if unit.contains("step") { return "steps" }

        let distanceUnits = ["km", "mi", "m", "meter", "metre", "mile", "kilometer", "kilometre"]
        let isDistance = distanceUnits.contains { unit.hasPrefix($0) || unit == "\($0)s" }
        if isDistance {
            if title.contains("cycle") || title.contains("bike") || title.contains("ride") || title.contains("spin") {
                return "cycling"
            }
            if title.contains("run") || title.contains("jog") || title.contains("sprint") {
                return "running"
            }
            return "distance"
        }

        if (unit.contains("hour") || unit == "h" || unit == "hr" || unit.contains("min")),
           (title.contains("sleep") || title.contains("nap")) {
            return "sleep"
        }

        let hydrationUnits = ["ml", "l", "liter", "litre", "oz", "cup", "glass"]
        let isHydrationUnit = hydrationUnits.contains { unit == $0 || unit == "\($0)s" || unit.hasPrefix($0) }
        if isHydrationUnit && (title.contains("water") || title.contains("drink") || title.contains("hydrat")) {
            return "water"
        }

        if (unit.contains("hour") || unit == "h" || unit == "hr" || unit.contains("min")),
           (title.contains("stand") || title.contains("standing")) {
            return "standing"
        }

        if (unit.contains("min") || unit == "m"), (title.contains("meditat") || title.contains("mindful") || title.contains("breath")) {
            return "mindfulness"
        }

        return nil
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - Subviews

struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? Color.white.opacity(0.96) : PlanPalette.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.71, blue: 0.93).opacity(0.25),
                                        Color(red: 0.12, green: 0.56, blue: 0.86).opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(Color.clear)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct HabitCard: View {
    let habit: HabitTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.08, blue: 0.12).opacity(0.92),
                                Color(red: 0.06, green: 0.11, blue: 0.17).opacity(0.86),
                                Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    habit.color.opacity(0.38),
                                    habit.color.opacity(0.18),
                                    Color.black.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 86)
                        .padding(.leading, 6)
                        .padding(.vertical, 6)
                    
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(habit.color.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: habit.icon)
                            .font(.system(size: 24))
                            .foregroundColor(habit.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(PlanPalette.textPrimary)
                        Text(habit.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(PlanPalette.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(habit.color)
                        .frame(width: 28, height: 28)
                        .background(habit.color.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

enum HabitCategory: String, CaseIterable {
    case suggested = "Suggested"
    case life = "Lifestyle"
    case health = "Health"
    case sport = "Sports"
    case time = "Time"
    case quit = "Quit"
}

struct HabitTemplate: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let colorKey: String // String key for persistence model
    let category: HabitCategory
    let defaultDurationSeconds: Int? // Optional default focus duration
    
    let metricKind: MetricKind
    let goalValue: Double
    let goalUnit: String
    let habitIntent: HabitIntent
    
    init(title: String, subtitle: String, icon: String, color: Color, colorKey: String, category: HabitCategory, defaultDurationSeconds: Int? = nil, metricKind: MetricKind = .count, goalValue: Double = 1, goalUnit: String = "times", habitIntent: HabitIntent = .build) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.colorKey = colorKey
        self.category = category
        self.defaultDurationSeconds = defaultDurationSeconds
        self.metricKind = metricKind
        self.goalValue = goalValue
        self.goalUnit = goalUnit
        self.habitIntent = habitIntent
    }
    
    static let allHabits: [HabitTemplate] = [
        // Suggested / Popular
        HabitTemplate(title: "Walk", subtitle: "Keep moving forward", icon: "figure.walk", color: .blue, colorKey: "blue", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 10000, goalUnit: "steps"),
        HabitTemplate(title: "Sleep", subtitle: "Rest well", icon: "bed.double.fill", color: .purple, colorKey: "purple", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 7, goalUnit: "hr"),
        HabitTemplate(title: "Drink water", subtitle: "Stay hydrated", icon: "drop.fill", color: .cyan, colorKey: "cyan", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3000, goalUnit: "ml"),
        HabitTemplate(title: "Meditation", subtitle: "Quiet your mind", icon: "figure.mind.and.body", color: Color(hex: "7F7FD5"), colorKey: "indigo", category: .suggested, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Run", subtitle: "Run 3km", icon: "figure.run", color: .green, colorKey: "green", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3, goalUnit: "km"),
        HabitTemplate(title: "Stand", subtitle: "Stand up", icon: "figure.stand", color: .orange, colorKey: "orange", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 8, goalUnit: "hr"),
        HabitTemplate(title: "Cycling", subtitle: "Ride with the wind", icon: "bicycle", color: .blue, colorKey: "blue", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3000, goalUnit: "m"),
        HabitTemplate(title: "Workout", subtitle: "Build strength", icon: "dumbbell.fill", color: .blue, colorKey: "blue", category: .suggested, defaultDurationSeconds: 3600, metricKind: .time, goalValue: 60, goalUnit: "min"),
        HabitTemplate(title: "Active Calorie", subtitle: "Burn active calories", icon: "flame.fill", color: .red, colorKey: "red", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 500, goalUnit: "Cal"),
        HabitTemplate(title: "Burn Calorie", subtitle: "Burn it off", icon: "flame", color: .red, colorKey: "red", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 500, goalUnit: "Cal"),
        HabitTemplate(title: "Read a book", subtitle: "A chapter a day", icon: "book.fill", color: .blue, colorKey: "blue", category: .suggested, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Drink Less Alcohol", subtitle: "Limit intake", icon: "wineglass.fill", color: .blue, colorKey: "blue", category: .suggested, defaultDurationSeconds: nil, metricKind: .count, goalValue: 2, goalUnit: "drink", habitIntent: .quit),

        // Lifestyle
        HabitTemplate(title: "Eat Vege", subtitle: "Eat more greens", icon: "leaf.fill", color: .green, colorKey: "green", category: .life, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3, goalUnit: "servings"),
        HabitTemplate(title: "No Sugar", subtitle: "Cut down sweets", icon: "birthday.cake.fill", color: .pink, colorKey: "pink", category: .life, defaultDurationSeconds: nil, metricKind: .count, goalValue: 0, goalUnit: "g", habitIntent: .quit),
        HabitTemplate(title: "Sleep early", subtitle: "Bed by 10pm", icon: "moon.zzz.fill", color: .indigo, colorKey: "purple", category: .life, defaultDurationSeconds: nil, metricKind: .time, goalValue: 8, goalUnit: "hr"),
        HabitTemplate(title: "Laugh out loud", subtitle: "Stay positive", icon: "face.smiling.inverse", color: .yellow, colorKey: "yellow", category: .life),
        HabitTemplate(title: "Eat Low-Fat", subtitle: "Healthy diet", icon: "leaf", color: .green, colorKey: "green", category: .life),
        HabitTemplate(title: "Eat an Apple", subtitle: "An apple a day", icon: "apple.logo", color: .red, colorKey: "red", category: .life, defaultDurationSeconds: nil, metricKind: .count, goalValue: 1, goalUnit: "apple"),
        HabitTemplate(title: "Eat Breakfast", subtitle: "Start day right", icon: "cup.and.saucer.fill", color: .orange, colorKey: "orange", category: .life),
        
        // Health
        HabitTemplate(title: "Burn Calorie", subtitle: "Burn 500 Cal", icon: "flame.fill", color: .red, colorKey: "red", category: .health, defaultDurationSeconds: nil, metricKind: .count, goalValue: 500, goalUnit: "Cal"),
        HabitTemplate(title: "Exercise", subtitle: "Stay fit", icon: "figure.run", color: .green, colorKey: "green", category: .health, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Meditation", subtitle: "Mental health", icon: "figure.mind.and.body", color: .purple, colorKey: "purple", category: .health, defaultDurationSeconds: 600, metricKind: .time, goalValue: 10, goalUnit: "min"),
        HabitTemplate(title: "Drink water", subtitle: "Hydration", icon: "drop.fill", color: .blue, colorKey: "blue", category: .health, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3000, goalUnit: "ml"),
        HabitTemplate(title: "Less Carbohydrate", subtitle: "Low carb diet", icon: "carrot.fill", color: .orange, colorKey: "orange", category: .health, defaultDurationSeconds: nil, metricKind: .count, goalValue: 100, goalUnit: "g", habitIntent: .quit),
        HabitTemplate(title: "Drink Less Caffeine", subtitle: "Limit caffeine", icon: "cup.and.saucer.fill", color: .brown, colorKey: "brown", category: .health, defaultDurationSeconds: nil, metricKind: .count, goalValue: 200, goalUnit: "mg", habitIntent: .quit),
        HabitTemplate(title: "Workout", subtitle: "Strength", icon: "dumbbell.fill", color: .blue, colorKey: "blue", category: .health, defaultDurationSeconds: 3600, metricKind: .time, goalValue: 60, goalUnit: "min"),
        HabitTemplate(title: "Eat Fruits", subtitle: "Vitamin C", icon: "carrot.fill", color: .red, colorKey: "red", category: .health, defaultDurationSeconds: nil, metricKind: .count, goalValue: 3, goalUnit: "servings"),

        // Sports
        HabitTemplate(title: "Yoga", subtitle: "Flexibility", icon: "figure.yoga", color: .purple, colorKey: "purple", category: .sport, defaultDurationSeconds: 1200, metricKind: .time, goalValue: 20, goalUnit: "min"),
        HabitTemplate(title: "Cycling", subtitle: "Cardio", icon: "bicycle", color: .green, colorKey: "green", category: .sport, defaultDurationSeconds: 1800, metricKind: .count, goalValue: 5, goalUnit: "km"),
        HabitTemplate(title: "Swim", subtitle: "Full body workout", icon: "figure.pool.swim", color: .blue, colorKey: "blue", category: .sport, defaultDurationSeconds: 1800, metricKind: .count, goalValue: 500, goalUnit: "m"),
        HabitTemplate(title: "Burn Calorie", subtitle: "Burn 500 Cal", icon: "flame.fill", color: .red, colorKey: "red", category: .sport, defaultDurationSeconds: nil, metricKind: .count, goalValue: 500, goalUnit: "Cal"),
        HabitTemplate(title: "Exercise", subtitle: "General fitness", icon: "figure.run", color: .green, colorKey: "green", category: .sport, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Workout", subtitle: "Gym session", icon: "dumbbell.fill", color: .blue, colorKey: "blue", category: .sport, defaultDurationSeconds: 3600, metricKind: .time, goalValue: 60, goalUnit: "min"),
        HabitTemplate(title: "Anaerobic", subtitle: "High intensity", icon: "figure.strengthtraining.traditional", color: .orange, colorKey: "orange", category: .sport, defaultDurationSeconds: 1200, metricKind: .time, goalValue: 20, goalUnit: "min"),
        
        // Time
        HabitTemplate(title: "Stretch", subtitle: "Morning stretch", icon: "figure.cooldown", color: .purple, colorKey: "purple", category: .time, defaultDurationSeconds: 600, metricKind: .time, goalValue: 10, goalUnit: "min"),
        HabitTemplate(title: "Yoga", subtitle: "Daily yoga", icon: "figure.yoga", color: .purple, colorKey: "purple", category: .time, defaultDurationSeconds: 1200, metricKind: .time, goalValue: 20, goalUnit: "min"),
        HabitTemplate(title: "Swim", subtitle: "Swim laps", icon: "figure.pool.swim", color: .blue, colorKey: "blue", category: .time, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Exercise", subtitle: "Daily workout", icon: "figure.run", color: .green, colorKey: "green", category: .time, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Anaerobic", subtitle: "Strength training", icon: "figure.strengthtraining.traditional", color: .orange, colorKey: "orange", category: .time, defaultDurationSeconds: 1200, metricKind: .time, goalValue: 20, goalUnit: "min"),
        HabitTemplate(title: "Meditation", subtitle: "Mindfulness", icon: "figure.mind.and.body", color: .indigo, colorKey: "indigo", category: .time, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Breathe", subtitle: "Deep breathing", icon: "lungs.fill", color: .cyan, colorKey: "cyan", category: .time, defaultDurationSeconds: 300, metricKind: .time, goalValue: 5, goalUnit: "min"),
        HabitTemplate(title: "Read a book", subtitle: "Reading time", icon: "book.fill", color: .blue, colorKey: "blue", category: .time, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),
        HabitTemplate(title: "Learning", subtitle: "Learn something new", icon: "graduationcap.fill", color: .yellow, colorKey: "yellow", category: .time, defaultDurationSeconds: 1800, metricKind: .time, goalValue: 30, goalUnit: "min"),

        // Quit
        HabitTemplate(title: "Drink Less Alcohol", subtitle: "Limit alcohol", icon: "wineglass.fill", color: .blue, colorKey: "blue", category: .quit, defaultDurationSeconds: nil, metricKind: .count, goalValue: 2, goalUnit: "drink", habitIntent: .quit),
        HabitTemplate(title: "Smoke Less", subtitle: "Reduce smoking", icon: "smoke.fill", color: .gray, colorKey: "gray", category: .quit, defaultDurationSeconds: nil, metricKind: .count, goalValue: 5, goalUnit: "cigs", habitIntent: .quit),
        HabitTemplate(title: "Play Less Game", subtitle: "Limit gaming", icon: "gamecontroller.fill", color: .purple, colorKey: "purple", category: .quit, defaultDurationSeconds: nil, metricKind: .time, goalValue: 60, goalUnit: "min", habitIntent: .quit),
        HabitTemplate(title: "Complain Less", subtitle: "Stay positive", icon: "mouth", color: .orange, colorKey: "orange", category: .quit, defaultDurationSeconds: nil, metricKind: .count, goalValue: 0, goalUnit: "times", habitIntent: .quit),
        HabitTemplate(title: "Sit Less", subtitle: "Move more", icon: "chair.lounge.fill", color: .blue, colorKey: "blue", category: .quit, defaultDurationSeconds: nil, metricKind: .time, goalValue: 240, goalUnit: "min", habitIntent: .quit),
        HabitTemplate(title: "Watch Less TV", subtitle: "Limit screen time", icon: "tv.fill", color: .black, colorKey: "gray", category: .quit, defaultDurationSeconds: nil, metricKind: .time, goalValue: 60, goalUnit: "min", habitIntent: .quit),
        HabitTemplate(title: "Less Social App", subtitle: "Digital detox", icon: "bubble.left.and.bubble.right.fill", color: .green, colorKey: "green", category: .quit, defaultDurationSeconds: nil, metricKind: .time, goalValue: 60, goalUnit: "min", habitIntent: .quit),
        HabitTemplate(title: "Spend Less", subtitle: "Save money", icon: "dollarsign.circle.fill", color: .green, colorKey: "green", category: .quit, defaultDurationSeconds: nil, metricKind: .count, goalValue: 50, goalUnit: "$", habitIntent: .quit),
    ]
}

// MARK: - Blue Gradient Card Style
extension View {
    func habitBlueCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.20, blue: 0.30).opacity(0.85),
                                Color(red: 0.05, green: 0.12, blue: 0.20).opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                TimerPalette.accent.opacity(0.4),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}
