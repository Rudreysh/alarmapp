# Awayk — Alarm Sound Feature Requirements Document

**Document Type:** Product Requirements Document (PRD)  
**Feature:** Alarm Sound — Persistent Ring Engine  
**Version:** 1.0  
**Status:** Approved For Implementation  
**Last Updated:** 2026-05-27

---

## 1. Purpose and Scope

This document defines the complete behavioral requirements for the Awayk alarm sound system. It covers how sound starts, how it persists, what can and cannot stop it, how it recovers from system interruptions, and what fallback behavior exists when the primary audio path fails.

The scope includes:
- Sound playback start and stop conditions
- Behavior across all phone states (locked, unlocked, foreground, background)
- Behavior across all user actions (side button, volume buttons, notifications, slide-to-stop)
- Fallback and recovery behavior
- Custom UI interaction requirements

This document does **not** cover alarm scheduling, mission configuration, or report generation.

---

## 2. The Core Requirement

> **The alarm sound must play continuously from the moment the alarm fires until the user explicitly presses the Stop button inside the Awayk custom ringing UI. No other action, button press, system event, or phone state change may stop the sound.**

This single requirement supersedes all other considerations. Every design decision in this document exists to protect and enforce this requirement.

---

## 3. Definitions

| Term | Definition |
|------|-----------|
| **Alarm fire time** | The scheduled time when the alarm is supposed to ring |
| **Ring session** | The active period from alarm fire to user-initiated stop or snooze |
| **App engine** | The `AlarmContinuousAudioEngine` — the primary audio player inside the app |
| **AlarmKit surface** | The iOS system alarm UI shown on the lock screen |
| **Custom ringing UI** | The full-screen in-app screen with Stop and Snooze buttons |
| **Slide-to-stop** | The iOS system gesture on the AlarmKit lock screen surface |
| **Side button** | The physical sleep/wake button on the right side of iPhone |
| **Volume buttons** | The two physical buttons on the left side of iPhone |
| **Silent mode** | State when the ring/silent toggle switch is set to silent (orange line visible) |
| **Snooze** | User action that temporarily stops the alarm and reschedules it |
| **Stop** | User action that permanently ends the current alarm ring session |
| **Fallback sound** | A default alarm sound bundled inside the app that plays when the selected sound is unavailable |

---

## 4. Sound Start Requirements

### 4.1 When Sound Must Start

Sound must start automatically when the alarm fire time is reached under ALL of the following conditions:

- Phone is locked and screen is off
- Phone is locked and screen is on (notification received)
- App is in the foreground (user has Awayk open)
- App is in the background (user has another app open)
- App was terminated (force-quit) before alarm fire time
- Phone was restarted after alarm was scheduled
- Phone is in Airplane Mode
- Phone is in Do Not Disturb mode
- Phone is in Focus mode (any Focus mode)
- Phone has no network connection
- Phone storage is critically low

### 4.2 Sound Must Play In Silent Mode

The silent mode toggle switch on the iPhone controls ringtones and notification sounds. It does **not** control alarm sounds.

**Requirement:** The Awayk alarm sound must play at full volume regardless of the position of the ring/silent toggle switch.

**Implementation:** The `AVAudioSession` category must be set to `.playback`. This category is explicitly designed to bypass the silent switch. The category must be confirmed active before `player.play()` is called.

### 4.3 Sound Must Play Regardless of System Volume

**Requirement:** The alarm must produce audible sound even if the user has set their system media volume to zero.

**Implementation:** The alarm uses the alarm/ringer volume domain, not the media volume domain. `overrideOutputAudioPort(.speaker)` must be called after `setActive(true)` to ensure correct routing. If system output volume is detected at 0, the app must trigger the AlarmKit audible fallback which uses the alarm volume domain independently.

### 4.4 Sound Must Play Through the Built-In Speaker

**Requirement:** Alarm sound must play through the iPhone's built-in speaker regardless of what audio output device is connected.

**Implementation:** `overrideOutputAudioPort(.speaker)` must be called unconditionally at the start of every ring session. This overrides AirPods, Bluetooth speakers, wired headphones, and any other connected output.

**Exception:** If the user is on an active phone call, the alarm must still play. Sound routes to speaker regardless of call audio routing.

