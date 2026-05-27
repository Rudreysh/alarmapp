# Alarm Fixes Progress

[DONE] FIX 1 — Reinstall mapping-loss recovery path added in processAlarmKitAlertingAlarm; engine now starts via fallback sound + self-mapping re-establish — 2026-05-27 12:51:03 CEST
[CONFLICT] Build gate requested scheme 'AlarmoAlarm' does not exist in project; validated on scheme 'alarmo' instead — 2026-05-27 12:51:03 CEST
[DONE] FIX 2 — Audible fallback decision hardened (alarmKitFallback OR stopped+scheduled OR waitingForAlarmKit>10s) + helpers timeInCurrentPhase/hasAnyAlarmScheduled — 2026-05-27 12:58:02 CEST
[DONE] FIX 3 — Handoff mapping validity changed to lifecycle-based (source alarm existence), added pruneOrphanedMappings and launch-time prune — 2026-05-27 13:01:45 CEST
[DONE] FIX 4 — Volume<=0.01 while backgrounded now forces alarmKitFallback and schedules immediate (+0.5s) audible AlarmKit recovery — 2026-05-27 13:07:39 CEST
[DONE] FIX 5 — Hardened fallback sound resolution to never return silent assets + added launch-time bundled alarm asset verification in app init — 2026-05-27 13:15:55 CEST
[DONE] FIX 6 — Foreground/AlarmKit race hardened: foreground path now phase-guarded + idempotent; AlarmKit alerting during preparing/fade/primary dismisses surfaces without restarting engine — 2026-05-27 13:18:14 CEST
[DONE] FIX 7 — Bridge start failure now records fallback and schedules immediate audible AlarmKit recovery (same-surface/rebind/new-start paths) — 2026-05-27 13:21:04 CEST
[DONE] FIX 8 — Mid-ring engine failure now triggers immediate audible AlarmKit recovery while preserving existing respawn scheduling — 2026-05-27 13:23:48 CEST
[DONE] FIX 9 — Concurrent AlarmKit alerting now follows first-alarm-wins policy, dismisses new concurrent surface, and records event log — 2026-05-27 13:30:35 CEST
[DONE] FIX 11 — Storage full staging recovery — 2026-05-27 13:40 CEST
  - File: AlarmSchedulerIOS26AlarmKit.swift
  - Test: Not run (manual device/storage scenario pending)
  - Build: BUILD SUCCEEDED ✅
  - Commit: c7b196a

[DONE] FIX 12 — Alarm during phone call defers audible fade-in and resumes after call ends — 2026-05-27 13:44 CEST
  - File: AlarmContinuousAudioEngine.swift
  - Test: Not run (manual phone call scenario pending)
  - Build: BUILD SUCCEEDED ✅
  - Commit: 3dab1cd

