# Alarmo Alarm Scheduling Notes

## Why alarms behave differently when locked and in Silent mode
Alarm behavior depends on which Apple API path is available on the running iOS version.

- Foreground app audio uses `AVAudioSession` (`SoundPlayer`), which helps while Alarmo is open.
- On older iOS versions, Alarmo schedules alarms with local notifications (`UNUserNotificationCenter`).
- Local notifications are reminder-style delivery and do not always match native Clock-app alarm behavior under locked + Silent mode conditions.
- On iOS 26+, Alarmo uses AlarmKit for the system-alarm path when available.

This is why unlocked/foreground behavior can appear stronger than locked/silent behavior on older iOS.

## iOS 26+ AlarmKit support vs older iOS fallback
Alarmo uses a version-aware scheduler facade:

- `AlarmScheduler` protocol defines the common API.
- `AlarmSchedulerIOS26AlarmKit` is selected on iOS 26+ when AlarmKit is available.
- `AlarmSchedulerLegacyNotification` is the fallback for older iOS.
- `AlarmManagerFacade` selects the path at runtime and keeps app scheduling calls backward-compatible.

If AlarmKit scheduling fails at runtime, the facade falls back to notification scheduling and logs the reason.

## Physical iPhone testing
1. Install and run Alarmo on a physical iPhone.
2. Open `Settings -> Alarm Compatibility`.
3. Tap `Schedule Alarm In 1 Minute` and lock the device.
4. Repeat with Silent mode on/off and compare behavior.
5. For iOS 26+ devices, verify detected path shows `AlarmKit path`.
6. For older iOS devices, verify detected path shows `Legacy notification path` and the compatibility note is shown.

## Required Info.plist / capability notes
- Added generated Info.plist key:
  - `NSAlarmKitUsageDescription` (via build setting `INFOPLIST_KEY_NSAlarmKitUsageDescription`).
- Existing notification permissions are still required for legacy fallback.
- AlarmKit-specific capabilities/entitlements must be configured in Apple Developer settings when required by SDK/runtime.

## Older iOS platform limits
The following cannot be fully guaranteed on older iOS without AlarmKit or restricted entitlements:

- Guaranteed system-alarm style ringing while device is locked and in Silent mode.
- Full parity with Apple Clock app alarm behavior.

Alarmo handles this by using a clear fallback path and in-app compatibility messaging.
