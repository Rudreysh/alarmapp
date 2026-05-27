# Alarm Fixes Progress

[DONE] FIX 1 — Reinstall mapping-loss recovery path added in processAlarmKitAlertingAlarm; engine now starts via fallback sound + self-mapping re-establish — 2026-05-27 12:51:03 CEST
[CONFLICT] Build gate requested scheme 'AlarmoAlarm' does not exist in project; validated on scheme 'alarmo' instead — 2026-05-27 12:51:03 CEST
[DONE] FIX 2 — Audible fallback decision hardened (alarmKitFallback OR stopped+scheduled OR waitingForAlarmKit>10s) + helpers timeInCurrentPhase/hasAnyAlarmScheduled — 2026-05-27 12:58:02 CEST
[DONE] FIX 3 — Handoff mapping validity changed to lifecycle-based (source alarm existence), added pruneOrphanedMappings and launch-time prune — 2026-05-27 13:01:45 CEST
[DONE] FIX 4 — Volume<=0.01 while backgrounded now forces alarmKitFallback and schedules immediate (+0.5s) audible AlarmKit recovery — 2026-05-27 13:07:39 CEST
