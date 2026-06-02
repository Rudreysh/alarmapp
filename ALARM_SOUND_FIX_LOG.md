# Alarm Sound Reliability — Fix Log

Branch: `new-ui`
Build target: `alarmo` scheme, iPhone 17 simulator (iOS 26.2), Debug.
Baseline before any fix: **BUILD SUCCEEDED (exit 0, 0 errors)**.

Rule enforced by all fixes: the alarm sound must play from fire time until the
user presses **Stop** in the custom in-app ringing UI. Nothing else stops it.

---

## [FIX 1 DONE] Removed `.mixWithOthers` — exclusive audio session — BUILD SUCCEEDED

Changed `setCategory(.playback, …)` options from `[.mixWithOthers]` to `[]`:
- `AlarmContinuousAudioEngine.swift` `configureSession()` (was line 320)
- `AlarmContinuousAudioEngine.swift` `configureSessionCategoryOnly()` (was line 327)

**Deviation from instructions (documented):**
- Instruction listed engine lines 327, 373, 380. Verified by grep: the engine had
  only **two** `.mixWithOthers` sites (320, 327). Lines 373/380 are inside the
  interruption handler and never set the category — no change needed/possible there.
- Instruction's Fix 1 omitted `AudioRouteManager.swift`, but it had two more sites:
  `configureAlarmSession()` (line 48) and `forceResetAlarmSession()` (line 82).
  `configureAlarmSession()` runs on **every foreground** (AppRootView scene-active /
  willEnterForeground) and from the notification delegate. Leaving `.mixWithOthers`
  there would re-apply the shared-route policy on each unlock and defeat the engine
  fix. Both were changed to `[]` so the session stays exclusive end-to-end.

Verify: `grep "options: [.mixWithOthers]"` → 0 code matches in both files
(the only remaining textual hits are explanatory comments).

**Risk noted for device testing:** With an exclusive session, the engine's
`setActive(true)` during the AlarmKit settle window can occasionally return
`cannotInterruptOthers` (OSStatus 560557684) if AlarmKit still owns a non-mixable
session. The engine already handles this code (grace window at lines ~97–104) and
retries. Watch the locked-overnight + settle path specifically on a real device.

**Accepted side effect:** other apps' audio (music/podcast) is interrupted at fire
time; resumed on stop via `setActive(false, .notifyOthersOnDeactivation)`.

## [FIX 2 DONE] Added `enforceBuiltInSpeakerOutput` + 6 call sites — BUILD SUCCEEDED

Added private helper `enforceBuiltInSpeakerOutput(context:)` after
`configureSessionCategoryOnly()`. It calls `overrideOutputAudioPort(.speaker)`,
verifies `currentRoute` contains `.builtInSpeaker`, retries up to 3× (0.2s apart),
logs CRITICAL if it never lands on speaker (does not stop the alarm).

Call added immediately after each `setActive(true)` (6 sites, verified = 7 total):
- `session-configure` (configureSession)
- `interruption-ended` (handleInterruption .ended)
- `interruption-retry` (scheduleInterruptionRetries)
- `fade-in-activate` (startFadeIn)
- `post-slide-boost` (applyPostSlideVolumeBoost)
- `watchdog-recover` (recoverPlayerIfNeeded)

Notes:
- Used accurate function-based context labels instead of the instruction's
  loosely-mapped ones (functionally identical; just clearer logs).
- Kept the helper **synchronous** with `Thread.sleep` as specified. Most call
  sites run on the main thread; the sleep only executes on the rare retry when the
  first override does not immediately reflect on the route. First-attempt success
  returns instantly with no sleep.

## [FIX 3 DONE] Route-change observer in engine + AudioRouteManager guard fix — BUILD SUCCEEDED

Engine (`AlarmContinuousAudioEngine.swift`):
- Added `routeChangeObserver` property.
- Added `startRouteChangeObserver()` / `stopRouteChangeObserver()`. On any route
  change while `isEngineActive`, re-applies `enforceBuiltInSpeakerOutput` after 0.3s.
