import Foundation

struct SpokenVerseItem: Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
}

enum ReligiousMissionContentStore {
    static let selectedIDsKey = "selectedVerseIDs"

    static func items(for type: WakeUpMissionType) -> [SpokenVerseItem] {
        switch type {
        case .bibleVerse: return bibleVerses
        case .quranVerse: return quranVerses
        case .bhagavadGitaVerse: return bhagavadGitaVerses
        case .affirmation: return affirmations
        default: return []
        }
    }

    static func selectedIDs(from mission: AlarmMission) -> Set<String> {
        guard let stored = mission.customData[selectedIDsKey], !stored.isEmpty else {
            return defaultSelectionIDs(for: mission.type)
        }
        let parsed = Set(
            stored
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return parsed.isEmpty ? defaultSelectionIDs(for: mission.type) : parsed
    }

    static func serializedIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    static func defaultSelectionIDs(for type: WakeUpMissionType) -> Set<String> {
        Set(items(for: type).map(\.id))
    }

    static func pickRandomItem(for mission: AlarmMission) -> SpokenVerseItem? {
        let available = items(for: mission.type)
        guard !available.isEmpty else { return nil }
        let selected = selectedIDs(from: mission)
        let filtered = available.filter { selected.contains($0.id) }
        return (filtered.isEmpty ? available : filtered).randomElement()
    }

    static func sectionTitle(for type: WakeUpMissionType) -> String {
        switch type {
        case .bibleVerse: return "Select Bible Verses"
        case .quranVerse: return "Select Quran Verses"
        case .bhagavadGitaVerse: return "Select Bhagavad Gita Verses"
        case .affirmation: return "Select Affirmations"
        default: return "Select Items"
        }
    }

    static func infoText(for type: WakeUpMissionType) -> String {
        switch type {
        case .affirmation:
            return "A random affirmation from your selection will be shown, and speaking it will complete the mission."
        default:
            return "A random verse from your selection will be shown, and speaking it will complete the mission."
        }
    }

    private static let bibleVerses: [SpokenVerseItem] = [
        .init(id: "bible_jeremiah_29_11", title: "Jeremiah 29:11", text: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future."),
        .init(id: "bible_philippians_4_13", title: "Philippians 4:13", text: "I can do all things through Christ who strengthens me."),
        .init(id: "bible_psalm_23_1_3", title: "Psalm 23:1-3", text: "The Lord is my shepherd; I shall not want. He makes me lie down in green pastures. He leads me beside still waters. He restores my soul."),
        .init(id: "bible_proverbs_3_5_6", title: "Proverbs 3:5-6", text: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."),
        .init(id: "bible_romans_8_28", title: "Romans 8:28", text: "And we know that in all things God works for the good of those who love him."),
        .init(id: "bible_isaiah_41_10", title: "Isaiah 41:10", text: "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you."),
        .init(id: "bible_matthew_6_33", title: "Matthew 6:33", text: "Seek first his kingdom and his righteousness, and all these things will be given to you as well."),
        .init(id: "bible_joshua_1_9", title: "Joshua 1:9", text: "Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.")
    ]

    private static let quranVerses: [SpokenVerseItem] = [
        .init(id: "quran_94_5_6", title: "Ash-Sharh 94:5-6", text: "So, surely with hardship comes ease. Surely with hardship comes ease."),
        .init(id: "quran_2_286", title: "Al-Baqarah 2:286", text: "Allah does not burden a soul beyond that it can bear."),
        .init(id: "quran_13_28", title: "Ar-Rad 13:28", text: "Truly, in the remembrance of Allah do hearts find rest."),
        .init(id: "quran_65_3", title: "At-Talaq 65:3", text: "And whoever relies upon Allah, then He is sufficient for him."),
        .init(id: "quran_20_25_28", title: "Taha 20:25-28", text: "My Lord, expand for me my chest, and ease for me my task, and untie the knot from my tongue so they may understand my speech."),
        .init(id: "quran_3_139", title: "Aal-E-Imran 3:139", text: "Do not lose heart nor fall into despair, for you will be superior if you are true in faith."),
        .init(id: "quran_8_2", title: "Al-Anfal 8:2", text: "The believers are those whose hearts tremble when Allah is mentioned."),
        .init(id: "quran_21_87", title: "Al-Anbiya 21:87", text: "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers.")
    ]

    private static let bhagavadGitaVerses: [SpokenVerseItem] = [
        .init(id: "gita_2_47", title: "Bhagavad Gita 2.47", text: "You have a right to perform your prescribed duty, but you are not entitled to the fruits of your actions."),
        .init(id: "gita_2_50", title: "Bhagavad Gita 2.50", text: "One who acts with wisdom and balance casts off both good and bad results in this life."),
        .init(id: "gita_2_70", title: "Bhagavad Gita 2.70", text: "As rivers flow into the full and still ocean, so desires enter the person who is at peace."),
        .init(id: "gita_4_7_8", title: "Bhagavad Gita 4.7-8", text: "Whenever righteousness declines and unrighteousness rises, I manifest myself to protect the good and reestablish dharma."),
        .init(id: "gita_6_5", title: "Bhagavad Gita 6.5", text: "One must elevate oneself by the mind, not degrade oneself. The mind is both friend and enemy."),
        .init(id: "gita_6_26", title: "Bhagavad Gita 6.26", text: "Wherever the restless mind wanders, bring it back under the control of the self."),
        .init(id: "gita_12_15", title: "Bhagavad Gita 12.15", text: "One from whom the world feels no fear and who is not disturbed by the world is dear to me."),
        .init(id: "gita_18_66", title: "Bhagavad Gita 18.66", text: "Abandon all forms of duty and take refuge in me alone. I shall free you from all sin; do not grieve.")
    ]

    private static let affirmations: [SpokenVerseItem] = [
        .init(id: "affirmation_positive", title: "I Am Positive", text: "I choose positivity and optimism. My thoughts shape my reality, and I choose thoughts that empower me."),
        .init(id: "affirmation_disciplined", title: "I Am Disciplined", text: "I keep promises to myself. I wake up on time and take action with consistency."),
        .init(id: "affirmation_calm", title: "I Am Calm", text: "I am calm, centered, and in control. I respond with clarity and confidence."),
        .init(id: "affirmation_focused", title: "I Am Focused", text: "My mind is clear and focused. I give full attention to what matters most."),
        .init(id: "affirmation_grateful", title: "I Am Grateful", text: "I am grateful for this day and all opportunities within it."),
        .init(id: "affirmation_resilient", title: "I Am Resilient", text: "I am resilient. Challenges strengthen me and help me grow."),
        .init(id: "affirmation_healthy", title: "I Am Healthy", text: "My body is strong, my mind is sharp, and my energy is high."),
        .init(id: "affirmation_capable", title: "I Am Capable", text: "I am capable of achieving meaningful goals through small daily steps.")
    ]
}