### 4.5 Fade-In Behavior

To avoid startling the user, sound must not start at full volume.

**Requirement:**
- Sound starts at 15% volume
- Sound ramps up to 100% volume over 8 seconds using `AVAudioPlayer.setVolume(_:fadeDuration:)`
- After the 8-second ramp, sound stays at 100% until stopped
- Fade-in must work when app is backgrounded (native `AVAudioPlayer` fade is background-safe)

**Why native fade:** Manual step-loop fades via `DispatchQueue.asyncAfter` are unreliable when the app is background-throttled. The native `AVAudioPlayer.setVolume(_:fadeDuration:)` runs in AVFoundation's audio thread and survives background state.

---

## 5. Sound Persistence Requirements

### 5.1 The Inviolable Rule

**Sound must keep playing when any of the following occur:**

| User Action | Sound Behavior |
|-------------|---------------|
| Side button pressed (locks phone) | Continues playing |
| Side button pressed again (wakes screen) | Continues playing |
| Volume down button pressed | Continues playing (may reduce volume, see 5.2) |
| Volume up button pressed | Continues playing |
| Slide-to-stop gesture on AlarmKit lock screen | Continues playing |
| Notification received from another app | Continues playing |
| Phone call received and answered | Continues playing |
| Phone call ends | Continues playing |
| User switches to another app | Continues playing |
| User pulls down notification center | Continues playing |
| App is backgrounded by any means | Continues playing |
| Screen auto-locks (auto-lock timer) | Continues playing |
| AlarmKit surface dismissed or disappears | Continues playing |
| AlarmKit surface replaced by new surface | Continues playing |
| Custom ringing UI disappears (view lifecycle) | Continues playing |

### 5.2 Volume Button Behavior During Ringing

**Requirement:** Volume buttons during a ring session must NOT reduce alarm volume to a level where the alarm cannot be heard.

**Implementation options (choose one):**
- Option A: Intercept volume button events and show a "Alarm volume cannot be muted" toast
- Option B: Monitor `outputVolume` during ring session and if it drops below 0.1, trigger AlarmKit audible fallback
- **Recommended:** Option B — less intrusive, still protects the user

**If volume drops to 0 during ring session:**
1. Engine detects `outputVolume <= 0.01`
2. Engine immediately triggers AlarmKit audible fallback (uses alarm volume domain)
3. AlarmKit audible fallback rings independently of media volume
4. Engine continues attempting to play as media volume recovers

### 5.3 Slide-To-Stop Must NOT Stop Sound

**This is a critical requirement.** The iOS AlarmKit lock screen surface has a "Slide to stop" gesture. When this gesture is performed:

- The AlarmKit surface is dismissed
- iOS fires `StopAlarmIntent`
- **The Awayk sound must continue playing**

**Required behavior:**
1. `StopAlarmIntent` fires
2. App detects intent
3. App checks: is engine healthy and primary?
4. If yes → apply `applyPostStopGentleRamp()` (brief volume drop then ramp back to full)
5. Schedule a new AlarmKit surface to restore the lock screen UI
6. Sound never actually stops
7. New AlarmKit surface appears with Stop/Snooze buttons
8. OR: App triggers push notification with Stop/Snooze actions

**Why allow gentle ramp:** The brief volume dip (to 15% then back to 100%) signals to the user that their gesture was registered while the alarm stays active. Without this, the alarm feels unresponsive.

### 5.4 Sound Must Survive App Background Throttling

iOS may throttle background apps, causing `DispatchQueue.asyncAfter` timers to fire late or not at all.

**Implementation requirements:**
- Use `AVAudioPlayer` in `.playback` category session — this keeps audio alive in background
- Background task `alarmo.ringCoordinator.ringing` must be active during ring session
- When background task expires, immediately request a new background task — never let both tasks expire simultaneously
- `AlarmBackgroundAudioBridge` must maintain audio session continuity across app state transitions
- If audio session is interrupted (by another app taking exclusive audio), recover within 0.5 seconds

---

## 6. Sound Stop Requirements

### 6.1 Only One Thing Stops The Sound

**The sound stops permanently if and only if:**

> The user taps the **Stop** button in the Awayk custom ringing UI AND completes the mission (if a mission is enabled).

