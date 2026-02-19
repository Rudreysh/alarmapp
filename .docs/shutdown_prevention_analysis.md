# Device Shutdown & App Deletion Prevention - Technical Analysis

## Executive Summary

After thorough research, implementing complete prevention of device shutdown and app deletion on iOS has **significant technical limitations** due to Apple's security model. However, we can implement a **hybrid approach** that provides accountability features and user education.

## Technical Limitations

### 1. Preventing Device Shutdown

**Status: NOT POSSIBLE on standard iOS**

- **Apple's Restriction**: iOS does not provide any public API to prevent device shutdown
- **Security Reason**: This is a fundamental security feature to prevent malicious apps from locking users out
- **App Store Policy**: Apps attempting this would be rejected
- **Only Exception**: Enterprise MDM (Mobile Device Management) on supervised devices

**What IS Possible:**

- Prevent screen sleep/lock using `UIApplication.shared.isIdleTimerDisabled = true`
- Detect when app enters background (user might be trying to shut down)
- Show warnings and accountability measures

### 2. Preventing App Deletion

**Status: PARTIALLY POSSIBLE with Screen Time API**

**Option A: Screen Time API (FamilyControls)**

- **Requires**: Special entitlement from Apple (`com.apple.developer.family-controls`)
- **Use Case**: Designed for parental control apps
- **Limitation**: Requires parent/guardian authentication
- **Benefit**: Once authorized, the parental control app itself cannot be deleted without guardian approval
- **App Store Review**: Requires justification and approval from Apple

**Option B: User-Guided Screen Time Settings**

- Guide users to manually enable iOS Screen Time restrictions
- Path: Settings > Screen Time > Content & Privacy Restrictions > Deleting Apps > Don't Allow
- Requires user to set Screen Time passcode
- **Limitation**: User can disable this themselves

## Recommended Implementation Strategy

### Phase 1: Accountability Shield Enhancement (IMMEDIATE)

Instead of preventing shutdown/deletion (impossible), implement strong accountability:

1. **Shutdown Detection & Warning**
   - Detect app entering background
   - Show warning about accountability consequences
   - Log shutdown attempts
   - Trigger penalty if enabled

2. **App Deletion Warning**
   - Cannot prevent, but can warn during onboarding
   - Explain consequences of deletion
   - Backup data to iCloud for recovery

3. **Screen Time Integration Guide**
   - Provide in-app tutorial to enable Screen Time restrictions
   - Step-by-step guide with screenshots
   - Verify if restrictions are enabled (limited detection possible)

### Phase 2: Screen Time API Integration (FUTURE)

If you want true prevention, you'll need to:

1. **Apply for Family Controls Entitlement**
   - Submit request to Apple explaining use case
   - Justify why your alarm app needs parental control features
   - Wait for approval (can take weeks)

2. **Implement FamilyControls Framework**
   - Request authorization from user
   - Once authorized, app cannot be deleted without re-authentication
   - Can shield/block other apps during alarm time

3. **App Store Review**
   - Provide detailed explanation of feature
   - May face additional scrutiny

## Proposed UI Implementation (Phase 1)

### Location: Below "Time Zone Anchor" in Alarm Settings

```
┌─────────────────────────────────────┐
│ Accountability Shield               │
├─────────────────────────────────────┤
│ ⚡ Enable for this alarm       [ON] │
│                                     │
│ 🔒 Lock phone while ringing    [ON] │
│                                     │
│ 💰 Use penalty credits         [ON] │
│    Penalty Amount (€5)              │
│                                     │
│ 🚫 Shutdown Protection         [ON] │ ← NEW
│    Detect shutdown attempts         │
│    • Log all attempts               │
│    • Apply penalty if enabled       │
│    • Cannot physically prevent      │
│                                     │
│ 📱 App Protection Guide        [>]  │ ← NEW
│    Learn how to prevent deletion    │
└─────────────────────────────────────┘
```

## Implementation Details

### 1. Shutdown Detection

```swift
// Detect when app enters background
NotificationCenter.default.addObserver(
    forName: UIApplication.willResignActiveNotification,
    object: nil,
    queue: .main
) { _ in
    // User might be shutting down
    self.handlePotentialShutdown()
}

// Detect when device is about to sleep
NotificationCenter.default.addObserver(
    forName: UIApplication.willTerminateNotification,
    object: nil,
    queue: .main
) { _ in
    // App is being terminated (shutdown or force quit)
    self.logShutdownAttempt()
}
```

### 2. Keep Screen Awake During Alarm

```swift
// When alarm is ringing
UIApplication.shared.isIdleTimerDisabled = true

// When alarm is dismissed
UIApplication.shared.isIdleTimerDisabled = false
```

### 3. Shutdown Attempt Logging

```swift
struct ShutdownAttempt {
    let timestamp: Date
    let alarmId: UUID
    let wasRinging: Bool
}

// Store in UserDefaults or SwiftData
// Apply penalty if alarm was active
```

### 4. App Protection Guide View

```swift
struct AppProtectionGuideView: View {
    // Step-by-step tutorial
    // 1. Open Settings
    // 2. Go to Screen Time
    // 3. Enable restrictions
    // 4. Set passcode
    // 5. Disable app deletion
}
```

## Testing in Simulator

### What CAN Be Tested

✅ UI for shutdown protection toggle
✅ Background detection notifications
✅ Logging shutdown attempts
✅ Penalty application logic
✅ Warning messages and dialogs
✅ Screen Time guide UI
✅ Idle timer disable (screen stays on)

### What CANNOT Be Tested

❌ Actual prevention of shutdown (not possible)
❌ Actual prevention of app deletion (requires entitlement)
❌ Screen Time API (requires real device + entitlement)
❌ Physical power button blocking

## Recommended User Communication

### Honest Messaging

"**Shutdown Protection**
While iOS doesn't allow apps to prevent device shutdown, we can:
• Detect shutdown attempts and log them
• Apply accountability penalties if enabled
• Keep your screen awake during alarms
• Guide you to enable iOS restrictions

For maximum protection, follow our guide to enable Screen Time restrictions."

## Alternative: Guided Access

iOS has a built-in feature called "Guided Access" that can:

- Lock device to single app
- Disable hardware buttons
- Require passcode to exit

**Implementation**: Provide tutorial to enable Guided Access before sleep
**Limitation**: User must manually enable it each time

## Conclusion

**For Simulator Testing:**
I'll implement Phase 1 (Accountability Shield Enhancement) which includes:

1. UI toggle for "Shutdown Protection"
2. Background detection and logging
3. Warning dialogs
4. Penalty integration
5. App Protection Guide
6. Screen wake-lock during alarms

This provides a **realistic accountability system** that works within iOS limitations and can be fully tested in the simulator.

**For Production:**
Consider applying for Screen Time API entitlement if you want true prevention capabilities, but be prepared for:

- Lengthy approval process
- Stricter App Store review
- Need to justify parental control use case
