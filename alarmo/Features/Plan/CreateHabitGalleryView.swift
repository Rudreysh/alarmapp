import SwiftUI
import SwiftData

struct CreateHabitGalleryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var selectedCategory: HabitCategory = .suggested
    @State private var selectedTemplateItem: PlanItem? // To trigger edit sheet

    var body: some View {
        NavigationView {
            ZStack {
                PlanGlassBackground()
                
                VStack(spacing: 0) {
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
                        .planGlassPanel(cornerRadius: 24, fillOpacity: 0.10)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    
                    // Habits List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let habits = habitsForCategory(selectedCategory)
                            ForEach(habits) { habit in
                                HabitCard(habit: habit) {
                                    createHabit(from: habit)
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Space for bottom button
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
                     _ = newItem // Persisted and scheduled by CreatePlanItemView.
                     dismiss() // Dismiss gallery after saving the new item
                 })
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
        newItem.goalValue = template.goalValue
        newItem.goalUnit = template.goalUnit
        
        selectedTemplateItem = newItem
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
                                        Color(red: 0.15, green: 0.71, blue: 0.93).opacity(0.42),
                                        Color(red: 0.12, green: 0.56, blue: 0.86).opacity(0.30)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
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
            HStack(spacing: 16) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: habit.icon)
                        .font(.system(size: 24))
                        .foregroundColor(habit.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Text(habit.subtitle)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(16)
            .planGlassPanel(cornerRadius: 16)
            .cornerRadius(20)
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