Nothing else stops the sound permanently.

### 6.2 Snooze Is Not Stop

When the user taps Snooze:
- Sound stops temporarily
- Ringing UI dismisses
- Alarm is rescheduled for: current time + snooze duration (default 9 minutes)
- At snooze fire time, the full ring sequence starts again from the beginning (including fade-in)
- This loop continues until the user presses Stop

### 6.3 The Stop Button Flow

**Without mission:**
```
User taps Stop button
→ Engine.stop(reason: "user-stop")
→ AlarmAudioStateController.recordStopped(reason: "user-stop")
→ All AlarmKit surfaces dismissed
→ All pending backup alarms cancelled
→ Ringing UI dismisses
→ App returns to alarm list
→ Alarm reschedules for next occurrence (next day if repeating)
```

**With mission enabled:**
```
User taps Stop button
→ Mission screen appears (overlays ringing UI)
→ Sound continues playing during mission
→ User completes mission correctly
→ Engine.stop(reason: "user-stop-mission-complete")
→ AlarmAudioStateController.recordStopped(reason: "user-stop-mission-complete")
→ Same cleanup as without mission
```

**Mission failed:**
```
User taps Stop button
→ Mission screen appears
→ User answers incorrectly
→ Sound continues playing
→ New mission appears
→ Repeat until correct
```

**There is no way to dismiss the mission screen without completing it correctly or pressing Snooze.**

### 6.4 What Must NEVER Stop The Sound

| Trigger | Correct Behavior |
|---------|-----------------|
| `StopAlarmIntent` from lock screen slide | Sound continues (see 5.3) |
| `StopAlarmIntent` from notification action | Sound continues — UI opens instead |
| App enters background | Sound continues |
| App is backgrounded by system | Sound continues |
| Background task expires | Sound continues (new task starts) |
| AlarmKit surface cancelled | Sound continues |
| `AlarmRingingView.onDisappear` | Sound continues |
| View lifecycle events | Sound continues |
| Scene phase changes | Sound continues |
| `protectedDataAvailable` event | Sound continues |
| Watchdog timer fires | Sound continues (watchdog may attempt restart but must not stop) |
| Bridge watchdog fires | Sound continues |
| Any automatic code path | Sound continues |

---

## 7. Phone State Behavior

### 7.1 Phone Locked — Screen Off (Primary Use Case)

This is the most common scenario — user is asleep.

**Expected flow:**
```
Alarm fire time arrives
→ AlarmKit fires → lock screen shows system alarm UI
→ App engine prepares sound silently (volume = 0, session not activated)
→ 4.5 second settle delay (AlarmKit establishes session)
→ App engine activates session, overrides to speaker, starts fade-in
→ Sound ramps 15% → 100% over 8 seconds
→ App engine is primary — sound continues indefinitely
→ Lock screen: AlarmKit surface with Stop/Snooze options visible
→ User wakes, sees lock screen alarm UI, hears sound
→ User presses Stop on lock screen → StopAlarmIntent fires → sound CONTINUES
→ New notification appears: "Tap to open Awayk to stop your alarm"
→ User unlocks phone → Awayk opens to custom ringing UI
→ User presses Stop in custom UI → alarm ends
```

### 7.2 Phone Locked — User Presses Side Button

The side button wakes the screen or locks it.

**Expected behavior:**
- Sound continues playing regardless
- If screen wakes: lock screen shows AlarmKit surface
- If screen locks: sound continues in background
- If user presses side button multiple times rapidly: sound continues every time

### 7.3 Phone Unlocked — App In Foreground

**Expected flow:**
```
Alarm fire time arrives
→ Foreground scheduler detects alarm
→ AlarmKit fires (adds resilience — happens simultaneously)
→ App engine starts immediately (no settle delay needed)
→ Custom ringing UI fills the screen
→ Sound plays at full volume from speaker
→ User sees Stop and Snooze buttons directly
→ No lock screen UI involved
→ User presses Stop → mission → alarm ends
```

### 7.4 Phone Unlocked — App In Background

**Expected flow:**
```
Alarm fire time arrives
→ AlarmKit fires → system notification appears
→ App is brought to foreground by AlarmKit
→ Custom ringing UI fills the screen
→ Same as 7.3 from this point
```

