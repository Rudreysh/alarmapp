# Alarmo XP + Rank System Implementation Skill

## Purpose

Implement Alarmo’s gamified XP and Rank system in a safe, testable, and phased way.

This skill should be used when adding or modifying:

- XP earning rules
- Rank progression
- XP transaction storage
- Daily XP caps
- Reward feedback
- Rank UI
- Streak logic
- Habit, alarm, focus, blocking, and HealthKit XP integrations

The goal is to reward meaningful wellness behavior without creating duplicate scoring, exploit loops, or unstable UI/audio behavior.

---

## Core Product Principle

Alarmo XP should reward real behavior, not repeated tapping.

Prioritize:

1. Correctness
2. Anti-duplication
3. Daily cap enforcement
4. Clear user feedback
5. Tunable scoring
6. Local-first implementation
7. Safe future sync compatibility

---

## Required Architecture

### 1. Use a ledger-based XP system

Do not store only a total XP value.

All XP must be granted through an `XPTransaction` ledger.

```swift
struct XPTransaction: Identifiable, Codable, Hashable {
    let id: String
    let sourceType: XPSourceType
    let sourceId: String
    let category: XPCategory
    let amount: Int
    let awardedAt: Date
    let localDay: String
    let alarmId: String?
    let sessionId: String?
    let habitId: String?
    let metadata: [String: String]
}
```

### 2. Enforce idempotency

Every XP grant must have a stable unique key.

Examples:

- `alarm_stop:<alarmId>:<localDate>`
- `alarm_mission:<alarmRunId>:<missionId>`
- `pomodoro_complete:<sessionId>`
- `habit_completion:<habitId>:<localDate>`
- `blocked_focus:<sessionId>`
- `healthkit_steps:<localDate>`
- `hydration:<localDate>`

Never grant duplicate XP for the same source event.

---

## Rank System

### Rank currency

User-facing currency: **XP**

User-facing progression label: **Rank**

### Rank rule

The user starts at: **0 XP = Wood I**

Do not create an unranked state.

### Rank order

Wood I, Wood II, Wood III,
Bronze I, Bronze II, Bronze III,
Silver I, Silver II, Silver III,
Gold I, Gold II, Gold III,
Platinum I, Platinum II, Platinum III,
Diamond I, Diamond II, Diamond III,
Champion I, Champion II, Champion III,
Titan I, Titan II, Titan III,
Olympian I, Olympian II, Olympian III

### Rank thresholds

- Wood I: 0
- Wood II: 40
- Wood III: 110
- Bronze I: 210
- Bronze II: 340
- Bronze III: 500
- Silver I: 700
- Silver II: 940
- Silver III: 1220
- Gold I: 1550
- Gold II: 1930
- Gold III: 2360
- Platinum I: 2840
- Platinum II: 3370
- Platinum III: 3950
- Diamond I: 4580
- Diamond II: 5260
- Diamond III: 5990
- Champion I: 6770
- Champion II: 7600
- Champion III: 8480
- Titan I: 9410
- Titan II: 10390
- Titan III: 11420
- Olympian I: 12500
- Olympian II: 13630
- Olympian III: 14810

Optional post-rank mastery target: **16050 XP**.

### Required rank models

```swift
struct RankLevel: Identifiable, Codable, Hashable {
    let id: Int
    let tier: RankTier
    let stage: Int
    let displayName: String
    let minXP: Int
    let assetName: String
}

enum RankTier: String, Codable, CaseIterable {
    case wood
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case champion
    case titan
    case olympian
}
```

Compute `maxXP` from next rank (`nextRank.minXP - 1`), do not store manually.

### Asset contract

Use standardized asset names (no `.png` in code):

`wood_1..3`, `bronze_1..3`, `silver_1..3`, `gold_1..3`, `platinum_1..3`, `diamond_1..3`, `champion_1..3`, `titan_1..3`, `olympian_1..3`.

All mapping should live in one table/enum.

---

## XP Economy

### Daily limits

- Base wellness cap: `100 XP/day`
- Bonus cap: `60 XP/day`
- Hard cap: `160 XP/day`
- Daily target: `80 XP/day`

### Calculation order

1. Calculate raw base XP by pillar.
2. Apply base pillar caps.
3. Calculate raw bonus XP.
4. Apply bonus category caps.
5. Apply total bonus cap (60).
6. Sum base + bonus.
7. Apply hard cap (160).
8. Persist capped + uncapped totals.

### Base XP pillars

- Wake & sleep: 20
- Morning routine: 15
- Habit/task quality: 20
- Focus productivity: 15
- Movement: 10
- Hydration: 8
- Nutrition/recovery: 6
- Mental wellness: 6

---

## Service Responsibilities

### RankProgressService

- Store XP ledger
- Add XP
- Prevent duplicates
- Resolve current rank
- Compute next-rank progress
- Detect rank-ups and multi-rank crossings

### WellnessXPService

- Calculate base + bonus XP
- Apply all caps
- Build `DailyXPBreakdown`

### RewardFeedbackService

- Queue and throttle XP toasts
- Play SFX
- Trigger haptics/confetti
- Show rank-up modal

### StreakEngineV2

- Track streaks
- Detect milestones and breaks
- Apply comeback bonus

### XPAssetProvider

- Rank-to-badge mapping
- Event-to-sound mapping

---

## Anti-Gaming Guardrails

- Ledger-based dedupe for every grant
- Category caps before hard cap
- No repeat scoring for same habit/alarm/session/day
- Blocking bonus only on meaningful completed activity
- No health/manual double-awards
- Ignore/batch spammy micro-events
- Prevent snooze/start-stop farming loops

---

## Final Rule

If behavior is uncertain, choose the safer path:

- Do not award duplicate XP
- Do not exceed caps
- Do not penalize users unfairly
- Do not break existing alarm/audio behavior
- Keep V1 simple and tunable
