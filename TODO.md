# Alarmo TODO

## General Tasks

- Before release: set `AppPreferences.debugDefaultUpsellValue` to `false` (or remove the dev-only upsell override) so celebration/paywall only show once.
- Before release: set `AppPreferences.debugDefaultOnboardingValue` to `false` (or remove the dev-only onboarding override) so onboarding only shows once.
- Implement StoreKit purchase flow for “Get offer” in discount paywall (close paywall on success, update entitlement, add restore purchases and receipt validation).
- Wire Pro paywall plan selection CTA to StoreKit purchase (yearly/monthly/lifetime) and persist subscription state.
- Re-enable `Notes` in the Plan `+` menu (currently hidden by request); restore quick-create flow and related sheet wiring.

## Habit alarm TODOs

- [ ] Connect Mission selection flow (currently placeholder 0/5)
- [ ] Implement specific mission types (Memory, Shake, Math, etc.)
- [ ] Build Wake up check configuration screen
- [ ] Build Gentle wake-up configuration screen
- [ ] Implement audio sample playback logic for Time/Weather/Extra loud toggles
- [ ] Build Snooze configuration screen
- [ ] Add Pro gating for advanced habit features (if applicable)

## Timer Mode TODOs

- [ ] Implement actual Timer engine (Countdown for Pomo, Count-up for Stopwatch)
- [ ] Connect "Focus" row to a selection modal with different focus categories
- [ ] Implement "Tappable Time" to allow editing Pomo duration and Stopwatch initial state
- [ ] Add sound notifications/alerts when Pomo session ends
- [ ] Implement background task support for timer persistence
- [ ] Add haptic feedback for timer start/stop/pause actions
