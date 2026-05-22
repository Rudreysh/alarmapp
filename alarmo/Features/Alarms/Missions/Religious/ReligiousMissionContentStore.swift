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
        .init(id: "bible_joshua_1_9", title: "Joshua 1:9", text: "Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go."),
        .init(id: "bible_genesis_1_1", title: "Genesis 1:1", text: "In the beginning God created the heaven and the earth."),
        .init(id: "bible_psalm_46_10", title: "Psalm 46:10", text: "Be still, and know that I am God."),
        .init(id: "bible_psalm_119_105", title: "Psalm 119:105", text: "Your word is a lamp unto my feet, and a light unto my path."),
        .init(id: "bible_proverbs_16_3", title: "Proverbs 16:3", text: "Commit your works to the Lord, and your plans will be established."),
        .init(id: "bible_proverbs_27_17", title: "Proverbs 27:17", text: "As iron sharpens iron, so one person sharpens another."),
        .init(id: "bible_isaiah_40_31", title: "Isaiah 40:31", text: "Those who wait on the Lord shall renew their strength; they shall mount up with wings as eagles."),
        .init(id: "bible_jeremiah_33_3", title: "Jeremiah 33:3", text: "Call unto me, and I will answer you, and show you great and mighty things, which you do not know."),
        .init(id: "bible_matthew_11_28", title: "Matthew 11:28", text: "Come unto me, all you who labor and are heavy laden, and I will give you rest."),
        .init(id: "bible_matthew_5_16", title: "Matthew 5:16", text: "Let your light so shine before men, that they may see your good works."),
        .init(id: "bible_john_3_16", title: "John 3:16", text: "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life."),
        .init(id: "bible_john_14_6", title: "John 14:6", text: "I am the way, the truth, and the life. No one comes to the Father except through me."),
        .init(id: "bible_john_16_33", title: "John 16:33", text: "In the world you shall have tribulation: but be of good cheer; I have overcome the world."),
        .init(id: "bible_romans_12_2", title: "Romans 12:2", text: "Do not be conformed to this world, but be transformed by the renewing of your mind."),
        .init(id: "bible_1corinthians_10_13", title: "1 Corinthians 10:13", text: "God is faithful; He will not let you be tempted beyond what you can bear."),
        .init(id: "bible_2timothy_1_7", title: "2 Timothy 1:7", text: "God has not given us the spirit of fear, but of power, and of love, and of a sound mind."),
        .init(id: "bible_hebrews_11_1", title: "Hebrews 11:1", text: "Now faith is the substance of things hoped for, the evidence of things not seen."),
        .init(id: "bible_james_1_5", title: "James 1:5", text: "If any of you lacks wisdom, let him ask of God, who gives generously to all without reproach.")
    ]

    private static let quranVerses: [SpokenVerseItem] = [
        .init(id: "quran_94_5_6", title: "Ash-Sharh 94:5-6", text: "So, surely with hardship comes ease. Surely with hardship comes ease."),
        .init(id: "quran_2_286", title: "Al-Baqarah 2:286", text: "Allah does not burden a soul beyond that it can bear."),
        .init(id: "quran_13_28", title: "Ar-Rad 13:28", text: "Truly, in the remembrance of Allah do hearts find rest."),
        .init(id: "quran_65_3", title: "At-Talaq 65:3", text: "And whoever relies upon Allah, then He is sufficient for him."),
        .init(id: "quran_20_25_28", title: "Taha 20:25-28", text: "My Lord, expand for me my chest, and ease for me my task, and untie the knot from my tongue so they may understand my speech."),
        .init(id: "quran_3_139", title: "Aal-E-Imran 3:139", text: "Do not lose heart nor fall into despair, for you will be superior if you are true in faith."),
        .init(id: "quran_8_2", title: "Al-Anfal 8:2", text: "The believers are those whose hearts tremble when Allah is mentioned."),
        .init(id: "quran_21_87", title: "Al-Anbiya 21:87", text: "There is no deity except You; exalted are You. Indeed, I have been of the wrongdoers."),
        .init(id: "quran_1_1", title: "Al-Fatihah 1:1", text: "In the name of Allah, the Beneficent, the Merciful."),
        .init(id: "quran_1_5", title: "Al-Fatihah 1:5", text: "You alone we worship; You alone we ask for help."),
        .init(id: "quran_1_6", title: "Al-Fatihah 1:6", text: "Show us the straight path."),
        .init(id: "quran_2_45", title: "Al-Baqarah 2:45", text: "Seek help in patience and prayer."),
        .init(id: "quran_2_152", title: "Al-Baqarah 2:152", text: "Remember Me; I will remember you. Give thanks to Me and do not reject Me."),
        .init(id: "quran_2_153", title: "Al-Baqarah 2:153", text: "Seek help through patience and prayer. Truly Allah is with the steadfast."),
        .init(id: "quran_2_255", title: "Al-Baqarah 2:255", text: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of existence."),
        .init(id: "quran_3_8", title: "Aal-E-Imran 3:8", text: "Our Lord, do not let our hearts deviate after You have guided us; grant us mercy from Yourself."),
        .init(id: "quran_3_159", title: "Aal-E-Imran 3:159", text: "When you decide, put your trust in Allah. Truly Allah loves those who trust in Him."),
        .init(id: "quran_8_46", title: "Al-Anfal 8:46", text: "Obey Allah and His Messenger, and do not dispute lest you lose courage and your strength depart."),
        .init(id: "quran_9_51", title: "At-Tawbah 9:51", text: "Nothing will befall us except what Allah has decreed for us. He is our Protector."),
        .init(id: "quran_12_87", title: "Yusuf 12:87", text: "Do not despair of relief from Allah; none despairs of relief from Allah except disbelieving people."),
        .init(id: "quran_14_7", title: "Ibrahim 14:7", text: "If you are grateful, I will surely give you more."),
        .init(id: "quran_16_97", title: "An-Nahl 16:97", text: "Whoever does righteousness, whether male or female, while a believer, We will grant them a good life."),
        .init(id: "quran_24_35", title: "An-Nur 24:35", text: "Allah is the Light of the heavens and the earth."),
        .init(id: "quran_29_69", title: "Al-Ankabut 29:69", text: "Those who strive for Us, We shall surely guide them to Our ways."),
        .init(id: "quran_39_53", title: "Az-Zumar 39:53", text: "Do not despair of the mercy of Allah; truly Allah forgives all sins.")
    ]

    private static let bhagavadGitaVerses: [SpokenVerseItem] = [
        .init(id: "gita_2_47", title: "Bhagavad Gita 2.47", text: "You have a right to perform your prescribed duty, but you are not entitled to the fruits of your actions."),
        .init(id: "gita_2_50", title: "Bhagavad Gita 2.50", text: "One who acts with wisdom and balance casts off both good and bad results in this life."),
        .init(id: "gita_2_70", title: "Bhagavad Gita 2.70", text: "As rivers flow into the full and still ocean, so desires enter the person who is at peace."),
        .init(id: "gita_4_7_8", title: "Bhagavad Gita 4.7-8", text: "Whenever righteousness declines and unrighteousness rises, I manifest myself to protect the good and reestablish dharma."),
        .init(id: "gita_6_5", title: "Bhagavad Gita 6.5", text: "One must elevate oneself by the mind, not degrade oneself. The mind is both friend and enemy."),
        .init(id: "gita_6_26", title: "Bhagavad Gita 6.26", text: "Wherever the restless mind wanders, bring it back under the control of the self."),
        .init(id: "gita_12_15", title: "Bhagavad Gita 12.15", text: "One from whom the world feels no fear and who is not disturbed by the world is dear to me."),
        .init(id: "gita_18_66", title: "Bhagavad Gita 18.66", text: "Abandon all forms of duty and take refuge in me alone. I shall free you from all sin; do not grieve."),
        .init(id: "gita_2_14", title: "Bhagavad Gita 2.14", text: "Contacts with matter give cold and heat, pleasure and pain; they come and go, and must be endured."),
        .init(id: "gita_2_20", title: "Bhagavad Gita 2.20", text: "The Self is never born and never dies. It is unborn, eternal, everlasting, ancient."),
        .init(id: "gita_2_38", title: "Bhagavad Gita 2.38", text: "Treat pleasure and pain, gain and loss, victory and defeat alike; then engage in battle."),
        .init(id: "gita_2_48", title: "Bhagavad Gita 2.48", text: "Perform action with steadfast yoga, abandoning attachment, and remain even-minded in success and failure."),
        .init(id: "gita_2_71", title: "Bhagavad Gita 2.71", text: "One who abandons all desires and moves without craving, possessiveness, or ego, attains peace."),
        .init(id: "gita_3_19", title: "Bhagavad Gita 3.19", text: "Therefore perform action without attachment; by acting without attachment one reaches the Supreme."),
        .init(id: "gita_3_30", title: "Bhagavad Gita 3.30", text: "Dedicate all actions to Me, with mind on the Self, free from longing and selfishness."),
        .init(id: "gita_4_13", title: "Bhagavad Gita 4.13", text: "The fourfold order was created by Me according to qualities and actions."),
        .init(id: "gita_4_39", title: "Bhagavad Gita 4.39", text: "The faithful who are devoted and self-controlled attain knowledge; attaining knowledge, they gain supreme peace."),
        .init(id: "gita_5_10", title: "Bhagavad Gita 5.10", text: "One who performs action, offering it to the Absolute and abandoning attachment, is untouched by sin, like a lotus leaf by water."),
        .init(id: "gita_5_18", title: "Bhagavad Gita 5.18", text: "The wise see with equal vision a learned priest, a cow, an elephant, a dog, and an outcaste."),
        .init(id: "gita_6_6", title: "Bhagavad Gita 6.6", text: "For one who has conquered the mind, the mind is the best of friends; for one who has failed, the mind is the greatest enemy."),
        .init(id: "gita_6_35", title: "Bhagavad Gita 6.35", text: "The restless mind is hard to control, but by practice and detachment it can be restrained."),
        .init(id: "gita_8_7", title: "Bhagavad Gita 8.7", text: "Remember Me at all times and fight. With mind and intellect fixed on Me, you shall come to Me."),
        .init(id: "gita_9_22", title: "Bhagavad Gita 9.22", text: "To those who are constantly devoted and worship Me with love, I carry what they lack and preserve what they have."),
        .init(id: "gita_10_20", title: "Bhagavad Gita 10.20", text: "I am the Self seated in the hearts of all beings; I am the beginning, middle, and end of all beings."),
        .init(id: "gita_12_13_14", title: "Bhagavad Gita 12.13-14", text: "One who has no hatred for any being, who is friendly, compassionate, free from possessiveness and ego, patient and forgiving, is dear to Me.")
    ]

    private static let affirmations: [SpokenVerseItem] = [
        .init(id: "affirmation_positive", title: "I Am Positive", text: "I choose positivity and optimism. My thoughts shape my reality, and I choose thoughts that empower me."),
        .init(id: "affirmation_disciplined", title: "I Am Disciplined", text: "I keep promises to myself. I wake up on time and take action with consistency."),
        .init(id: "affirmation_calm", title: "I Am Calm", text: "I am calm, centered, and in control. I respond with clarity and confidence."),
        .init(id: "affirmation_focused", title: "I Am Focused", text: "My mind is clear and focused. I give full attention to what matters most."),
        .init(id: "affirmation_grateful", title: "I Am Grateful", text: "I am grateful for this day and all opportunities within it."),
        .init(id: "affirmation_resilient", title: "I Am Resilient", text: "I am resilient. Challenges strengthen me and help me grow."),
        .init(id: "affirmation_healthy", title: "I Am Healthy", text: "My body is strong, my mind is sharp, and my energy is high."),
        .init(id: "affirmation_capable", title: "I Am Capable", text: "I am capable of achieving meaningful goals through small daily steps."),
        .init(id: "affirmation_confident", title: "I Am Confident", text: "I trust my decisions and carry myself with confidence."),
        .init(id: "affirmation_brave", title: "I Am Brave", text: "I face discomfort with courage and move forward anyway."),
        .init(id: "affirmation_patient", title: "I Am Patient", text: "I am patient with my progress and committed to steady growth."),
        .init(id: "affirmation_consistent", title: "I Am Consistent", text: "I show up every day and build momentum through consistency."),
        .init(id: "affirmation_worthy", title: "I Am Worthy", text: "I am worthy of success, peace, and meaningful relationships."),
        .init(id: "affirmation_creative", title: "I Am Creative", text: "Creative solutions come to me naturally and easily."),
        .init(id: "affirmation_energetic", title: "I Am Energetic", text: "My energy is strong and I use it with purpose."),
        .init(id: "affirmation_present", title: "I Am Present", text: "I stay present in this moment and focus on what I can do now."),
        .init(id: "affirmation_adaptable", title: "I Am Adaptable", text: "I adapt quickly to change and find opportunity in uncertainty."),
        .init(id: "affirmation_kind", title: "I Am Kind", text: "I treat myself and others with kindness and respect."),
        .init(id: "affirmation_free", title: "I Am Free", text: "I release what no longer serves me and choose what uplifts me."),
        .init(id: "affirmation_strong", title: "I Am Strong", text: "I am stronger than my doubts and more powerful than my fears."),
        .init(id: "affirmation_grounded", title: "I Am Grounded", text: "I stay grounded, balanced, and calm in every situation."),
        .init(id: "affirmation_open", title: "I Am Open", text: "I am open to growth, learning, and new possibilities."),
        .init(id: "affirmation_optimistic", title: "I Am Optimistic", text: "I expect good outcomes and keep a hopeful mindset."),
        .init(id: "affirmation_clear", title: "I Am Clear", text: "My priorities are clear and my actions are aligned."),
        .init(id: "affirmation_leader", title: "I Am a Leader", text: "I lead by example with integrity, discipline, and heart."),
        .init(id: "affirmation_decisive", title: "I Am Decisive", text: "I make decisions with clarity and confidence."),
        .init(id: "affirmation_resourceful", title: "I Am Resourceful", text: "I find solutions with the resources I have right now."),
        .init(id: "affirmation_humble", title: "I Am Humble", text: "I stay humble, curious, and willing to improve."),
        .init(id: "affirmation_determined", title: "I Am Determined", text: "I stay determined and follow through until I finish."),
        .init(id: "affirmation_supported", title: "I Am Supported", text: "I am supported by people, opportunities, and grace."),
        .init(id: "affirmation_fearless", title: "I Am Fearless", text: "I release fear and take action with boldness."),
        .init(id: "affirmation_composed", title: "I Am Composed", text: "I remain composed under pressure and think clearly."),
        .init(id: "affirmation_persistent", title: "I Am Persistent", text: "I keep going even when progress feels slow."),
        .init(id: "affirmation_selfcontrol", title: "I Have Self-Control", text: "I choose actions that support my long-term goals."),
        .init(id: "affirmation_selfrespect", title: "I Respect Myself", text: "I honor my values, boundaries, and commitments."),
        .init(id: "affirmation_loved", title: "I Am Loved", text: "I give and receive love freely and sincerely."),
        .init(id: "affirmation_peaceful", title: "I Am Peaceful", text: "Peace lives within me and guides my choices."),
        .init(id: "affirmation_abundant", title: "I Am Abundant", text: "I welcome abundance in health, relationships, and work."),
        .init(id: "affirmation_learning", title: "I Am Learning", text: "Every day I learn, improve, and become wiser."),
        .init(id: "affirmation_forgiving", title: "I Am Forgiving", text: "I forgive myself and others so I can move forward."),
        .init(id: "affirmation_balance", title: "I Am Balanced", text: "I create balance between effort, rest, and joy."),
        .init(id: "affirmation_successful", title: "I Am Successful", text: "I create success through clarity, action, and discipline."),
        .init(id: "affirmation_honest", title: "I Am Honest", text: "I speak and act with honesty and authenticity."),
        .init(id: "affirmation_courageous", title: "I Am Courageous", text: "I take brave steps toward the life I want."),
        .init(id: "affirmation_deserving", title: "I Deserve Good Things", text: "I deserve joy, peace, and meaningful progress."),
        .init(id: "affirmation_believe", title: "I Believe in Myself", text: "I believe in myself and trust my journey."),
        .init(id: "affirmation_grace", title: "I Move with Grace", text: "I move through challenges with grace and strength."),
        .init(id: "affirmation_inspired", title: "I Am Inspired", text: "I am inspired to take aligned action every day."),
        .init(id: "affirmation_committed", title: "I Am Committed", text: "I am committed to my vision and I keep showing up."),
        .init(id: "affirmation_safe", title: "I Am Safe", text: "I am safe, protected, and guided in each moment."),
        .init(id: "affirmation_motivated", title: "I Am Motivated", text: "I am motivated to do what matters most today."),
        .init(id: "affirmation_progress", title: "I Make Progress", text: "I make progress every day, one step at a time."),
        .init(id: "affirmation_centered", title: "I Am Centered", text: "I return to my center and act from calm confidence."),
        .init(id: "affirmation_radiant", title: "I Am Radiant", text: "I carry positive energy and uplift the spaces I enter."),
        .init(id: "affirmation_ready", title: "I Am Ready", text: "I am ready for the opportunities and growth ahead."),
        .init(id: "affirmation_unstoppable", title: "I Am Unstoppable", text: "With discipline and faith, I keep moving forward.")
    ]
}