### 7.5 Phone Unlocked — User Locks Phone During Ring

```
Custom ringing UI is showing, sound is playing
User presses side button → phone locks
→ Custom ringing UI disappears (app backgrounds)
→ Sound continues playing via background audio session
→ Lock screen shows AlarmKit surface
→ User can still Stop/Snooze from lock screen (triggers flow in 5.3)
→ Unlocking phone returns to custom ringing UI
→ Sound was playing the entire time
```

---

## 8. Notification Behavior

### 8.1 When App Is Active — No Notification Needed

When the custom ringing UI is visible and the app is in the foreground, no notification or AlarmKit banner should appear. The user has direct access to Stop and Snooze buttons.

**Requirement:** Suppress all AlarmKit banners and notification prompts when:
- App is active (`UIApplication.applicationState == .active`)
- Engine is primary (`phase == .appEnginePrimary`)

### 8.1.1 Unlocked Banner/Badge Dismissal Must Not Stop Alarm

When the phone is unlocked and any alarm-related banner, badge, or in-app top notification UI is dismissed (manually or automatically), the alarm sound must continue ringing.

**Requirement:**
- Dismissing or swiping away a banner/badge must never call any stop path.
- Sound may stop only via:
  - Custom full-screen **Stop** (per section 6.1)
  - Custom full-screen **Snooze** (temporary stop, per section 6.2)

**Explicit non-stop rule:** Closing notification UI is a visual action only. It must not alter ring session ownership or terminate audio.

### 8.2 After Slide-To-Stop — Recovery Notification

When the user slides to stop on the lock screen (which must not stop sound):

**Requirement:** A custom local notification must appear within 1 second showing:

```
App Icon + "Awayk"          Time

☀️ Good afternoon
Alarm is still ringing — open Awayk to stop.

[ Snooze ]  [ Stop ]
```

**Behavior of notification buttons:**
- **Stop** button: opens Awayk, sound stops only after Stop is confirmed in custom UI
- **Snooze** button: snoozes alarm, sound stops temporarily, reschedules

**Note:** The Stop button in the notification is for convenience navigation only. The actual sound stop happens inside the custom UI, not in the notification handler.

### 8.3 When Phone Is Locked During Ring

When the phone is locked while alarm is ringing, the lock screen must show the AlarmKit surface at all times during the ring session.

If the AlarmKit surface is dismissed (by any means), a new one must be scheduled within 2 seconds.

**Why:** The user must always have a visible indication that the alarm is ringing and must always have access to Stop and Snooze options even on the lock screen.

---

## 9. Fallback Sound Requirements

### 9.1 The Fallback Chain

When the user's selected alarm sound cannot be played, the engine must fall through a chain of alternatives. The chain must always terminate with an audible sound.

```
Level 1: User's selected sound (e.g. "Free Soul Gayatri Mantra.caf")
  ↓ (if file not found or corrupt)
Level 2: Previously downloaded sounds in Application Support/Assets
  ↓ (if none available)
Level 3: BundledSounds/ringtones/ folder in app bundle
  ↓ (if empty or missing)
Level 4: App bundle-wide scan for any audio file > 10,000 bytes that is not the silent file
  ↓ (if nothing found)
Level 5: AlarmKit audible fallback (triggers phase = .alarmKitFallback, uses system alarm sound)
```

**Level 5 must never be reached under normal circumstances.** Level 3 exists specifically to prevent Level 5. The app bundle MUST ship with at least one audible alarm sound in `BundledSounds/ringtones/`.

### 9.2 The Mandatory Default Sound

**Requirement:** The app bundle must include a file at:
```
BundledSounds/ringtones/Default Alarm.caf
```

This file:
- Must be a valid CAF audio file
- Must be at minimum 30 seconds in duration
- Must be at minimum 50,000 bytes in size
- Must not be the silent alarmo_silence.caf
- Must play at an audible volume appropriate for waking a sleeping person
- Must loop cleanly (no gap between loop end and loop start)

This file is the emergency fallback for all cases where the user's selected sound cannot be played. It ships inside the .ipa and is never deleted.

### 9.3 Fallback Trigger Conditions

