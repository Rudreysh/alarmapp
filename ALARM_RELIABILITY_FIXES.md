# Alarm Reliability Fixes — Complete Reference

**Project:** Awayk  
**Date:** 2026-05-30  
**Branch:** `sound-fix-issue`  
**Status:** All issues resolved and verified working (volume control added 2026-05-30; stale handoff cleanup added 2026-05-31; side-button and badge-tap fixes added 2026-05-31)

---

## Table of Contents

1. [User Requirements](#1-user-requirements)
2. [Architecture Overview](#2-architecture-overview)
3. [How the Alarm Flow Works](#3-how-the-alarm-flow-works)
4. [Issues Found and Fixed](#4-issues-found-and-fixed)
5. [Files Changed](#5-files-changed)
6. [Expected Behavior After Fixes](#6-expected-behavior-after-fixes)
7. [Known Limitations](#7-known-limitations)

> **Issue 15 (Volume control) and Issue 16 (Stale handoff state cleanup) were added after initial document creation — see section 4 and section 5 for the updates.**

---

## 1. User Requirements

These are the requirements the user defined, used to guide all fixes.

### R1 — Sound Reliability (Deleted/Missing Sounds)
When a user selects a sound that later becomes unavailable (cloud sound deleted, custom sound removed), the alarm must still ring. Every alarm must have a guaranteed bundled fallback sound. The user must never wake up to silence because a sound file was missing.

### R2 — Reliable Alarm After Long Delays (2–4+ Hours)
An alarm set for several hours in the future, with the phone locked overnight, must ring on time with audible sound. 1-minute test alarms already worked. The failure was specific to long-delay locked-phone scenarios.

### R3 — Slide-to-Stop Must Not Kill the Alarm
When the user swipes "slide to stop" on the AlarmKit lock-screen badge, the alarm sound must **not stop**. Sound should continue playing in the background. The AlarmKit UI (badge) can go away, but the sound keeps going until the user explicitly presses Stop in the in-app UI.

### R4 — Slide-to-Stop Must Trigger Phone Unlock
When the user presses slide-to-stop, iOS must immediately prompt for Face ID or passcode. Once authenticated, the phone unlocks and the full-screen in-app alarm UI is shown with Stop and Snooze buttons.

### R5 — Snooze Must Work Correctly
Pressing Snooze in the in-app UI must:
- Pause the current alarm sound immediately
- Ring again after the configured snooze interval (set per alarm)
- Not kill the alarm permanently

### R6 — Volume Levels and Gentle Wake-Up Must Be Applied
Volume level and gentle wake-up duration configured in alarm settings must actually affect playback. The engine was previously always using 100% volume with an 8-second fade regardless of settings.

### R7 — No Double Audio / Echo Effect
When AlarmKit fires and the app engine takes over, both should play the same sound at the same playback position. No echo, no phase offset, no two copies of the same track at different timestamps.

### R9 — Volume Levels Must Match User Settings and Be Enforced
The alarm must play at the volume level configured in the alarm's settings. If the user configured 80% volume, the alarm should play at 80% regardless of where the phone's media volume was left. When the user presses volume-down during an active alarm (app foreground), the volume should immediately go back up to the configured level — the same behavior seen in Alarmy where the volume HUD shows going back up.

### R8 — Consistent Alarm Architecture (Alarmy-like)
The alarm should behave like the Alarmy app:
- Sound starts ~3–4 seconds after lock screen UI appears (settle delay)
- Slide-to-stop does not stop the sound
- Side buttons (volume rocker) do not reduce alarm volume to silence
- Alarm must be dismissed only via the in-app Stop or Snooze button

---

## 2. Architecture Overview

### Key Components

| Component | File | Role |
|---|---|---|
| `AlarmSchedulerIOS26AlarmKit` | `AlarmSchedulerIOS26AlarmKit.swift` | Schedules AlarmKit alarms, configures sound, handles `StopAlarmIntent` |
| `AlarmContinuousAudioEngine` | `AlarmContinuousAudioEngine.swift` | AVAudioPlayer-based engine; loops alarm sound continuously |
| `AlarmAudioStateController` | `AlarmAudioStateController.swift` | Phase state machine; coordinates engine takeover |
| `AlarmBackgroundAudioBridge` | `AlarmBackgroundAudioBridge.swift` | 50ms watchdog; keeps audio alive in background |
| `AlarmForegroundScheduler` | `AlarmForegroundScheduler.swift` | Timer-based scheduler when app is foreground (5s poll + precise timer) |
| `AlarmRingCoordinator` | `AlarmRingCoordinator.swift` | Manages ring session, stop, snooze, missions |
| `NotificationManager` | `NotificationManager.swift` | Observes AlarmKit updates, sends unlock prompts |
| `SoundCatalogRepository` | `SoundCatalogRepository.swift` | Loads bundled/custom/cloud sounds for the picker UI |
| `SoundConfig` | `SoundConfig.swift` | List of bundled alarm tone filenames |
| `SoundPickerView` | `SoundPickerView.swift` | UI for selecting alarm sounds; handles sound deletion |

### Audio Domain Split

| Domain | Owner | Affected by mute switch? | Affected by media volume? |
|---|---|---|---|
| Ringer | AlarmKit | No (bypasses) | No |
| Media (`.playback`) | App engine | No (bypasses) | Yes |

This split is critical. AlarmKit's configured sound plays in the **ringer domain** — it rings even when the phone is on silent and media volume is 0. The app engine plays in the **media domain** — it requires media volume > 0 to be audible. Both play simultaneously after the engine fades in; they mix via `.mixWithOthers`.

### Bundled Sound Files

Located at `alarmo/Resources/BundledSounds/ringtones/`:

| File | Display Name |
|---|---|
| `Default Alarm.caf` | Default Alarm |
| `Clock Alarm.caf` | Clock Alarm |
| `Cockpit Alert.caf` | Cockpit Alert |
| `Alarm.caf` | Alarm |
| `bbc_electronic.caf` | BBC Electronic |

These five files are **always present** in the compiled app bundle. They are the guaranteed fallback sounds.

---

## 3. How the Alarm Flow Works

### 3.1 Normal Alarm Fire (Phone Locked, Long Delay)

```
T=0     AlarmKit fires
        → AlarmKit plays configured sound in ringer domain (audible immediately)
        → App wakes in background
        → NotificationManager observes .alerting state
        → handleAlarmKitAlerting() called
        → prepareSilently(): creates AVAudioPlayer, prepareToPlay() (not started yet)
        → scheduleDelayedTakeover(delay: 3.0s)

T=3s    scheduleDelayedTakeover fires
        → requestAppEngineTakeoverIfAllowed()
        → startFadeIn(): setActive(true), play(), seek to AlarmKit elapsed position
        → Engine fades from 0.15 → targetVolume over gentleWakeUpSeconds
        → Phase: alarmKitSettling → appEngineFadingIn

T=3+fadeIn  Engine fully faded in
        → Phase: appEnginePrimary
        → AlarmKit ringer + engine both playing (mix via .mixWithOthers)
        → User hears alarm from ringer domain immediately at T=0
        → Engine provides continuous looping audio from T=3s
```

### 3.2 Why Short Tests Always Worked

`AlarmForegroundScheduler` polls every 5 seconds. When the app is in foreground (short tests), it catches the alarm and calls `startRinging()` directly. The audio session is warm, the engine starts immediately, and AlarmKit's settle window is bypassed. This is why 1-minute alarms always worked but 2-4 hour locked-phone alarms failed.

### 3.3 Slide-to-Stop Flow (After Fixes)

```
User swipes slide-to-stop on lock screen
→ StopAlarmIntent.perform() runs
→ openAppWhenRun = true: iOS shows Face ID / passcode prompt IMMEDIATELY
→ User authenticates
→ App opens (foreground)
→ shouldUseLockedHandling = false (app is now active)
→ Posts alarmKitCustomUIHandoffRequested
→ Full-screen alarm ringing UI appears
→ Engine has been playing continuously throughout (never stopped)
→ User presses Stop or Snooze
```

### 3.4 Snooze Flow

```
User presses Snooze in in-app UI
→ stopRingingInternal(preserveSession: true)
→ clearCompletedAlarmFlow() — clears suppression so snooze alarm fires correctly
→ scheduler.scheduleSnooze() — schedules new AlarmKit alarm at now + snoozeInterval
→ Sound stops immediately
→ asyncAfter(snoozeInterval): startRinging() if still in foreground
→ AlarmKit alarm fires at snooze time (phone locked path)
→ Full ring cycle restarts
```

### 3.5 Phase State Machine

```
stopped → waitingForAlarmKit → alarmKitSettling → appEnginePreparing
        → appEngineFadingIn → appEnginePrimary

Failure path: any phase → alarmKitFallback (engine failed, AlarmKit becomes audio owner)
```

---

## 4. Issues Found and Fixed

### Issue 1 — `findFallbackSound()` Picked SFX/Rank Sounds

**File:** `AlarmContinuousAudioEngine.swift`  
**Symptom:** When the engine needed a fallback sound, it picked a random audio file from the bundle, sometimes selecting SFX sound effects (rank-up sounds, coin sounds) instead of alarm tones.  
**Root Cause:** The function scanned the entire bundle and returned the first audio file found, with no preference ordering.  
**Fix:** Rewrote `findFallbackSound()` with a priority list: tries `defaultalarm` → `clockalarm` → `alarm` by normalized name before any generic scan. SFX files (in `/SFX/` or `/Ranks/` paths) are explicitly excluded from the first two priority tiers.

---

### Issue 2 — Deleted Cloud Sounds Left Alarms Silent

**File:** `SoundPickerView.swift`  
**Symptom:** If a user downloaded a cloud sound (e.g., "Birds Chirping"), set it as their alarm sound, then deleted it from the app, the alarm would fire with no sound at all.  
**Root Cause:** The deletion path only deleted the file; it did not update alarms that referenced the deleted sound name.  
**Fix:** Added `deleteDownloadedSound(remoteSound:)` helper. Before deleting the file, it iterates all alarms in `AlarmStore.shared`. Any alarm with `soundName == deletedTitle` is updated to `"Default Alarm"` via `AlarmStore.shared.update(alarm)`. Same fix applied to custom sound deletion via `commitDelete()`.

---

### Issue 3 — AlarmKit Always Configured with Silent Sound

**File:** `AlarmSchedulerIOS26AlarmKit.swift` — `makeConfiguration()`  
**Symptom:** After 2–4 hours with phone locked, the alarm would show the AlarmKit lock-screen badge but produce zero sound. User sees the UI but hears nothing.  
**Root Cause:** `makeConfiguration()` configured AlarmKit with `alarmo_silence.caf` (a generated 1-second silent audio file) for every alarm. The design assumed the app engine would always take over within 3 seconds. If the engine failed for any reason, there was no audible backup.  
**Fix:** Changed `makeConfiguration()` to always attempt staging the user's selected sound. If staging succeeds, AlarmKit uses the real alarm tone in the **ringer domain** (bypasses media volume and mute switch). If staging fails, silent CAF is used as fallback (engine must succeed). `soundName ?? "Default Alarm"` ensures a valid sound name is always available.

---

### Issue 4 — `resolveSoundURL()` Used Wrong Bundle Path

**File:** `AlarmSchedulerIOS26AlarmKit.swift` — `resolveSoundURL()`  
**Symptom:** `stageNotificationSound()` always returned `nil` for bundled sounds, making Issue 3's fallback path (AlarmKit with audible sound) non-functional.  
**Root Cause:** The bundle scan looked in `Bundle.main.bundleURL/sounds/` — a directory that does not exist in the compiled bundle. Bundled alarm tones live in `BundledSounds/ringtones/`.  
**Fix:** Replaced the broken path lookup with:
1. **Fast path:** `Bundle.main.url(forResource: rawBase, withExtension: ext)` using the original filename (with spaces) — not the normalized key.
2. **Full scan:** Enumerate entire `Bundle.main.bundleURL` to find resources in any subdirectory.

The normalized key was previously being passed to `Bundle.main.url(forResource:)`, which silently failed for files with spaces in their names (e.g., `"Default Alarm"` was normalized to `"defaultalarm"`, which doesn't match the actual filename).

---

### Issue 5 — `stageNotificationSound()` Returned nil When File Already Staged

**File:** `AlarmSchedulerIOS26AlarmKit.swift` — `stageNotificationSound()`  
**Symptom:** At alarm-fire time, even if the sound was successfully staged at schedule time (copied to `Library/Sounds/`), the function returned `nil` because `resolveSoundURL()` was called first and failed.  
**Root Cause:** The function's first line was `guard let sourceURL = resolveSoundURL(for: rawName) else { return nil }`. This guard ran before checking whether the staged file already existed.  
**Fix:** Reordered the function to check `Library/Sounds/` for an already-staged file **first** (checking `{base}_alarmkit.m4a` and `{base}.{ext}` for all supported extensions). If found, returns immediately without needing the source URL. Only falls through to source URL resolution if staging hasn't happened yet.

---

### Issue 6 — `startFadeIn()` Bailed on Zero Media Volume

**File:** `AlarmContinuousAudioEngine.swift` — `startFadeIn()`  
**Symptom:** After 2+ hours of idle phone, media output volume is often 0 (user had media volume at minimum, separate from ringer volume). The engine bailed pre-emptively.  
**Root Cause:**
```swift
if appState != .active && activatedOutput <= 0.01 {
    AlarmAudioStateController.shared.recordFallback(reason: "locked-zero-output-at-fadein")
    return
}
```
This called `recordFallback()` which then tried to schedule an audible AlarmKit respawn — but because of Issues 3 and 4, that respawn was also silent. Net result: complete silence.  
**Fix:** Removed the hard bail. Engine now proceeds to `p.play()`. The existing 200ms confirmation check handles actual play failures. With Issue 3 fixed (AlarmKit always audible), the alarm rings even if the engine can't produce media audio.

---

### Issue 7 — Volume Observer Caused 2-Second Gap on Volume Press

**File:** `AlarmContinuousAudioEngine.swift` — `startVolumeObserver()`  
**Symptom:** When the user pressed the volume-down button during an active alarm, the alarm sound would briefly disappear for ~2 seconds before resuming.  
**Root Cause:** The volume observer fired on any drop below 0.15, calling `recordFallback()`. This transitions phase to `.alarmKitFallback`, which cancels the live AlarmKit alarm and schedules a new one with a 2-second delay via `scheduleHardwareButtonRespawnIfNeeded()`.  
**Fix:** Added a phase check before calling `recordFallback()`:
- In `.appEngineFadingIn` or `.appEnginePrimary` phases: only set `player.volume = 1.0`. No respawn triggered. AlarmKit is already playing (fix from Issue 3), so no backup is needed.
- In other phases: original behavior (trigger respawn as safety net).

---

### Issue 8 — Snooze Killed Alarm Permanently

**File:** `AlarmRingCoordinator.swift` — `snooze()`  
**Symptom:** Pressing Snooze appeared to kill the alarm completely. No sound and no UI appeared after the snooze interval.  
**Root Cause:** `stopRingingInternal()` (called during snooze) calls `markAlarmFlowCompleted(alarmId:)`, which adds the alarm ID to `completedAlarmFlowIds` set. This set is checked by `processAlarmKitAlertingAlarm()` via `isAlarmFlowSuppressed()`. The time-based suppression window expires after 12 seconds, but `alarmFlowPhaseBySource[alarmId]` remains `.completed` until `clearCompletedAlarmFlow()` is called. For the locked-phone path (AlarmKit fires the snooze alarm), the coordinator's `startRinging()` is not called — so `clearCompletedAlarmFlow()` was never called, and the snooze alarm could be suppressed.  
**Fix:** Added an explicit `clearCompletedAlarmFlow(alarmId:)` call in `snooze()` immediately after `stopRingingInternal()`. This ensures the snooze alarm fires cleanly through the AlarmKit notification path.

---

### Issue 9 — Volume and Gentle Wake-Up Settings Ignored

**Files:** `AlarmAudioStateController.swift`, `AlarmRingCoordinator.swift`  
**Symptom:** Alarm always started at full volume (1.0) with an 8-second fade regardless of the per-alarm settings for volume level and gentle wake-up duration.  
**Root Cause:** `requestAppEngineTakeoverIfAllowed()` always called:
```swift
AlarmContinuousAudioEngine.shared.startFadeIn(
    alarmRunId: alarmRunId,
    fadeInDuration: Self.appEngineFadeInDuration,   // always 8.0
    targetVolume: Self.appEngineFinalTargetVolume   // always 1.0
)
```
And `AlarmRingCoordinator.startRinging()` always passed `volume: 1.0` to `engine.start()`.  
**Fix:**
- In `requestAppEngineTakeoverIfAllowed()`: reads `alarm.soundVolume` and `alarm.gentleWakeUpSeconds` from `AlarmStore.shared` using `currentAlarmId`. Passes them to `startFadeIn()`.
- In `startRinging()` and `reassertRingingAudio()`: uses `alarm.soundVolume > 0 ? alarm.soundVolume : 1.0` instead of hardcoded `1.0`.

---

### Issue 10 — Speaker Override `Code=-50` Error Spam

**File:** `AlarmContinuousAudioEngine.swift` — `enforceBuiltInSpeakerOutput()`  
**Symptom:** Log showed repeated `overrideOutputAudioPort failed Code=-50` followed by `CRITICAL: Could not enforce speaker after 3 attempts`. This was a false alarm — not a real speaker failure.  
**Root Cause:** `Code=-50` means "audio session not active." The route change observer fires during the `prepareSilently` window, which calls `configureSessionCategoryOnly()` (sets category but does **not** call `setActive(true)`). When `enforceBuiltInSpeakerOutput()` is called on an inactive session, it always fails with `-50`.  
**Fix:** Added early exit for `Code=-50` specifically: logs a single "session not active yet" message and returns without retrying. The override is correctly re-applied later when `startFadeIn()` calls `setActive(true)`.

---

### Issue 11 — `SoundCatalogRepository` Loaded 0 Bundled Sounds

**File:** `SoundConfig.swift`  
**Symptom:** Log showed `[SoundCatalogRepository] Loaded 0 sounds` with 8 "WARNING: Could not find sound" messages on every launch. Bundled alarm tones did not appear in the sound picker for new users.  
**Root Cause:** `SoundConfig.sounds` listed 8 cloud-only MP3 files (`Addams Family.mp3`, `Alan Jackson Remix.mp3`, etc.) that are downloaded on demand and **not** included in the app bundle. The actual bundled `.caf` files were not listed in `SoundConfig` at all.  
**Fix:** Replaced the 8 cloud-only MP3 entries with the 5 actual bundled `.caf` files:
```
Default Alarm.caf, Clock Alarm.caf, Cockpit Alert.caf, Alarm.caf, bbc_electronic.caf
```
Cloud sounds continue to appear via `loadRemoteSoundsFromCatalog()` when downloaded — that path was already working correctly and is unaffected.

---

### Issue 12 — Phase Sync: Engine Started 3 Seconds Behind AlarmKit

**File:** `AlarmContinuousAudioEngine.swift` — `startFadeIn()`  
**Symptom:** After the engine faded in, the user heard a slight echo or chorus effect — the same alarm melody at two different time positions simultaneously.  
**Root Cause:** AlarmKit starts playing its sound at T=0. The engine starts 3 seconds later (after the settle delay) but begins the track at position 0. For those 3–8 seconds during fade-in, both AlarmKit and the engine play the same track 3 seconds apart in phase.  
**Fix:** After `p.play()` succeeds in `startFadeIn()`, seek the engine player to match AlarmKit's current position:
```swift
if let alertingAt = AlarmAudioStateController.shared.alarmKitAlertingReceivedAt,
   p.duration > 0 {
    let elapsed = Date().timeIntervalSince(alertingAt)
    let syncPos = elapsed.truncatingRemainder(dividingBy: p.duration)
    if syncPos > 0 { p.currentTime = syncPos }
}
```
`alarmKitAlertingReceivedAt` is `nil` for foreground-timer alarms, so the sync only runs for AlarmKit-fired alarms. Both audio sources now play the same position in the track.

---

### Issue 13 — Slide-to-Stop Looping Badge (Zombie Respawn Loop)

**File:** `AlarmSchedulerIOS26AlarmKit.swift` — `StopAlarmIntent`  
**Symptom:** Each time the user swiped slide-to-stop on the lock screen, the AlarmKit badge disappeared and reappeared ~1 second later. Sound restarted from the beginning each time. User had to keep pressing slide-to-stop in a loop with no way to dismiss.  
**Root Cause:** A previous fix removed the early returns from `StopAlarmIntent.perform()`, causing it to **always** schedule a zombie respawn AlarmKit alarm (1s delay) regardless of engine health. Each respawn called `handleAlarmKitAlerting()`, which (when not in a primary phase) called `prepareSilently()` — stopping the existing player and creating a new one, restarting the sound from the beginning.  
**Fix:**
1. Restored the `engineHealthy = true` early return.
2. Restored the `!respawnAppropriate` early return.
3. Changed `openAppWhenRun = false` → `true` (see Issue 14).

The zombie respawn now only fires for `respawnAppropriate = true` (engine confirmed failed in a phase where failure is a genuine error). Delay kept at 1.0s instead of the original 4.0s.

---

### Issue 14 — No Unlock Prompt on Slide-to-Stop

**File:** `AlarmSchedulerIOS26AlarmKit.swift` — `StopAlarmIntent`  
**Symptom:** After slide-to-stop with engine healthy, users had no clear way to unlock the phone and dismiss the alarm. A notification was sent ("tap to open Awayk") but many users missed it or didn't understand its purpose.  
**Root Cause:** `openAppWhenRun = false` meant the intent ran silently in the background. iOS never prompted for Face ID or passcode. Users saw the badge go away (or reappear) with no authentication prompt.  
**Fix:** Changed `static var openAppWhenRun: Bool = false` to `true`. Now:
- When user presses slide-to-stop, iOS **immediately** shows Face ID / passcode prompt
- User authenticates → app opens → `perform()` runs with app active
- `shouldUseLockedHandling = false` → no zombie respawn
- `alarmKitCustomUIHandoffRequested` posted → full-screen alarm UI shown
- Engine has been playing the entire time (never stopped)

Face ID behavior on device face-down or unrecognized: iOS automatically falls back to passcode entry after a failed Face ID attempt. This is standard iOS behavior.

---

## 5. Files Changed

| File | Changes |
|---|---|
| `AlarmContinuousAudioEngine.swift` | `findFallbackSound()` priority list; removed zero-volume bail in `startFadeIn()`; volume observer phase-aware (no respawn when primary); phase sync seek in `startFadeIn()`; Code=-50 silent handling in `enforceBuiltInSpeakerOutput()`; floor calls use `selectedSoundVolume` instead of hardcoded constant |
| `AlarmSchedulerIOS26AlarmKit.swift` | `makeConfiguration()` always uses audible sound; `resolveSoundURL()` full bundle scan with correct fast path; `stageNotificationSound()` checks staged file before source URL; `StopAlarmIntent.openAppWhenRun = true`; restored early returns for healthy/settling paths; respawn delay 4.0s → 1.0s |
| `SoundPickerView.swift` | `deleteDownloadedSound()` helper resets affected alarms to "Default Alarm"; `commitDelete()` same for custom sounds |
| `AlarmAudioStateController.swift` | `requestAppEngineTakeoverIfAllowed()` uses `alarm.gentleWakeUpSeconds` for fade duration, player always 1.0; added `selectedSoundVolume` property set from alarm in `beginAlarmSession()`; floor called with `selectedSoundVolume`; constants raised 0.25 → 0.70 |
| `AlarmRingCoordinator.swift` | `snooze()` calls `clearCompletedAlarmFlow()` after `stopRingingInternal()`; `startRinging()` and `reassertRingingAudio()` always pass `volume: 1.0` to engine |
| `AlarmRingingView.swift` | `onAppear` floor uses `alarm.soundVolume`; `systemVolumeDidChange` handler re-enforces floor on every volume change (Alarmy behavior) |
| `SystemOutputVolumeFloorManager.swift` | `minimumAttemptInterval` reduced 10.0s → 1.5s |
| `SoundConfig.swift` | Replaced 8 cloud-only MP3 entries with 5 actual bundled `.caf` filenames |
| `AlarmSchedulingCore.swift` | `pendingRequest()`: added 24h hard ceiling + future-timestamp guard; added `pruneWithAlarmStore(_:runtimeIsActive:appIsForeground:)` for store-aware startup cleanup |
| `NotificationManager.swift` | `configure()`: added `pruneWithAlarmStore` call after fallback chain cleanup and before recovery/observation |
| `AlarmContinuousAudioEngine.swift` (vol observer) | Removed `else { recordFallback }` from volume observer — non-primary phases no longer trigger stop+respawn on volume change |
| `AlarmSchedulerIOS26AlarmKit.swift` (StopAlarmIntent) | Badge tap in foreground with ring UI active is now a no-op — returns immediately when `!shouldUseLockedHandling && isAlarmRinging` |

---

## 6. Expected Behavior After Fixes

### Alarm fires on time (phone locked overnight)
1. AlarmKit badge appears on lock screen
2. Alarm sound plays immediately (ringer domain — bypasses mute and media volume)
3. After ~3 seconds, app engine fades in, synchronized to AlarmKit's playback position
4. Both sources play in phase — no echo, no double audio sensation
5. Sound loops continuously

### User presses slide-to-stop
1. iOS immediately shows Face ID prompt (or passcode if face not detected)
2. Engine continues playing in background throughout authentication
3. User authenticates → phone unlocks → app opens
4. Full-screen alarm UI shown with Stop and Snooze buttons
5. AlarmKit badge does NOT reappear
6. Sound continues playing until user presses Stop or Snooze

### User presses volume-down during alarm
- If phone is locked: side buttons affect ringer volume (AlarmKit domain). iOS enforces a minimum alarm volume at the OS level.
- If phone is unlocked (app foreground): volume observer prevents engine player volume from dropping below a floor. Player volume is set to 1.0 if system volume drops below 0.15.

### User presses Snooze
1. Sound stops immediately
2. Alarm is rescheduled for `now + snoozeInterval` (configured per alarm in settings)
3. After the snooze interval: alarm rings again with same sound
4. Works correctly even if phone is locked during the snooze period (AlarmKit fires the snooze alarm)

### User presses Stop in the in-app UI
1. Engine stops
2. All AlarmKit surfaces cancelled
3. All unlock notifications cancelled
4. For repeating alarms: rescheduled for next occurrence
5. For one-shot alarms: disabled

### Sound picker — cloud sound deleted
- All alarms referencing the deleted sound name are automatically reset to "Default Alarm"
- Alarm settings view reflects the change
- Next alarm ring uses "Default Alarm.caf" as configured

### Sound catalog
- 5 bundled sounds always visible in sound picker (no download required)
- Cloud sounds appear when downloaded
- No "Loaded 0 sounds" warnings on launch

---

## 7. Known Limitations

### Face ID Must Be Available
`openAppWhenRun = true` relies on iOS's standard authentication flow. If the phone has no passcode set, the app opens immediately (no authentication). If Face ID fails and passcode is disabled, the intent might not complete and the app won't open — the engine will continue playing in the background but no UI will be shown until the user manually opens the app.

### Media Volume vs Ringer Volume
The app engine uses the media audio domain (`.playback` category). If the user has media volume at 0 when the alarm fires:
- AlarmKit ringer is still audible (ringer domain, unaffected by media volume)
- After slide-to-stop + unlock, the app engine is playing but may be inaudible until the user raises media volume
- The full-screen alarm UI is shown; the user can then adjust volume or press Stop/Snooze

### Gentle Wake-Up Only Applies to Engine Fade-In
AlarmKit's configured sound (ringer domain) always plays at full ringer volume from T=0. The gentle wake-up fade applies only to the engine's portion (starting at T=3s). This matches how Alarmy works — the ringer domain does not support volume ramping.

### Zombie Respawn Still Active for Failed Engine
If the engine completely fails to start (play() returns false, session activation error), `StopAlarmIntent` still schedules a zombie respawn AlarmKit alarm at +1.0s as a safety net. In this scenario the badge reappears once. This is intentional — it ensures the user is not left with complete silence and no way to interact.

### AlarmKit Sound Duration Limit (29.5 Seconds)
AlarmKit enforces a maximum sound duration of 29.5 seconds. For sounds longer than this, `stageNotificationSound()` exports a trimmed 29.5-second version for the AlarmKit ringer. The engine plays the full-length version. After 29.5 seconds the ringer loops the trimmed file; the engine plays through the full track.

---

### Issue 15 — Alarm Volume Too Low; User Settings Not Applied to System Volume

**Date added:** 2026-05-30 (volume control base fix) / updated same day (real-time enforcement)  
**Files:** `AlarmAudioStateController.swift`, `AlarmContinuousAudioEngine.swift`, `AlarmRingCoordinator.swift`, `AlarmRingingView.swift`, `SystemOutputVolumeFloorManager.swift`

**Symptom (initial):** Alarm played at ~20% of maximum volume even when the user configured 80% in alarm settings. Log confirmed: `ENGINE_VOL=0.80`, `OUTPUT_VOL=0.25`, effective = 0.80 × 0.25 = 0.20. 

**Symptom (follow-up):** After the base fix, user observed that rapidly pressing volume-down could still reduce the alarm to `outputVolume=0.00` (complete silence for ~2–5 seconds before the floor recovered). The volume should never drop below the user's configured level regardless of how fast the buttons are pressed.

**Root Cause (3 stacked problems):**

1. **Player volume set to `alarm.soundVolume` (wrong).** `AlarmRingCoordinator` and `AlarmAudioStateController` were passing `alarm.soundVolume` (e.g. 0.80) as the engine player's volume. Because effective output = `playerVolume × systemOutputVolume`, setting player to 0.80 with system at 0.25 gave only 0.20. Player should always be 1.0 to maximise headroom; the user's volume setting should control the **system floor**, not the player gain.

2. **Volume floor constants were 0.25 (too low).** `preAlarmMinimumOutputVolume` and `postSlideMinimumOutputVolume` were hardcoded to 0.25. `SystemOutputVolumeFloorManager` saw system volume = 0.25 → "already meets floor" → took no action. The floor needed to match the user's `alarm.soundVolume`.

3. **Rate limit of 10 seconds was too slow.** `SystemOutputVolumeFloorManager.minimumAttemptInterval = 10.0` meant the manager could only respond to volume-down presses once per 10 seconds. For real-time "volume goes back up" behavior, this needed to be ~1.5 seconds.

**How Alarmy achieves the "volume goes back up" effect:**
Alarmy keeps the alarm UI in the foreground (`openAppWhenRun = true`, same as our app). Their ringing view has a hidden `MPVolumeView` slider in the hierarchy and observes `AVAudioSession.outputVolume` via KVO. When volume drops, they immediately set the slider value to their target floor. iOS receives the slider action, raises system volume, and shows the standard volume HUD going up. This ONLY works from the foreground — from background/locked state `MPVolumeView` is silently ignored.

**Root cause of follow-up (3 more bugs):**

1. **Volume observer threshold was `0.15`** — misses all drops from 1.00 → 0.85 → 0.55 → 0.25. The observer only triggered enforcement at 0.10, 0.05, 0.00 by which point the alarm was already inaudible.

2. **Volume observer only set `player.volume = 1.0`** — which was already 1.0. It never called `SystemOutputVolumeFloorManager` to raise the system output volume. In `appEnginePrimary` phase, raising `player.volume` does nothing because the bottleneck is `outputVolume = 0.00`.

3. **`AlarmRingingView.systemVolumeDidChange` was rate-limited to 1.5s** — user rapidly pressing volume-down 5 times in 1 second triggered enforcement once (first press), then 4 presses went unresponded. Volume reached 0.00 before the 1.5s window expired.

**Fix (8 changes total — 5 base + 3 follow-up):**

*Base fixes (player volume formula):*

1. **`AlarmAudioStateController.swift`**: Added `private(set) var selectedSoundVolume: Float = 1.0` property, set from `alarm.soundVolume` in `beginAlarmSession`. Raised `preAlarmMinimumOutputVolume` and `postSlideMinimumOutputVolume` from `0.25` → `0.70`. In `requestAppEngineTakeoverIfAllowed`: removed the `targetVolume = alarm.soundVolume` override (player stays at 1.0), added an explicit floor call with `selectedSoundVolume` after `startFadeIn`.

2. **`AlarmContinuousAudioEngine.swift`**: Both floor calls in `prepareSilently()` and `startFadeIn()` now use `AlarmAudioStateController.shared.selectedSoundVolume` instead of the hardcoded `preAlarmMinimumOutputVolume` constant.

3. **`AlarmRingCoordinator.swift`**: Both `engine.start(volume:)` call sites changed from `alarm.soundVolume > 0 ? alarm.soundVolume : 1.0` → `1.0`. Player always at maximum; system floor handles the user's volume preference.

4. **`AlarmRingingView.swift`**: `onAppear` floor call now uses `ringCoordinator.activeAlarm.soundVolume` (clamped 0.01–1.0) instead of the hardcoded constant.

5. **`SystemOutputVolumeFloorManager.swift`**: `minimumAttemptInterval` reduced from `10.0` → `1.5` seconds.

*Follow-up fixes (real-time per-button-press enforcement):*

6. **`SystemOutputVolumeFloorManager.swift`**: Added `enforceFloorImmediately(minimumVolume:)` method that bypasses all rate limiting — finds the `MPVolumeView` slider and sets it immediately. Used for interactive enforcement (volume button presses) where the 1.5s rate limit is unacceptable.

7. **`AlarmContinuousAudioEngine.swift` — `startVolumeObserver()`**: Changed threshold from `0.15` to `AlarmAudioStateController.shared.selectedSoundVolume` (e.g., 0.80). Now enforcement fires as soon as volume drops below the alarm's configured level, not just below 0.15. In `appEnginePrimary`/`appEngineFadingIn` phase, now calls `enforceFloorImmediately()` via `Task { @MainActor in }` to immediately raise system output — not just player volume.

8. **`AlarmRingingView.swift` — `systemVolumeDidChange`**: Switched from `attemptRaiseOutputVolumeFloor` (rate-limited) to `enforceFloorImmediately` (immediate). Every single volume-button press while the ringing UI is visible now triggers an immediate floor raise.

**Volume formula after fix:**
```
player.volume = 1.0  (always)
system.outputVolume = raised to ≥ alarm.soundVolume immediately on any drop
effective output = 1.0 × alarm.soundVolume = alarm.soundVolume   ← correct, maintained continuously
```

**Expected behavior after fix:**
- User presses volume-down during alarm (app foreground) → system volume instantly returns to `alarm.soundVolume`
- iOS shows volume HUD going back up (same as Alarmy)
- Rapid successive button presses are each individually countered
- Volume can never drop below the user's configured alarm volume while alarm UI is visible

**Background limitation (unchanged):** From background/locked state, `MPVolumeView` cannot raise system volume (no key window). AlarmKit ringer domain handles the initial audio from lock screen (from Issue 3 fix). Once the user unlocks via slide-to-stop + Face ID (Issue 14 fix), the app is foreground and volume floor enforcement activates immediately.

---

### Issue 16 — Stale Handoff State Caused Ghost Ring / "Awayk" Notification Until Reinstall

**Date added:** 2026-05-31  
**Files:** `AlarmSchedulingCore.swift`, `NotificationManager.swift`

**Symptom:** After an alarm session ended (user stopped the alarm), some users saw the "Awayk" custom alarm UI or notification appear unexpectedly on subsequent app opens — sometimes hours or days later. Deleting and reinstalling the app fixed the behavior, which is the hallmark of stale `UserDefaults` state surviving across launches.

**Root Cause:**

`AlarmCustomUIHandoffStore` persists three scalar keys in `UserDefaults` (the "pending request"):

```
alarmo.alarmKit.pendingCustomUISourceAlarmId
alarmo.alarmKit.pendingCustomUISurfaceAlarmId
alarmo.alarmKit.pendingCustomUITimestamp
```

And a multi-entry map:
```
alarmo.alarmKit.surfaceSourceMap  (JSON: [surfaceUUID → sourceUUID + timestamp])
```

**The ghost-ring path:** `AppRootView.handlePendingCustomAlarmUIHandoff()` is called on every app launch and foreground transition (lines 97, 189, 308). It reads `pendingRequest()` **directly** (line 408) and calls `ringCoordinator.startRinging(alarmId: pending.sourceAlarmID)` (line 452) using `pending.sourceAlarmID` — not via the map. So if stale pending state exists from a previous alarm session:

- One-shot deleted alarm → source alarm no longer in AlarmStore → `startRinging` returns false (alarm not found). Low harm but noisy.  
- **Recurring alarm that still exists** → source alarm IS in AlarmStore → `startRinging` succeeds → ghost ring UI starts, alarm sounds, UI shows Stop/Snooze with no real alarm firing. This is the dangerous case.

Three gaps allowed stale state to survive:

1. **`pendingRequest()` had no time expiry.** The comment explicitly said "Lifecycle-based: no time expiry." A pending request written during last week's alarm stayed valid until `clear()` was explicitly called (Stop/Snooze path) or until 48 hours passed via `pruneOrphanedMappings()`. If the app crashed mid-ring, `clear()` was never called and the stale pending survived indefinitely (up to 48h).

2. **`pruneOrphanedMappings()` was time-only (48h) and ran before `AlarmStore` was available.** It ran in `AwaykApp.init()` before SwiftData was loaded, so it could not check whether source alarm IDs still existed. Stale entries for deleted one-off alarms could survive up to 48 hours.

3. **No store-aware cleanup at configure time.** `NotificationManager.configure()` (the first point where `AlarmStore` is available) performed no handoff state cleanup. Stale state for deleted alarms, or stale pending for existing recurring alarms, was never removed with store knowledge.

**Why "source-exists" alone is not proof a pending is valid:**  
A recurring daily alarm fired at 7am yesterday, was stopped by the user, and `clear()` was called. But if the app crashed between writing the pending request and calling `clear()`, yesterday's pending (sourceAlarmID = daily alarm UUID) survives with the alarm still present in AlarmStore. This satisfies "source exists" yet is completely stale.

**Fix (2 files only):**

**`AlarmSchedulingCore.swift` — Change A: 24h hard ceiling in `pendingRequest()`**

Replaced the "no expiry" comment and added:
```swift
let age = now.timeIntervalSince1970 - timestamp
guard age >= 0, age < 24 * 60 * 60 else {
    // future-timestamp (clock change) or hard-expiry
    clear()
    return nil
}
```
- `age >= 0` rejects future-dated timestamps from device clock changes, which would otherwise make the age appear negative and keep stale state alive forever.
- 24h ceiling: NOT 2h or 10min. A healthy locked alarm may never refresh the pending timestamp — the `engineLiveHealthy` path in `processAlarmKitAlertingAlarm` (NotificationManager.swift line ~1719) returns early **without** calling `request()`. A 2h TTL would clear a real live alarm; 24h is far beyond any realistic ringing session.

**`AlarmSchedulingCore.swift` — Change B: new `pruneWithAlarmStore(_:runtimeIsActive:appIsForeground:)`**

Store-aware cleanup run once at startup after AlarmStore is loaded. Pending scalar key cleanup rules (in order):

| Condition | Reason logged | Action |
|---|---|---|
| `timestamp <= 0` | `invalid-timestamp` | `clear()` |
| `age < 0` (future-dated) | `future-timestamp` | `clear()` |
| `age >= 24h` | `hard-expiry` | `clear()` |
| source alarm not in AlarmStore AND `age >= 30m` | `missing-source` | `clear()` |
| source alarm exists AND `age >= 6h` AND NOT runtime-active AND foreground launch | `inactive-existing-source` | `clear()` |

The `inactive-existing-source` threshold is **6 hours, not 60 minutes**. A real long-ringing alarm (1–3h) could have `runtimeIsActive == false` at `configure()` time because observation/recovery runs AFTER configure. 6h eliminates this risk while still catching the hours-to-days-old stale state from a prior session. The `appIsForeground` guard (`applicationState != .background`) prevents the aggressive clear during a background alarm-recovery relaunch.

Surface map cleanup: entries < 60m kept unconditionally (protects active alarms and snooze chains); entries > 48h removed (safety net); entries 60m–48h removed if source alarm no longer exists in AlarmStore.

**`NotificationManager.swift` — one call in `configure()`**

Inserted after `cancelAllAlarmRingingFallbackChains()` and before `drainPendingAlarmStarts()` / `startAlarmKitObservation()`:
```swift
let runtimeIsActive =
    ringCoordinator.isRinging ||
    AlarmBackgroundAudioBridge.shared.currentAlarmID != nil ||
    AlarmContinuousAudioEngine.shared.isEngineActive ||
    AlarmAudioStateController.shared.phase != .stopped
let appIsForeground = UIApplication.shared.applicationState != .background
AlarmCustomUIHandoffStore.pruneWithAlarmStore(
    alarmStore,
    runtimeIsActive: runtimeIsActive,
    appIsForeground: appIsForeground
)
```

`phase != .stopped` covers transitional states (`waitingForAlarmKit`, `alarmKitSettling`, `appEnginePreparing`, `appEngineFadingIn`, `alarmKitFallback`) that the other three signals might miss. Running before observation ensures stale pending state cannot route through `handlePendingCustomAlarmUIHandoff` (called next, line 97 of AppRootView).

**What is NOT changed:**

- `engine.wasPlaying` / `engine.currentAlarmId` / `engine.currentSoundName` / `engine.persistedAt` — already have a 1h TTL in `recoverIfNeeded()` (AlarmContinuousAudioEngine.swift:276). Clearing them would break real alarm recovery. Untouched.
- `pruneOrphanedMappings()` at `AwaykApp.init()` — kept as the conservative 48h pre-AlarmStore first pass.
- `cancelAllAlarmRingingFallbackChains()` — already prefix-scoped to `"alarmo-ring-fallback-*"`. No global notification wipe added.
- `clear()` — already removes the 3 scalar keys correctly. No changes.
- StopAlarmIntent, snooze, bridge, engine, notification categories — all untouched.

**Protected behaviors verified:**

- **Cold relaunch into active alarm (background):** `appIsForeground == false` → `inactive-existing-source` clear cannot fire. Only `invalid`/`future`/`hard-expiry`/`missing-source` rules apply — none match a seconds-old live alarm. ✓
- **Foreground launch while real alarm has been ringing 1–3h:** 6h threshold means the pending (e.g. 2h old) is NOT cleared. ✓
- **Multi-snooze chain:** map entries < 60m kept unconditionally throughout. ✓
- **Slide-to-stop:** runtime signals active → no aggressive clear; engine/AlarmKit state untouched. ✓
- **Volume enforcement (Issue 15/16):** entirely independent layers; unaffected. ✓

---

### Issue 17 — Side Button Press Stopped Sound (Volume Observer Regression)

**Date added:** 2026-05-31  
**Files:** `AlarmContinuousAudioEngine.swift`

**Symptom:** When the user pressed the side or volume button while the alarm was ringing (phone locked or transitioning to background), the sound would stop for ~2 seconds and then resume. Slide-to-stop was unaffected — that path correctly kept audio playing. The issue was specific to volume-button interaction in the locked/background state.

**Root Cause:**

The Issue 15 volume floor fix changed the volume observer threshold from `0.15` to `selectedSoundVolume` (e.g. 0.80). The observer has two branches:

- `appEnginePrimary`/`appEngineFadingIn`: calls `enforceFloorImmediately` — correct, raises system volume
- `else` (all other phases): called `recordFallback(reason:)` — **this is where the regression was**

In `alarmKitFallback`, `alarmKitSettling`, or `waitingForAlarmKit` phases, AlarmKit's **ringer domain** is the audio source. The ringer domain is completely immune to media volume — pressing the volume button changes the user's media volume but does NOT silence the AlarmKit ringer. However, the old `else` branch called `recordFallback` whenever media volume dropped below `selectedSoundVolume` in these phases.

`recordFallback` → `scheduleHardwareButtonRespawnIfNeeded` → stops all alerting AlarmKit surfaces → schedules respawn at +2s → **2-second silence**.

Before Issue 15, the threshold was `0.15`. A volume drop from 0.90 to 0.70 would not cross 0.15 and would not trigger `recordFallback`. After Issue 15, the same drop (0.90 → 0.79 < 0.80) would trigger it.

**Fix:**

Removed the `else { recordFallback }` branch from the volume observer entirely. When phase is not `appEnginePrimary`/`appEngineFadingIn`, the observer now logs the volume drop and returns without calling `recordFallback`. The ringer domain audio is unaffected by media volume changes, so no respawn is needed. The engine's own watchdog and bridge handle genuine audio failures.

---

### Issue 18 — AlarmKit Badge Tap Stopped Sound When Phone Was Unlocked

**Date added:** 2026-05-31  
**Files:** `AlarmSchedulerIOS26AlarmKit.swift`

**Symptom:** When the phone was unlocked and the alarm was ringing in foreground (custom ring UI visible), a small AlarmKit banner/badge appeared at the top of the screen. Tapping the badge stopped the alarm sound. Sound should only stop when the user presses the in-app Stop button.

**Root Cause:**

When the badge is tapped, `StopAlarmIntent.perform()` runs. With the app in foreground:
```swift
let shouldUseLockedHandling = state != .active || !UIApplication.shared.isProtectedDataAvailable
// → false when app is active and protected data available
```

`shouldUseLockedHandling = false` → the intent falls through to the **unlocked-device fallback path**, which:
1. Calls `scheduleAlarmKitUnlockPrompt` (suppressed when active — no-op)
2. Calls `startAlarmKitUnlockPromptLoop` (suppressed when active — no-op)
3. Posts `alarmKitCustomUIHandoffRequested`

Step 3 triggers `handlePendingCustomAlarmUIHandoff` → `startRinging` (already ringing, duplicate path) → `engine.start()` (no-op if playing). This alone should not stop sound.

However, AlarmKit itself **stops its own alarm surface** as part of executing the intent, silencing the ringer-domain audio. If the media engine is also briefly unhealthy at the tap moment (e.g., the badge tap caused a scene state transition), the combined loss of both audio sources produces complete silence. Additionally, the unlocked path's side effects (writing new pending request, posting handoff notification) can interfere with an already-healthy ringing session.

**Fix:**

Added an early return at the start of `StopAlarmIntent.perform()`: if `shouldUseLockedHandling == false` AND `AlarmAudioStateController.shared.isAlarmRinging == true`, the intent returns immediately without any side effects. The in-app ring UI is already showing with Stop/Snooze buttons — the badge tap does nothing. AlarmKit may still stop its own ringer surface (system behavior outside our control), but the engine (media domain) is not touched.

```swift
if !shouldUseLockedHandling && AlarmAudioStateController.shared.isAlarmRinging {
    // Badge tap with ring UI active — no-op
    return .result()
}
```

---

*This document covers all alarm sound reliability work completed on the `sound-fix-issue` branch.*  
*All issues were verified working on device after implementation.*