- `startRouteChangeObserver()` called from `configureSession()` and
  `configureSessionCategoryOnly()` (both run at ring start; self-guarded so safe to
  call repeatedly and re-added on each new ring). Removed in `stop(reason:)`.

AudioRouteManager (`AudioRouteManager.swift`):
- Removed the engine-active guard in `handleRouteChange()` only. It now just calls
  `checkCurrentRoute()` (updates published external-output state; does not touch the
  session).

**Deviation from instructions (documented + safety call):**
- Instruction's verify said `grep isEngineActive AudioRouteManager.swift` should be 0.
  That is **unsafe** and I did NOT do it. The other two `isEngineActive` guards —
  `configureAlarmSession()` catch (line 57) and `forceResetAlarmSession()` (line 77) —
  prevent AudioRouteManager from calling `setActive(false)` while the engine owns the
  session. Removing them would deactivate the engine's session mid-alarm = silence,
  the exact bug we are fixing. Only the `handleRouteChange` guard was removed.
- Instruction said install in the same place as the interruption observers
  (`installObserversIfNeeded`). That function is guard-once (`observersInstalled`), so a
  route observer installed there and removed in stop() would never be re-added on the
  next alarm. Installing from the two configure functions (which run at each ring start)
  makes it correctly re-addable.

## [FIX 4 DONE] Background task persists through ring session + .invalid fallback — BUILD SUCCEEDED

`AlarmRingCoordinator.swift`:
- Part A: Removed `self.endRingingBackgroundTask()` from the `.alarmEngineBecamePrimary`
  observer. Bridge still stops there; the coordinator background task now lives until
  user Stop/Snooze. Verified `endRingingBackgroundTask` is no longer in the observer
  (only at: stopRingingInternal line 428, expiry `!isRinging` guard line 812, definition 836).
- Part B: In `beginRingingBackgroundTask()` expiry handler, after re-requesting, check
  `ringingBackgroundTaskID == .invalid`. If iOS refused renewal, call
  `recordFallback(reason: "background-task-refused-by-ios")` to switch to AlarmKit
  audible fallback; otherwise log the renewed id.

Notes:
- Preserved the existing careful old-task cleanup (end old task before requesting new)
  rather than blindly replacing with the instruction's simpler template.