The fallback chain is entered automatically when any of the following occur:

- `findSoundURL(for: alarm.soundName)` returns nil
- Audio file size is less than 1,000 bytes
- `prepareToPlay()` returns false
- `player.play()` returns false
- `currentTime` does not advance after 2 seconds (file corrupt/unreadable)
- App engine throws an audio session exception

### 9.4 AlarmKit Audible Fallback

When the app engine fails completely (Level 5), the system falls back to AlarmKit playing an audible sound.

**Requirement:** When `phase == .alarmKitFallback`, all AlarmKit alarms must be scheduled with an audible sound (not alarmo_silence.caf).

**The staged fallback sound** is resolved by the same fallback chain, staged into `Library/Sounds/` so AlarmKit can access it. If staging fails (storage full), the system alarm tone is used.

---

## 10. Recovery Requirements

### 10.1 Engine Failure Mid-Ring Recovery

If the app engine fails while the alarm is already ringing (audio session interrupted, player crashes):

**Required sequence:**
```
Engine fails → phase transitions to .alarmKitFallback
→ If previous phase was .appEnginePrimary or .appEngineFadingIn:
   → AlarmKit surface was already dismissed (engine was primary)
   → Must immediately schedule new audible AlarmKit surface
   → New surface rings audibly within 2 seconds of engine failure
→ If previous phase was .appEnginePreparing or .alarmKitSettling:
   → AlarmKit still owns audio — no new surface needed
   → Wait for backup chain to provide audible fallback
→ Engine attempts recovery: retry ladder [0.5s, 1.0s, 2.0s, 4.0s]
→ If engine recovers → dismiss AlarmKit surface → resume app engine
→ If engine does not recover in 30 seconds → stay in fallback
```

### 10.2 Audio Session Interruption Recovery

When another app takes the audio session (phone call received, Siri, etc.):

**Required sequence:**
```
Interruption begins (.began) → pause player (do not stop)
Interruption ends (.ended with shouldResume = true)
   → Reactivate session
   → Resume player within 0.4 seconds
   → Log: "Audio session recovered after interruption"
Interruption ends (.ended with shouldResume = false)
   → Wait 0.5 seconds
   → Force reactivate session
   → Resume player
   → Log: "Audio session force-recovered"
If resume fails at any point → record fallback → AlarmKit audible
```

### 10.3 Phone Restart Recovery

If the phone is restarted after an alarm is scheduled:

**Required sequence:**
```
Phone boots
iOS delivers AlarmKit alarm at scheduled time (AlarmKit survives reboots)
App launched by system when alarm fires
App detects alarm should be ringing on launch
App engine starts within 5 seconds of app launch
If app not launched within 5 seconds → AlarmKit audible fallback rings
Custom ringing UI shown when app becomes active
```

**Implementation note:** AlarmKit is designed to survive device reboots. The silent .caf approach means the device may boot and receive an AlarmKit alert playing silence. The app MUST be able to launch and take over audio within the settle window.

### 10.4 Mapping Lost Recovery

If the alarm UUID mapping is lost (reinstall, corruption):

**Required sequence:**
```
AlarmKit fires with surface UUID
Source alarm lookup returns nil (mapping missing)
Do NOT skip engine start
Instead:
   → Extract sound name from AlarmKit alarm metadata if available
   → OR use AlarmSettingsStore.defaultSoundName
   → OR fall through to fallback chain
   → Start engine with recovered sound
   → Re-establish mapping using surface UUID as source UUID
   → Continue ring session normally
```

---

## 11. State Machine Requirements

### 11.1 Valid Phases and Their Meaning

| Phase | Meaning | Audio State |
|-------|---------|-------------|
| `stopped` | No alarm active | Silent |
| `waitingForAlarmKit` | Session started, AlarmKit not yet fired | Silent (intentional) |
| `alarmKitSettling` | AlarmKit fired, stabilization window | Silent (intentional) |
| `appEnginePreparing` | Engine loading sound silently | Silent (intentional) |
| `appEngineFadingIn` | Engine ramping from 0 to 100% | Quiet → Loud |
| `appEnginePrimary` | Engine at full volume, confirmed primary | Full volume |
| `alarmKitFallback` | Engine failed, AlarmKit owns audio | AlarmKit playing |

