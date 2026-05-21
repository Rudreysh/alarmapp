# Product Requirements Document: Alarmo Gamified XP + Rank System

## 1. Objective

Build a motivating, health-oriented XP and Rank progression system for Alarmo that rewards wake discipline, focus, habits, movement, hydration, and routine completion.

The system should feel rewarding, avoid exploit loops, and remain local-only in v1 while staying extensible for sync/leaderboards later.

## 2. Product Goals

- Increase engagement and retention
- Encourage real behavior change
- Reward meaningful daily wellness actions
- Keep early progress motivating and later progress meaningful
- Prevent duplicate/farmed XP
- Ship local-only first with clean upgrade path

## 3. Non-Goals (V1)

- Global/friends leaderboard
- Percentiles
- Backend anti-cheat/verification
- Cross-device sync
- Seasonal ladder
- Social sharing

## 4. Phases

### V1

- Rank definitions + asset mapping
- XP ledger
- RankProgressService
- WellnessXPService
- Alarm, focus, habit XP
- Daily caps
- Rank row in Settings
- Rank Progress screen
- XP toasts + rank-up modal + haptics/SFX/confetti

### V1.1

- Streak systems
- Comeback bonus
- Blocking/social multipliers + milestones

### V1.2

- HealthKit movement/hydration contribution
- Manual fallback and anti-double-count

### V2

- Social, leaderboard, sync, seasonal systems

## 5. Core Rank Model

- Currency: XP
- Label: Rank
- Start state: **0 XP = Wood I**
- Total visible ranks: 27 (Wood I → Olympian III)

### Thresholds

| Rank | Min XP |
|---|---:|
| Wood I | 0 |
| Wood II | 40 |
| Wood III | 110 |
| Bronze I | 210 |
| Bronze II | 340 |
| Bronze III | 500 |
| Silver I | 700 |
| Silver II | 940 |
| Silver III | 1220 |
| Gold I | 1550 |
| Gold II | 1930 |
| Gold III | 2360 |
| Platinum I | 2840 |
| Platinum II | 3370 |
| Platinum III | 3950 |
| Diamond I | 4580 |
| Diamond II | 5260 |
| Diamond III | 5990 |
| Champion I | 6770 |
| Champion II | 7600 |
| Champion III | 8480 |
| Titan I | 9410 |
| Titan II | 10390 |
| Titan III | 11420 |
| Olympian I | 12500 |
| Olympian II | 13630 |
| Olympian III | 14810 |

Optional mastery: 16050 XP.

## 6. XP Economy

- Base cap: 100/day
- Bonus cap: 60/day
- Hard cap: 160/day
- Daily target UI: 80/day

### Base pillars

- Wake/sleep 20
- Morning routine 15
- Habit quality 20
- Focus 15
- Movement 10
- Hydration 8
- Nutrition/recovery 6
- Mental wellness 6

### Calculation order

1. Raw base
2. Base caps
3. Raw bonus
4. Bonus caps
5. Bonus total cap
6. Sum
7. Hard cap
8. Persist capped + uncapped totals

## 7. Scoring Rules (V1 core)

### Alarm

- On-time dismiss: +12 base
- Late valid dismiss: +6 base
- Mission complete: +6 bonus
- Hard mission: +4 bonus
- No-snooze day: +5 bonus

### Focus

- 15–24m: +4 base
- 25–49m: +7 base
- 50m+: +10 base
- Interrupted: +1..+3 base

### Habit

- Small: +2 base
- Medium: +4 base
- Large: +6 base
- In-window: +1 bonus
- All planned complete: +5 bonus

### Blocking bonuses (V1.1)

- Focus completed while blocked: +8 bonus
- 50m+ blocked focus: +5 bonus
- 4 blocked sessions/day: +12 bonus
- Blocking bonus sub-cap: 30/day

### Social multiplier (V1.1)

If blocked set includes social apps: apply `x1.25` to blocking XP only.

## 8. Ledger + Idempotency

All XP grants must be transactions, never direct total mutation.

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

Unique key rule: `sourceType + sourceId + localDay`.

## 9. UX Requirements

- Settings top-right: Free/Pro chip
- Replace points slot with streak card
- Replace prior Pro row slot with Rank row
- Rank row tap opens Rank Progress screen
- Rank screen shows current rank, XP, next rank progress, locked ladder states, and XP needed
- Reward feedback: gold/yellow XP, short SFX, haptics, confetti for major events

## 10. Asset Contract

Use exactly:

- wood_1..3
- bronze_1..3
- silver_1..3
- gold_1..3
- platinum_1..3
- diamond_1..3
- champion_1..3
- titan_1..3
- olympian_1..3

## 11. Anti-Gaming Rules

- Dedupe all events via ledger keys
- One habit full reward per habit/day
- One alarm stop reward per alarm run
- One focus completion reward per session
- No manual+HealthKit double-award for same pillar/day
- Enforce category caps before daily cap
- Ignore spam loops

## 12. Implementation Order

1. Rank models + thresholds + asset mapping
2. XPTransaction ledger
3. RankProgressService
4. DailyXPBreakdown model
5. WellnessXPService
6. Alarm XP hooks
7. Reward feedback layer
8. Settings rank row
9. Rank Progress screen
10. Focus XP hooks
11. Habit XP hooks
12. StreakEngineV2
13. Blocking/social bonus logic
14. HealthKit contribution
15. Telemetry + tests + tuning

## 13. QA Checklist

- 0 XP shows Wood I
- Threshold lookup accuracy
- Rank-up correctness (single + multi-crossing)
- Duplicate event prevention
- Pillar caps and hard cap enforcement
- Alarm/focus/habit grants behave per rules
- Rank UI updates live
- Reward UI not spammy
- SFX/haptics load correctly

## 14. Success Metrics

- D1/D7 retention
- Alarm completion and no-snooze rates
- Focus completion rate
- Habit completion rate
- Average XP/day
- Early-tier progression rates (Wood III, Bronze I)
- Rank screen visits and rank-up modal impressions

## 15. Product Principle

Reward consistency, not taps.

V1 prioritizes clarity, stability, anti-duplication, and tunable economy.