- Used `print(...)` (the coordinator's logging style); the instruction template used
  `log(...)` which does not exist in this class.
- `recordFallback` is called directly (already inside `Task { @MainActor }`; the
  coordinator is `@MainActor`), no extra Task wrapper needed.

## [FIX 5 DONE] Removed 10-min mapping expiry → lifecycle/48h safety net — BUILD SUCCEEDED

`AlarmSchedulingCore.swift` (`AlarmCustomUIHandoffStore`):
- Removed the `maxAge = 10 * 60` property.
- `pendingRequest()`: dropped the time gate (kept `timestamp > 0`). A pending handoff
  is valid until consumed/cleared (Stop/Snooze).
- `sourceAlarmID(forSurfaceAlarmID:)`: **the core snooze fix** — removed the `age <= maxAge`
  check; the surface→source mapping is now valid as long as it exists. Previously, two
  9-min snoozes (>10 min) expired the mapping, the lookup returned the surface UUID, the
  source alarm was not found, and the engine never started → silent 2nd/3rd snooze.
- `pruneOrphanedMappings()`: replaced 10-min cutoff with a 48h safety net (only drops
  genuinely abandoned mappings; bounds map growth).

Verify: `grep "maxAge\|10 * 60"` → 0 matches.

**Deviation from instructions — Step 5 (lifecycle prune) intentionally NOT implemented (documented per work rules):**
The instructed `pruneExpiredMappings()` would prune mappings whose source alarm is absent
from `AlarmStore.shared.alarms`. But the live store is the per-view instance created in
`AppRootView` (`@StateObject AlarmStore()`), which is a **different object** from
`AlarmStore.shared`. `.shared` can hold stale/empty alarms, so pruning against it could
delete VALID mappings and re-introduce the exact silence bug. The 48h safety net already
bounds growth, and removing the time gates fully fixes the snooze-silence symptom, so the
lifecycle prune is unnecessary and net-risky. Skipped deliberately rather than guessing a
store-wiring change larger than described.

## [FIX 6 DONE] Volume KVO observer + floor enforcement — BUILD SUCCEEDED

`AlarmContinuousAudioEngine.swift`:
- Added `volumeObserver: NSKeyValueObservation?` and `volumeEnforcementActive`.
- `startVolumeObserver()` observes `\.outputVolume`. On a downward change below the
  0.15 floor while ringing: sets `player.volume = 1.0` (max headroom) and calls
  `recordFallback(reason: "volume-floor-…")` to layer in AlarmKit's ringer-domain
  audible fallback. `stopVolumeObserver()` invalidates it.
- Wired alongside the route observer in `configureSession()` /
  `configureSessionCategoryOnly()`; removed in `stop(reason:)`.

Notes:
- Typed the token as `NSKeyValueObservation?` (not the instruction's `NSObjectProtocol?`)
  because `observe(_:options:)` returns that; `invalidate()` is the correct teardown.
- Repeated sub-floor volume presses while already in `.alarmKitFallback` are harmless:
  the `.alarmKitFallback → .alarmKitFallback` transition is rejected by the state
  machine and `recordFallback`'s respawn has its own 3s throttle, so no churn.

## [FIX 7 DONE] Legacy alarmStop notification redirects to custom UI — BUILD SUCCEEDED

`NotificationManager.swift` `handleAlarmStopAction`:
- When `ringCoordinator?.isRinging == true`, replaced `ringCoordinator?.stopRinging()`
  with: resolve `sourceAlarmId` from `userInfo["alarmId"]` (the key the alarmRing
  category actually uses) and fall back to the active alarm's id, then
  `requestCustomUIHandoff(...)` + `startOrQueueAlarm(...)`. The not-ringing branch
  (post-ring cleanup) is unchanged.
- Net effect: tapping "Stop" on a notification while ringing opens the custom UI and
  keeps the sound playing; only the custom-UI Stop (after mission) ends the alarm.

Note: used the existing `userInfo["alarmId"]` key (verified against
`scheduleAlarmRingingFallbackChain`), not the instruction's guessed `"sourceAlarmId"`.

---

## Summary — all 7 fixes complete, BUILD SUCCEEDED (exit 0, 0 errors)

Files touched: AlarmContinuousAudioEngine.swift, AudioRouteManager.swift,
AlarmRingCoordinator.swift, AlarmSchedulingCore.swift, NotificationManager.swift.

Net behavioral effect toward the core promise (sound plays from fire until custom-UI
Stop): exclusive audio session (no shared-route silence), forced built-in speaker with
route-change recovery, persistent background task with audible fallback when iOS refuses
renewal, snooze mappings that no longer expire mid-session, a volume floor that cannot be
silenced with the rocker, and notification Stop actions that route to the custom UI
instead of stopping.

### Remaining item NOT in the 7-fix scope (flagged, not changed)
`NotificationManager.handleNotificationStopAction` (around line 1337, the legacy
`alarmStopCard` / `ALARM_STOP_CATEGORY` path) still calls `engine.stop()` +
`recordStopped()` directly when the coordinator is not ringing. This is a separate
notification flow from Fix 7's `handleAlarmStopAction`. It is a known PRD-violation
candidate but was outside the 7 specified fixes, so it was left unchanged. Recommend a
follow-up to route it through the custom UI as well.

### Device-test focus (cannot be validated in simulator)
1. Locked overnight + AlarmKit settle window — watch for `cannotInterruptOthers` after
   removing `.mixWithOthers` (Fix 1 risk note).
2. Repeated snooze (2nd/3rd) now produces sound (Fix 5).
3. AirPods/Bluetooth connected at fire time → sound on phone speaker (Fix 2/3).
4. Volume-down spam during ring → stays audible (Fix 6).
5. Slide-to-stop / notification Stop → sound continues, custom UI required (Fix 7).

---

## [FIX 1 REVERTED] Restored `.mixWithOthers` — device regression confirmed — BUILD SUCCEEDED

**Reason:** On-device log proved removing `.mixWithOthers` breaks the core takeover.
Sequence observed:
```
[Engine] startFadeIn: session activation failed: Session activation failed
Phase appEnginePreparing → alarmKitFallback (reason=session-activation-failed-at-fadein)
→ permanent alarmKitFallback; engine player exists but isPlaying=false forever
→ backup AlarmKit chain respawns a new surface every ~2s (F5AA→311C→B568→85C7→842E→9C0B…)
→ SpringBoard overloaded ("blank screen with loading"), sound restarts with gaps, crash
```

**Root cause:** AlarmKit keeps its own (silent) alarm-sound session active for the
entire ring. With an **exclusive** session, the engine's `setActive(true)` is rejected
with `cannotInterruptOthers` for the whole settle window — not a transient race. The
engine can never go audible, so the state machine locks into `alarmKitFallback`, where
takeover is blocked (`requestAppEngineTakeoverIfAllowed` → "phase alarmKitFallback not
eligible"), and the 2s respawn chain storms the system. This is exactly the risk flagged
under FIX 1 DONE. The PRD's "exclusive session" requirement is **architecturally
incompatible** with this app's silent-AlarmKit + app-engine design.

**Action:** Restored `options: [.mixWithOthers]` at all four sites
(`AlarmContinuousAudioEngine.configureSession` / `configureSessionCategoryOnly`,
`AudioRouteManager.configureAlarmSession` / `forceResetAlarmSession`) and added a
prominent "do NOT remove" comment. Fixes 2–7 remain in place (they are additive and do
not depend on session exclusivity). Speaker enforcement (`overrideOutputAudioPort`) works
fine with `.mixWithOthers`.

### Separate latent bug surfaced by this log (NOT yet fixed — needs decision)
The backup-chain + locked-loop respawn (every ~2s, each new surface dismissing the prior)
is what produces the SpringBoard "blank loading screen" + crash whenever the app is stuck
in `alarmKitFallback`. Reverting Fix 1 removes the trigger in the normal path (engine
takes over → `appEnginePrimary` suppresses respawns). But the storm can still occur on any
genuine prolonged fallback. Recommended follow-up: add a circuit-breaker / max-respawn cap
and a longer backoff to `ensureBackupAlarmKitChain` + `ensureAlarmKitSurfaceForLockedLoopIfNeeded`.
This was outside the original 7-fix scope; flagging rather than guessing a fix.

---

## [FIX 8 DONE] Snooze no longer kills one-shot/quick alarms — BUILD SUCCEEDED

**Symptom:** Pressing Snooze in the custom UI stopped the alarm permanently; it never
rang again after the snooze interval.

**Root cause:** In `AlarmRingCoordinator.stopRingingInternal`, the source-alarm retirement
block ran for BOTH stop and snooze (it was not guarded by `preserveSession`):
```
if alarm.type == .quick { alarmStore?.remove(id:) }          // quick → deleted
else if repeatMask == 0 && !isDaily { toggleEnabled(false) } // one-shot → disabled
```
On snooze (`preserveSession == true`) this deleted/disabled the alarm, so when the snooze
reschedule fired, `alarm(by:)` found no live alarm and the engine never started → silence.
Repeating/daily alarms skipped this block, which is why snooze appeared to work for them.

**Fix:** Wrapped the block in `if !preserveSession { … }`. Snooze now preserves the alarm;
the existing re-ring paths (AlarmKit reschedule via `scheduleSnooze` + the foreground
`asyncAfter` → `startRinging`) fire the alarm again after the configured snooze interval
(snoozeMinutes/snoozeSeconds), and the loop repeats until the user presses Stop. Real Stop
(`!preserveSession`) retires quick/one-shot alarms exactly as before.