### 11.2 Silence During Settling Is Intentional

During `waitingForAlarmKit`, `alarmKitSettling`, and `appEnginePreparing`, the app engine is intentionally silent. This is NOT a failure state.

**All watchdogs must be phase-aware.** Any watchdog that treats silence as a failure during these phases will create the crash-loop behavior (repeated AlarmKit surface spawning, SpringBoard crash, black screen).

**Rule:** A watchdog may only treat silence as a failure when phase is `appEngineFadingIn`, `appEnginePrimary`, or `alarmKitFallback`.

### 11.3 Phase Transition Guards

The following transitions are allowed:

```
stopped → waitingForAlarmKit (new alarm session begins)
stopped → alarmKitSettling (AlarmKit fires before coordinator)
waitingForAlarmKit → alarmKitSettling (AlarmKit alerting received)
waitingForAlarmKit → appEnginePreparing (foreground timer path)
waitingForAlarmKit → stopped (cancelled)
alarmKitSettling → appEnginePreparing (engine prepared)
alarmKitSettling → appEngineFadingIn (early takeover)
alarmKitSettling → appEnginePrimary (direct primary)
alarmKitSettling → alarmKitFallback (fallback)
alarmKitSettling → stopped (cancelled)
appEnginePreparing → appEngineFadingIn (takeover proceeds)
appEnginePreparing → alarmKitFallback (fallback)
appEnginePreparing → stopped (cancelled)
appEngineFadingIn → appEnginePrimary (ramp complete)
appEngineFadingIn → alarmKitFallback (fallback)
appEngineFadingIn → stopped (user action only)
appEnginePrimary → alarmKitFallback (engine failure)
appEnginePrimary → stopped (user action only — Stop button)
alarmKitFallback → appEnginePreparing (engine recovery attempt)
alarmKitFallback → stopped (user action only — Stop button)
```

**Critical rule:** `appEnginePrimary → stopped` and `appEngineFadingIn → stopped` transitions may ONLY occur when triggered by user-initiated Stop action. They must never occur automatically.

---

## 12. Specific Non-Requirements (Things The App Must NOT Do)

These represent behaviors that must be explicitly prevented:

```
❌ Auto-stop after any time duration
❌ Auto-snooze after any time duration
❌ Stop when background task expires
❌ Stop when AlarmKit surface is dismissed
❌ Stop when StopAlarmIntent fires (unless triggered from custom UI)
❌ Stop when phone locks
❌ Stop when app enters background
❌ Stop when scene phase changes
❌ Stop when protectedDataAvailable fires
❌ Stop when volume drops to 0
❌ Stop when silent mode is active
❌ Stop from any watchdog path
❌ Stop from any bridge recovery path
❌ Stop due to duplicate AlarmKit surfaces
❌ Stop because custom ringing view disappears
❌ Stop because another alarm fires
❌ Stop automatically for any reason whatsoever
```

---

## 13. Diagnostic and Self-Monitoring Requirements

### 13.1 At Alarm Schedule Time

When the user saves an alarm, the app must run a silent diagnostic and display warnings:

| Check | Warning Shown If |
|-------|-----------------|
| Sound file exists | File not found or too small |
| Phone volume | Below 30% |
| Background App Refresh | Disabled |
| Notification permission | Not granted |
| Available storage | Below 100MB |

Warnings are informational — they do not prevent saving the alarm.

### 13.2 At Ring Time

The engine must log the following at every ring session start:

```
[Engine] Ring session started
  alarmId: {uuid}
  soundName: {name}
  soundFound: {true/false}
  fallbackUsed: {true/false}
  fallbackLevel: {1-5 or nil}
  outputVolume: {0.0-1.0}
  audioRoute: {Speaker/Headphones/Bluetooth}
  silentMode: {cannot detect — omit}
  appState: {active/inactive/background}
  phase: {current phase}
  backgroundTaskActive: {true/false}
```

### 13.3 Telemetry Events

The following events must be tracked for quality monitoring:

| Event | Tracked Fields |
|-------|---------------|
| `alarm_fired` | alarmId, timestamp, soundName, appState |
| `engine_started` | alarmId, soundFound, fallbackLevel, outputVolume |
| `engine_failed` | alarmId, reason, phase, recovery |
| `user_stopped` | alarmId, timeToStop (seconds from fire to stop) |
| `user_snoozed` | alarmId, snoozeCount, snoozeDuration |
| `silent_alarm_detected` | alarmId, reason (critical — needs investigation) |

---

## 14. Testing Requirements

### 14.1 Manual Test Matrix

Before any release, all of the following scenarios must be tested on a real iPhone:

| # | Scenario | Expected | Pass/Fail |
|---|----------|----------|-----------|
| 1 | Alarm fires while phone locked | Audible sound via speaker | |
| 2 | Alarm fires with silent mode ON | Audible sound via speaker | |
| 3 | Alarm fires with volume at 0% | AlarmKit audible fallback plays | |
| 4 | Side button pressed during ring | Sound continues | |
| 5 | Volume down pressed during ring | Sound continues or recovers | |
| 6 | Slide-to-stop on lock screen | Sound continues, notification appears | |
| 7 | Tap Stop in notification | App opens, sound continues until custom UI Stop | |
| 8 | Tap Stop in custom UI | Sound stops, alarm cleaned up | |
| 9 | Tap Snooze | Sound stops, reschedules for +9 min | |
| 10 | Snooze fires again | Sound plays again from beginning | |
| 11 | AirPods connected during ring | Sound plays through phone speaker | |
| 12 | Phone call received during ring | Alarm continues after call ends | |
| 13 | App force-quit before alarm | Alarm fires via AlarmKit | |
| 14 | Phone restart before alarm | Alarm fires after reboot | |
| 15 | Selected sound file deleted | Fallback sound plays | |
| 16 | Phone locked after custom UI opens | Sound continues, lock screen shows surface | |
| 17 | Unlock after lock during ring | Custom UI re-appears, sound still playing | |
| 18 | Multiple alarms at same time | One rings, others don't crash | |
| 19 | App deleted and reinstalled | Next alarm fires with fallback sound | |
| 20 | Storage full scenario | System sound fallback plays | |
| 21 | Incremental Xcode app update without deleting app | Next alarm still rings audibly | |
| 22 | Clean build folder + reinstall + immediate alarm schedule | Alarm rings audibly without manual recovery | |
| 23 | Overnight alarm after daytime code update | Morning alarm rings audibly with lock-screen continuity | |
| 24 | Unlocked banner/badge dismissed while alarm active | Sound continues; no stop path triggered | |

### 14.2 Regression Tests After Code Changes

Any change to these files requires running the full test matrix before merging:

- `AlarmContinuousAudioEngine.swift`
- `AlarmAudioStateController.swift`
- `AlarmRingCoordinator.swift`
- `NotificationManager.swift`
- `AlarmBackgroundAudioBridge.swift`
- `AlarmRingingView.swift`
- `AppRootView.swift`

---

## 15. Known Edge Cases and Their Resolutions

### 15.1 StopAlarmIntent From Slide-To-Stop

**Edge case:** iOS fires `StopAlarmIntent` when user slides the lock screen alarm surface.

**Resolution:** `StopAlarmIntent` must NOT stop the app engine. Instead:
1. Detect intent
2. Apply brief volume dip and ramp (`applyPostStopGentleRamp`)
3. Schedule replacement AlarmKit surface (2 second delay)
4. Post local notification with "Tap to stop alarm" action
5. Return `.result()` without stopping engine

### 15.2 `AlarmRingingView` Lifecycle

**Edge case:** `AlarmRingingView.onDisappear` fires when phone locks, causing cleanup code to run.

**Resolution:** `onDisappear` must check the current phase before doing anything:
- If `phase == .appEnginePrimary` and alarm is still ringing → do NOT stop engine
- Only call `ensureLockPromptLoop` if `phase == .appEnginePrimary` (not during settling)
- Never call `engine.stop()` from `onDisappear` during an active ring session

### 15.3 Watchdog Firing During Settle Phase

**Edge case:** Bridge watchdog detects silence during settle phase and panics.

**Resolution:** All watchdogs must call `isSilenceExpected()` before treating silence as a failure. During `waitingForAlarmKit`, `alarmKitSettling`, and `appEnginePreparing`, silence is expected and watchdog failure counters must reset to 0.

### 15.4 Multiple AlarmKit Surfaces Blinking

**Edge case:** Backup chain schedules new surfaces while original surface is still active, causing rapid present/dismiss cycles that crash SpringBoard (black loading screen).

**Resolution:** `ensureBackupAlarmKitChain` must be gated by `shouldAllowAlarmKitRespawn()` which returns false during all settling phases and false when engine is primary.

### 15.5 Volume Domain Switch After Slide-To-Stop

**Edge case:** Before slide-to-stop, AlarmKit owns audio (ringer domain, loud). After, app engine owns (media domain, potentially quiet).

**Resolution:** `applyPostStopGentleRamp()` addresses the perceived loudness by ramping engine volume from 15% back to 100%. Additionally, `overrideOutputAudioPort(.speaker)` ensures consistent routing.

### 15.6 Short Audio Gap Tolerance During Ownership Transitions

**Edge case:** During side-button press, lock/unlock churn, slide-to-stop, or AlarmKit/app-engine ownership transitions, a short audible dip may occur.

**Requirement:**
- Audio continuity target: no audible gap greater than **1.0 second**.
- Stretch tolerance for extreme system contention: no audible gap greater than **2.0 seconds**.
- If continuity exceeds 2.0 seconds, the system must immediately trigger fallback recovery and log a critical reliability event.

**Pass criterion:** 95% of transition events remain <= 1.0 second gap, 100% remain <= 2.0 seconds.

---

## 16. Implementation Priority Order

### Priority 1 — Critical (Alarm May Be Silent)

1. Mapping lost recovery (reinstall, expiry)
2. Missed alerting event recovery (backup alarms use silent .caf)
3. Mapping lifecycle-based expiry (not time-based)
4. Volume 0 triggers AlarmKit audible fallback
5. Mandatory fallback sound in app bundle verified on launch

### Priority 2 — High (Alarm May Stop Prematurely)

6. StopAlarmIntent must not stop engine
7. `onDisappear` must not stop engine
8. Background task expiry must not stop engine
9. Watchdog phase-awareness (prevent panic during settling)
10. Engine failure mid-ring → AlarmKit surface recreation

### Priority 3 — Medium (Reliability)

11. Phone restart recovery (check for missed alarms on launch)
12. Concurrent alarm handling (first alarm wins)
13. Bridge failure triggers audible fallback
14. Speaker override verified after route changes
15. Storage full graceful degradation

### Priority 4 — Polish

16. Diagnostic warnings at alarm save time
17. Ring session telemetry
18. Volume escalation user preference
19. Notification design matching app theme
20. Automated test suite for all 20 manual scenarios

---

## 17. Success Criteria

The alarm sound feature is considered complete and correct when:

1. **Alarm always rings.** In 100 alarm fires across the test matrix, at least 98 produce audible sound within 5 seconds of the fire time.

2. **Sound never auto-stops.** In 50 ring sessions where the user does NOT press Stop, the sound plays continuously for at least 10 minutes without any interruption.

3. **Silent mode does not suppress alarm.** In 20 tests with silent mode ON, all 20 produce audible sound.

4. **Slide-to-stop does not stop alarm.** In 20 tests where the user slides to stop on the lock screen, all 20 alarms continue ringing.

5. **Stop button is the only stop.** In 20 tests using Stop button in custom UI, all 20 alarms stop cleanly. In 20 tests using any other method, all 20 alarms continue ringing.

6. **Snooze loop works.** In 10 tests with 3 consecutive snoozes, all 10 complete the full loop correctly and stop only when Stop is pressed.

7. **Update-path stability is reliable.** In 20 runs after incremental Xcode update (without app delete), all 20 alarms ring audibly at fire time.

8. **UI dismissal cannot stop sound.** In 20 unlocked sessions where alarm banners/badges are dismissed, all 20 continue ringing until custom UI Stop/Snooze.

9. **Continuity gap target is met.** Across 100 lock/unlock/slide transition events, 95+ are <= 1.0 second audible gap and 100 are <= 2.0 seconds.

---

*End of Document*

*This PRD is the authoritative specification for alarm sound behavior in Awayk. Any code change that contradicts this document is a bug.*
