p# Alarmo — Split Into 3 Standalone Apps: Full Implementation Plan

**Version:** 1.0  
**Status:** Implementation-Grade  
**Base Branch:** `green-theme-3e73` (read-only — never modified)  
**Date:** 2026-05-21

---

## Table of Contents

1. [Overview and Goals](#1-overview-and-goals)
2. [Prerequisites Checklist](#2-prerequisites-checklist)
3. [split/contracts.md Definition](#3-splitcontractsmd-definition)
4. [Git Setup — Phase 0](#4-git-setup--phase-0)
5. [Extension and Entitlement Audit — Phase 0b](#5-extension-and-entitlement-audit--phase-0b)
6. [Settings Key Audit — Phase 0c](#6-settings-key-audit--phase-0c)
7. [Foundation Branch Implementation — Phase 1](#7-foundation-branch-implementation--phase-1)
8. [CI Matrix Setup — Phase 1 Gate Prerequisite](#8-ci-matrix-setup--phase-1-gate-prerequisite)
9. [Foundation Gate Checklist](#9-foundation-gate-checklist)
10. [Alarm App Branch — Phase 2](#10-alarm-app-branch--phase-2)
11. [Habit App Branch — Phase 3](#11-habit-app-branch--phase-3)
12. [Overlap App Branch — Phase 4](#12-overlap-app-branch--phase-4)
13. [Data Migration Strategy](#13-data-migration-strategy)
14. [Verification Gates Summary](#14-verification-gates-summary)
15. [What Not To Do](#15-what-not-to-do)
16. [Execution Timeline](#16-execution-timeline)
17. [Troubleshooting Common Issues](#17-troubleshooting-common-issues)

---

## 1. Overview and Goals

### What Is Being Built

Three standalone iOS apps extracted from the single `Alarmo` codebase:

| App | Bundle ID | Features |
|-----|-----------|----------|
| **Alarmo** (Alarm) | `com.yourcompany.alarmo` | Alarm creation, ringing, missions, alarm settings, alarm reports |
| **Alarmo Habits** (Habit) | `com.yourcompany.alarmo.habits` | Habit tracking, timer/pomodoro, app blocking, habit settings, habit reports |
| **Alarmo Overlap** (Overlap) | `com.yourcompany.alarmo.overlap` | Overlap feature, minimal settings |

### Why The Split

- Each app can be submitted to the App Store independently
- Users who only want alarm functionality do not download habit/blocking code
- Each team/developer can work on one app without risk of breaking others
- App Review is scoped to only the features in each binary

### Core Constraint

> **The current `green-theme` branch is never modified under any circumstances.**
> All work happens exclusively in git worktrees on separate branches.
> The original project folder is read-only for the duration of this split.

### Dependency Between Phases

```
Phase 0 (Git Setup)
    ↓
Phase 0b (Extension Audit)
    ↓
Phase 0c (Settings Key Audit)
    ↓
Phase 1 (Foundation Branch)  ← ALL app branches depend on this
    ↓ [Foundation Gate must pass]
    ↓
Phase 2 (Alarm App)    Phase 3 (Habit App)    Phase 4 (Overlap App)
    ↓                       ↓                       ↓
[Alarm Gate]           [Habit Gate]           [Overlap Gate]
```

No phase begins until the previous gate passes. This is non-negotiable.

---

## 2. Prerequisites Checklist

Complete every item before writing a single line of code.

- [ ] Git version `>= 2.35` (required for worktree support): `git --version`
- [ ] Xcode version `>= 15.0`: `xcodebuild -version`
- [ ] Current branch is `green-theme`: `git branch --show-current`
- [ ] Zero uncommitted changes: `git status` shows clean
- [ ] Zero untracked files that matter: `git status` reviewed
- [ ] All local changes committed or stashed: `git stash list`
- [ ] Project builds successfully on current branch: `xcodebuild build -scheme Alarmo`
- [ ] All existing tests pass: `xcodebuild test -scheme Alarmo`
- [ ] Extension/entitlement audit completed (Section 5)
- [ ] Settings key audit completed and migration matrix built (Section 6)
- [ ] Extension ownership decisions documented and agreed (Section 5)
- [ ] App Group identifiers confirmed for each app
- [ ] Bundle IDs registered in Apple Developer Portal for all three apps
- [ ] Three App Store Connect app records created (or planned)
- [ ] `split/contracts.md` content reviewed and approved (Section 3)

---

## 3. split/contracts.md Definition

This file is committed to the `split/foundation-modularization` branch at the root of the repository. It defines the rules that all app branches must follow. Any violation is a build error or a code review block.

Create this file at the path: `split/contracts.md`

```markdown
# Alarmo Split Contracts

**Version:** 1.0  
**Enforced From:** split/foundation-modularization and all app branches

This document defines ownership, import rules, key namespaces, and domain
boundaries for the Alarmo three-app split. Violating these contracts causes
cross-feature leakage, data corruption, and App Store review risk.

---

## Module Ownership

| File / Directory | AlarmApp | HabitApp | OverlapApp | SharedCore |
|-----------------|----------|----------|------------|------------|
| AlarmContinuousAudioEngine.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmRingCoordinator.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmBackgroundAudioBridge.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmAudioStateController.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmSchedulerIOS26AlarmKit.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmSchedulerForeground.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmRingingView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmListView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmEditView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmMissionsView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmReportViewModel.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmSettingsStore.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmSettingsRootView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmMainView.swift | ✅ | ❌ | ❌ | ❌ |
| AlarmApp.swift | ✅ | ❌ | ❌ | ❌ |
| PlanView.swift / HabitView.swift | ❌ | ✅ | ❌ | ❌ |
| TimerView.swift / PomodoroView.swift | ❌ | ✅ | ❌ | ❌ |
| StopwatchView.swift | ❌ | ✅ | ❌ | ❌ |
| BlockingManager.swift | ❌ | ✅ | ❌ | ❌ |
| AccountabilityEnforcementManager.swift | ❌ | ✅ | ❌ | ❌ |
| AppListsView.swift | ❌ | ✅ | ❌ | ❌ |
| HabitReportViewModel.swift | ❌ | ✅ | ❌ | ❌ |
| HabitSettingsStore.swift | ❌ | ✅ | ❌ | ❌ |
| HabitSettingsRootView.swift | ❌ | ✅ | ❌ | ❌ |
| HabitMainView.swift | ❌ | ✅ | ❌ | ❌ |
| HabitApp.swift | ❌ | ✅ | ❌ | ❌ |
| OverlapView.swift | ❌ | ❌ | ✅ | ❌ |
| OverlapStore.swift | ❌ | ❌ | ✅ | ❌ |
| OverlapMainView.swift | ❌ | ❌ | ✅ | ❌ |
| OverlapApp.swift | ❌ | ❌ | ✅ | ❌ |
| AppTheme.swift | ✅ | ✅ | ✅ | ✅ |
| ThemeManager.swift | ✅ | ✅ | ✅ | ✅ |
| CommonSettingsStore.swift | ✅ | ✅ | ✅ | ✅ |
| AppFlavor.swift | ✅ | ✅ | ✅ | ✅ |
| SupportView.swift | ✅ | ✅ | ✅ | ✅ |
| LegalView.swift | ✅ | ✅ | ✅ | ✅ |
| AccountView.swift | ✅ | ✅ | ✅ | ✅ |

---

## Allowed Import Rules

Cross-feature imports are forbidden. A feature module must never import
another feature module directly.

| From \ To | AlarmFeature | HabitFeature | OverlapFeature | SharedCore |
|-----------|-------------|--------------|----------------|------------|
| AlarmFeature | ✅ self | ❌ FORBIDDEN | ❌ FORBIDDEN | ✅ allowed |
| HabitFeature | ❌ FORBIDDEN | ✅ self | ❌ FORBIDDEN | ✅ allowed |
| OverlapFeature | ❌ FORBIDDEN | ❌ FORBIDDEN | ✅ self | ✅ allowed |
| SharedCore | ❌ FORBIDDEN | ❌ FORBIDDEN | ❌ FORBIDDEN | ✅ self |

**Enforcement:** Use `grep -r "import AlarmFeature" HabitFeature/` in CI to
detect violations. Any cross-feature import is a build-blocking error.

---

## @AppStorage Key Namespace Rules

All UserDefaults / @AppStorage keys must use a feature prefix.
Unprefixed keys are legacy migration sources only — never write to them.

| Namespace | Owner | Example Keys |
|-----------|-------|--------------|
| `alarm.*` | AlarmApp only | `alarm.snoozeDuration`, `alarm.vibrationEnabled` |
| `habit.*` | HabitApp only | `habit.focusDuration`, `habit.blockingEnabled` |
| `overlap.*` | OverlapApp only | `overlap.lastViewedDate` |
| `common.*` | All apps | `common.appTheme`, `common.language` |
| (no prefix) | LEGACY READ-ONLY | Migration sources — never write |

**Rule:** No new key may be written without a prefix. PR review must check
for bare string keys in @AppStorage declarations.

---

## Report Domain Boundaries

| Domain | Owner | ActivityDomain value |
|--------|-------|---------------------|
| Alarm reports | AlarmApp only | `.alarm` |
| Habit reports | HabitApp only | `.habit` |
| Pomodoro/Focus reports | HabitApp only | `.pomodoro` |
| Overlap reports | OverlapApp only | `.overlap` (if applicable) |

**Rule:** AlarmReportViewModel must ONLY query ActivityDomain.alarm.
HabitReportViewModel must ONLY query ActivityDomain.habit and .pomodoro.
Cross-domain queries in a single app binary are a contract violation.

---

## Extension Ownership

| Extension Type | AlarmApp | HabitApp | OverlapApp |
|---------------|----------|----------|------------|
| Widget Extension | ✅ (alarm widgets) | ✅ (habit widgets) | ❌ |
| Notification Content Extension | ✅ | ❌ | ❌ |
| App Intents Extension (AlarmKit) | ✅ | ❌ | ❌ |
| Shield Extension (Screen Time) | ❌ | ✅ | ❌ |
| Share Extension | ❌ | ❌ | ❌ |

**Rule:** An extension target belongs to exactly one app. It must not be
added to multiple app targets.

---

## Contract Violation Detection

Run these checks in CI and on every PR:

```bash
# Check for cross-feature imports
grep -r "import AlarmFeature" HabitFeature/ && echo "VIOLATION: HabitFeature imports AlarmFeature"
grep -r "import HabitFeature" AlarmFeature/ && echo "VIOLATION: AlarmFeature imports HabitFeature"

# Check for unprefixed new keys (warn on any bare @AppStorage string)
grep -rn '@AppStorage("' --include="*.swift" | grep -v '"alarm\.' | grep -v '"habit\.' | grep -v '"overlap\.' | grep -v '"common\.' | grep -v 'migration'

# Check binary for cross-feature symbols (run after build)
nm build/AlarmoAlarm.app/AlarmoAlarm | grep -i "BlockingManager" && echo "VIOLATION: AlarmApp binary contains HabitFeature symbols"
nm build/AlarmoHabit.app/AlarmoHabit | grep -i "AlarmRingCoordinator" && echo "VIOLATION: HabitApp binary contains AlarmFeature symbols"
```
```

---

## 4. Git Setup — Phase 0

**Work location:** Current project folder (read-only after this section)  
**Time estimate:** 1 hour

### Step 4.1 — Verify Current State

```bash
# Confirm you are on green-theme
git branch --show-current
# Expected output: green-theme

# Confirm clean working tree
git status
# Expected output: nothing to commit, working tree clean

# If uncommitted changes exist, stash them
git stash push -m "pre-split stash $(date +%Y%m%d)"
```

### Step 4.2 — Create Base Snapshot Tag

```bash
# Tag the exact commit that all app branches will trace back to
git tag split-base-snapshot
git tag -l | grep split
# Expected output: split-base-snapshot

# Push tag to remote so it is preserved
git push origin split-base-snapshot
```

### Step 4.3 — Create Foundation Branch Only

```bash
# Create ONLY the foundation branch at this stage
# App branches are created AFTER foundation gate passes (Section 9)
git branch split/foundation-modularization

# Verify
git branch | grep split
# Expected output: split/foundation-modularization
```

### Step 4.4 — Create Worktree For Foundation

```bash
# Navigate to parent folder of your project
cd ..

# Confirm current folder name
ls
# Should show your project folder (e.g. alarmo)

# Create worktree in sibling folder
git -C alarmo worktree add ./alarmo-foundation split/foundation-modularization

# Verify worktrees
git -C alarmo worktree list
# Expected output:
# /path/to/alarmo           [commit hash] [green-theme]
# /path/to/alarmo-foundation [commit hash] [split/foundation-modularization]
```

### Step 4.5 — Verify Original Folder Is Untouched

```bash
cd alarmo
git branch --show-current
# Must output: green-theme — if not, STOP and fix before proceeding

git status
# Must output: nothing to commit, working tree clean
```

### Step 4.6 — App Branch Creation (Run ONLY After Foundation Gate)

> **DO NOT RUN THESE COMMANDS NOW.**  
> Run these only after the Foundation Gate checklist in Section 9 passes completely.

```bash
# Run from the alarmo-foundation worktree folder AFTER foundation gate passes
cd ../alarmo-foundation

# Create app branches from stable foundation
git branch split/alarm-app
git branch split/habit-app
git branch split/overlap-app

# Create worktrees for each app
cd ..
git -C alarmo worktree add ./alarmo-alarm-app   split/alarm-app
git -C alarmo worktree add ./alarmo-habit-app   split/habit-app
git -C alarmo worktree add ./alarmo-overlap-app split/overlap-app

# Verify all worktrees
git -C alarmo worktree list
# Expected: 5 entries (original + foundation + 3 app branches)
```

---

## 5. Extension and Entitlement Audit — Phase 0b

**This audit must be completed before Phase 1 begins.**  
**Work location:** `alarmo/` (original folder, read-only — audit only, no changes)

### Step 5.1 — List All Current Targets and Extensions

Open `alarmo.xcodeproj` in Xcode. Navigate to the project navigator.
Document every target currently in the project:

```
Current Targets (fill in from your project):
- [ ] Main app target: _______________
- [ ] Widget extension: _______________  (if exists)
- [ ] Notification content extension: _______________ (if exists)
- [ ] App intents extension: _______________ (if exists)
- [ ] Shield extension: _______________ (if exists)
- [ ] Other: _______________
```

### Step 5.2 — Extension Ownership Decision Table

Lock these decisions before Phase 1. Changes after branching are expensive.

| Extension Type | AlarmApp Target | HabitApp Target | OverlapApp Target | Decision Status |
|---------------|-----------------|-----------------|-------------------|-----------------|
| Widget Extension (alarm widgets) | ✅ Include | ❌ Exclude | ❌ Exclude | - [ ] Decided |
| Widget Extension (habit widgets) | ❌ Exclude | ✅ Include | ❌ Exclude | - [ ] Decided |
| Notification Content Extension | ✅ Include | ❌ Exclude | ❌ Exclude | - [ ] Decided |
| App Intents Extension (AlarmKit) | ✅ Include | ❌ Exclude | ❌ Exclude | - [ ] Decided |
| Shield Extension (Screen Time) | ❌ Exclude | ✅ Include | ❌ Exclude | - [ ] Decided |

### Step 5.3 — Entitlements Per App

Create three separate entitlements files in Phase 1.

**AlarmoAlarm.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- AlarmKit — required for alarm scheduling -->
    <key>com.apple.developer.usernotifications.time-sensitive</key>
    <true/>
    <!-- Background audio — required for engine playback -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>
    <!-- App Groups — required for engine AppGroup state sharing -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.alarmo</string>
    </array>
    <!-- Push notifications -->
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

**AlarmoHabit.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- FamilyControls — required for app blocking -->
    <key>com.apple.developer.family-controls</key>
    <true/>
    <!-- Background fetch — for habit reminders -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>
    <!-- App Groups — for Shield extension communication -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.alarmo.habits</string>
    </array>
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

**AlarmoOverlap.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Minimal — only what overlap actually uses -->
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

### Step 5.4 — App Groups Strategy

App Groups allow data sharing between app and extensions.

| App Group Identifier | Used By | Purpose |
|---------------------|---------|---------|
| `group.com.yourcompany.alarmo` | AlarmApp + Widget + Intents | Engine state, alarm data |
| `group.com.yourcompany.alarmo.habits` | HabitApp + Shield Extension | Blocking state, habit data |

> **Important:** App Group identifiers must be registered in Apple Developer Portal
> before building. They cannot be added retroactively to a submitted binary.

---

## 6. Settings Key Audit — Phase 0c

**This audit must be completed before writing any migration code.**

### Step 6.1 — Extract All Current Keys

```bash
# Run from the original alarmo/ folder
cd alarmo

# Extract all @AppStorage keys
grep -rn '@AppStorage' --include="*.swift" . | \
  grep -v "//.*@AppStorage" | \
  sort > /tmp/alarmo_settings_keys.txt

# Extract all UserDefaults keys
grep -rn 'UserDefaults' --include="*.swift" . | \
  grep -v "//.*UserDefaults" | \
  sort >> /tmp/alarmo_settings_keys.txt

# View the output
cat /tmp/alarmo_settings_keys.txt
```

### Step 6.2 — Migration Matrix Template

Fill this table from the output of Step 6.1.
**Every key must appear in this table before migration code is written.**

| Actual Key String (from code) | Swift Type | Default Value | Belongs To | New Namespaced Key |
|-------------------------------|-----------|---------------|------------|-------------------|
| *(fill from grep output)* | | | alarm/habit/common | alarm.xxx / habit.xxx / common.xxx |
| *(fill from grep output)* | | | | |
| *(fill from grep output)* | | | | |

### Step 6.3 — Migration Code Pattern

After the matrix is complete, implement migration using this pattern.
Replace sample key names with real keys from the matrix.

```swift
// AlarmSettingsMigration.swift
// Run once at first launch of AlarmApp

struct AlarmSettingsMigration {
    
    static let migrationKey = "alarm.settings.migration.v1.complete"
    
    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return  // Already migrated
        }
        
        migrateKeys()
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()
    }
    
    private static func migrateKeys() {
        let defaults = UserDefaults.standard
        
        // Pattern: read old unprefixed key, write to new namespaced key
        // Only migrate if old key exists AND new key does not yet have a value
        
        // Example — replace with real keys from your migration matrix:
        migrateInt(
            from: "YOUR_REAL_OLD_KEY_HERE",
            to: "alarm.YOUR_NEW_KEY_HERE",
            default: 9
        )
        
        migrateBool(
            from: "YOUR_REAL_OLD_BOOL_KEY_HERE",
            to: "alarm.YOUR_NEW_BOOL_KEY_HERE",
            default: true
        )
    }
    
    private static func migrateInt(from oldKey: String, to newKey: String, default defaultValue: Int) {
        guard UserDefaults.standard.object(forKey: oldKey) != nil else { return }
        guard UserDefaults.standard.object(forKey: newKey) == nil else { return }
        let value = UserDefaults.standard.integer(forKey: oldKey)
        UserDefaults.standard.set(value, forKey: newKey)
    }
    
    private static func migrateBool(from oldKey: String, to newKey: String, default defaultValue: Bool) {
        guard UserDefaults.standard.object(forKey: oldKey) != nil else { return }
        guard UserDefaults.standard.object(forKey: newKey) == nil else { return }
        let value = UserDefaults.standard.bool(forKey: oldKey)
        UserDefaults.standard.set(value, forKey: newKey)
    }
    
    private static func migrateString(from oldKey: String, to newKey: String, default defaultValue: String) {
        guard let value = UserDefaults.standard.string(forKey: oldKey) else { return }
        guard UserDefaults.standard.object(forKey: newKey) == nil else { return }
        UserDefaults.standard.set(value, forKey: newKey)
    }
}
```

### Step 6.4 — Migration Unit Test Pattern

```swift
// AlarmSettingsMigrationTests.swift

import XCTest
@testable import AlarmoAlarm

final class AlarmSettingsMigrationTests: XCTestCase {
    
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use in-memory test suite — never touches real UserDefaults
        testDefaults = UserDefaults(suiteName: "test.migration.\(UUID().uuidString)")
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.volatileDomain)
        super.tearDown()
    }
    
    func testMigrationRunsOnce() {
        // Set old key
        testDefaults.set(15, forKey: "YOUR_REAL_OLD_KEY_HERE")
        
        // Run migration
        AlarmSettingsMigration.runIfNeeded()
        
        // Verify new key has value
        XCTAssertEqual(testDefaults.integer(forKey: "alarm.YOUR_NEW_KEY_HERE"), 15)
        
        // Run again — should not overwrite
        testDefaults.set(99, forKey: "YOUR_REAL_OLD_KEY_HERE")
        AlarmSettingsMigration.runIfNeeded()
        
        // Value should still be 15, not 99
        XCTAssertEqual(testDefaults.integer(forKey: "alarm.YOUR_NEW_KEY_HERE"), 15)
    }
    
    func testMigrationSkipsWhenNewKeyAlreadySet() {
        // New key already has a value (user already on new version)
        testDefaults.set(7, forKey: "alarm.YOUR_NEW_KEY_HERE")
        
        // Old key has different value
        testDefaults.set(99, forKey: "YOUR_REAL_OLD_KEY_HERE")
        
        AlarmSettingsMigration.runIfNeeded()
        
        // New key must not be overwritten
        XCTAssertEqual(testDefaults.integer(forKey: "alarm.YOUR_NEW_KEY_HERE"), 7)
    }
    
    func testMigrationWithNoOldKey() {
        // No old key — first install of alarm app
        AlarmSettingsMigration.runIfNeeded()
        
        // New key should not exist (use default from @AppStorage declaration)
        XCTAssertNil(testDefaults.object(forKey: "alarm.YOUR_NEW_KEY_HERE"))
    }
}
```

---

## 7. Foundation Branch Implementation — Phase 1

**Work location:** `alarmo-foundation/` worktree  
**Branch:** `split/foundation-modularization`  
**Prerequisite:** Sections 4, 5, 6 complete

```bash
cd ../alarmo-foundation
# Confirm branch
git branch --show-current
# Expected: split/foundation-modularization
```

### Step 1.1 — AppFlavor.swift

Create `Shared/AppFlavor.swift`:

```swift
// AppFlavor.swift
// Identifies which app target is currently compiling.
// Set via Xcode build settings: Other Swift Flags

import Foundation

enum AppFlavor: String, CaseIterable {
    case alarm   = "alarm"
    case habit   = "habit"
    case overlap = "overlap"
    
    static var current: AppFlavor {
        #if ALARM_APP
        return .alarm
        #elseif HABIT_APP
        return .habit
        #elseif OVERLAP_APP
        return .overlap
        #else
        #warning("No ALARM_APP / HABIT_APP / OVERLAP_APP flag set. Defaulting to .alarm for development.")
        return .alarm
        #endif
    }
    
    var displayName: String {
        switch self {
        case .alarm:   return "Alarmo"
        case .habit:   return "Alarmo Habits"
        case .overlap: return "Alarmo Overlap"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .alarm:   return "com.yourcompany.alarmo"
        case .habit:   return "com.yourcompany.alarmo.habits"
        case .overlap: return "com.yourcompany.alarmo.overlap"
        }
    }
    
    var appGroupIdentifier: String {
        switch self {
        case .alarm:   return "group.com.yourcompany.alarmo"
        case .habit:   return "group.com.yourcompany.alarmo.habits"
        case .overlap: return ""
        }
    }
}
```

**Xcode Build Settings — add to each target:**

| Target | Other Swift Flags |
|--------|------------------|
| AlarmoAlarm | `-DALARM_APP` |
| AlarmoHabit | `-DHABIT_APP` |
| AlarmoOverlap | `-DOVERLAP_APP` |

### Step 1.2 — Xcode Target Creation

In Xcode, with `alarmo-foundation.xcodeproj` open:

1. **File → New → Target → iOS App**
   - Product Name: `AlarmoAlarm`
   - Bundle Identifier: `com.yourcompany.alarmo`
   - Add `AlarmApp.swift` as the entry point for this target only

2. **File → New → Target → iOS App**
   - Product Name: `AlarmoHabit`
   - Bundle Identifier: `com.yourcompany.alarmo.habits`
   - Add `HabitApp.swift` as the entry point for this target only

3. **File → New → Target → iOS App**
   - Product Name: `AlarmoOverlap`
   - Bundle Identifier: `com.yourcompany.alarmo.overlap`
   - Add `OverlapApp.swift` as the entry point for this target only

**Target Membership Configuration (do for every Swift file):**

For each file in the project navigator, open File Inspector and set target membership:

| File | AlarmoAlarm | AlarmoHabit | AlarmoOverlap |
|------|-------------|-------------|---------------|
| AlarmContinuousAudioEngine.swift | ✅ | ❌ | ❌ |
| AlarmRingCoordinator.swift | ✅ | ❌ | ❌ |
| AlarmBackgroundAudioBridge.swift | ✅ | ❌ | ❌ |
| AlarmAudioStateController.swift | ✅ | ❌ | ❌ |
| AlarmSchedulerIOS26AlarmKit.swift | ✅ | ❌ | ❌ |
| AlarmRingingView.swift | ✅ | ❌ | ❌ |
| AlarmListView.swift | ✅ | ❌ | ❌ |
| AlarmEditView.swift | ✅ | ❌ | ❌ |
| AlarmMissionsView.swift | ✅ | ❌ | ❌ |
| PlanView.swift | ❌ | ✅ | ❌ |
| TimerView.swift | ❌ | ✅ | ❌ |
| PomodoroView.swift | ❌ | ✅ | ❌ |
| BlockingManager.swift | ❌ | ✅ | ❌ |
| AccountabilityEnforcementManager.swift | ❌ | ✅ | ❌ |
| AppListsView.swift | ❌ | ✅ | ❌ |
| OverlapView.swift | ❌ | ❌ | ✅ |
| OverlapStore.swift | ❌ | ❌ | ✅ |
| AppTheme.swift | ✅ | ✅ | ✅ |
| ThemeManager.swift | ✅ | ✅ | ✅ |
| CommonSettingsStore.swift | ✅ | ✅ | ✅ |
| AppFlavor.swift | ✅ | ✅ | ✅ |
| SupportView.swift | ✅ | ✅ | ✅ |
| LegalView.swift | ✅ | ✅ | ✅ |
| AccountView.swift | ✅ | ✅ | ✅ |

> **Do not use `mv` to move files.** Target membership is the correct mechanism.
> File paths do not change. Git history is preserved.

### Step 1.3 — Settings Stores

**Create `Settings/AlarmSettingsStore.swift`:**

```swift
// AlarmSettingsStore.swift
// Alarm app settings — all keys prefixed with "alarm."
// Only included in AlarmoAlarm target.

import SwiftUI
import Combine

final class AlarmSettingsStore: ObservableObject {
    
    // MARK: - Alarm Behavior
    // Replace key strings with real keys from your migration matrix (Section 6)
    
    @AppStorage("alarm.snoozeDuration")
    var snoozeDuration: Int = 9
    
    @AppStorage("alarm.vibrationEnabled")
    var vibrationEnabled: Bool = true
    
    @AppStorage("alarm.bedtimeReminderEnabled")
    var bedtimeReminderEnabled: Bool = false
    
    @AppStorage("alarm.skipHolidaysEnabled")
    var skipHolidaysEnabled: Bool = false
    
    @AppStorage("alarm.mathMissionDifficulty")
    var mathMissionDifficulty: Int = 1
    
    @AppStorage("alarm.missionEnabled")
    var missionEnabled: Bool = false
    
    @AppStorage("alarm.defaultSoundName")
    var defaultSoundName: String = "Default"
    
    // MARK: - Migration
    
    func migrateFromLegacyKeysIfNeeded() {
        AlarmSettingsMigration.runIfNeeded()
    }
}
```

**Create `Settings/HabitSettingsStore.swift`:**

```swift
// HabitSettingsStore.swift
// Habit app settings — all keys prefixed with "habit."
// Only included in AlarmoHabit target.

import SwiftUI

final class HabitSettingsStore: ObservableObject {
    
    // MARK: - Timer / Pomodoro
    
    @AppStorage("habit.focusDuration")
    var focusDuration: Int = 25
    
    @AppStorage("habit.shortBreakDuration")
    var shortBreakDuration: Int = 5
    
    @AppStorage("habit.longBreakDuration")
    var longBreakDuration: Int = 15
    
    @AppStorage("habit.sessionsBeforeLongBreak")
    var sessionsBeforeLongBreak: Int = 4
    
    // MARK: - App Blocking
    
    @AppStorage("habit.blockingEnabled")
    var blockingEnabled: Bool = false
    
    @AppStorage("habit.blockingDuringFocusOnly")
    var blockingDuringFocusOnly: Bool = true
    
    // MARK: - Habits
    
    @AppStorage("habit.weekStartDay")
    var weekStartDay: Int = 1
    
    @AppStorage("habit.dailyReminderEnabled")
    var dailyReminderEnabled: Bool = false
    
    // MARK: - Migration
    
    func migrateFromLegacyKeysIfNeeded() {
        HabitSettingsMigration.runIfNeeded()
    }
}
```

**Create `Settings/CommonSettingsStore.swift`:**

```swift
// CommonSettingsStore.swift
// Settings shared across all three apps — keys prefixed with "common."
// Included in ALL targets.

import SwiftUI

final class CommonSettingsStore: ObservableObject {
    
    @AppStorage("common.appTheme")
    var appTheme: String = "default"
    
    @AppStorage("common.language")
    var language: String = "en"
    
    @AppStorage("common.hapticFeedback")
    var hapticFeedback: Bool = true
    
    @AppStorage("common.reviewRequestCount")
    var reviewRequestCount: Int = 0
    
    @AppStorage("common.hasCompletedOnboarding")
    var hasCompletedOnboarding: Bool = false
}
```

### Step 1.4 — Settings Root Views

**Create `Settings/AlarmSettingsRootView.swift`:**

```swift
// AlarmSettingsRootView.swift
// Only included in AlarmoAlarm target.

import SwiftUI

struct AlarmSettingsRootView: View {
    @EnvironmentObject var alarmSettings: AlarmSettingsStore
    @EnvironmentObject var commonSettings: CommonSettingsStore
    
    var body: some View {
        NavigationStack {
            List {
                Section("Alarm") {
                    NavigationLink("Snooze") {
                        SnoozeSettingsView()
                    }
                    NavigationLink("Missions") {
                        MissionsSettingsView()
                    }
                    NavigationLink("Sound Library") {
                        SoundLibraryView()
                    }
                    NavigationLink("Vibration") {
                        VibrationSettingsView()
                    }
                    NavigationLink("Bedtime Reminder") {
                        BedtimeReminderSettingsView()
                    }
                }
                
                Section("Appearance") {
                    NavigationLink("Theme") {
                        ThemeSettingsView()
                    }
                    NavigationLink("Language") {
                        LanguageSettingsView()
                    }
                }
                
                Section("Account") {
                    NavigationLink("Subscription") {
                        SubscriptionView()
                    }
                    NavigationLink("Support") {
                        SupportView()
                    }
                    NavigationLink("Legal") {
                        LegalView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Create `Settings/HabitSettingsRootView.swift`:**

```swift
// HabitSettingsRootView.swift
// Only included in AlarmoHabit target.

import SwiftUI

struct HabitSettingsRootView: View {
    @EnvironmentObject var habitSettings: HabitSettingsStore
    @EnvironmentObject var commonSettings: CommonSettingsStore
    
    var body: some View {
        NavigationStack {
            List {
                Section("Habits") {
                    NavigationLink("Weekly Goal") {
                        WeeklyGoalSettingsView()
                    }
                    NavigationLink("Reminders") {
                        HabitReminderSettingsView()
                    }
                    NavigationLink("Week Start Day") {
                        WeekStartDaySettingsView()
                    }
                }
                
                Section("Timer") {
                    NavigationLink("Focus Duration") {
                        FocusDurationSettingsView()
                    }
                    NavigationLink("Break Duration") {
                        BreakDurationSettingsView()
                    }
                    NavigationLink("Sessions Before Long Break") {
                        SessionsSettingsView()
                    }
                }
                
                Section("App Blocking") {
                    NavigationLink("Blocked Apps") {
                        AppListsView()
                    }
                    NavigationLink("Blocking Schedule") {
                        BlockingScheduleView()
                    }
                    NavigationLink("Accountability") {
                        AccountabilitySettingsView()
                    }
                }
                
                Section("Appearance") {
                    NavigationLink("Theme") { ThemeSettingsView() }
                    NavigationLink("Language") { LanguageSettingsView() }
                }
                
                Section("Account") {
                    NavigationLink("Subscription") { SubscriptionView() }
                    NavigationLink("Support") { SupportView() }
                    NavigationLink("Legal") { LegalView() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Create `Settings/OverlapSettingsRootView.swift`:**

```swift
// OverlapSettingsRootView.swift
// Only included in AlarmoOverlap target.

import SwiftUI

struct OverlapSettingsRootView: View {
    @EnvironmentObject var commonSettings: CommonSettingsStore
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    NavigationLink("Theme") { ThemeSettingsView() }
                    NavigationLink("Language") { LanguageSettingsView() }
                }
                
                Section("Account") {
                    NavigationLink("Subscription") { SubscriptionView() }
                    NavigationLink("Support") { SupportView() }
                    NavigationLink("Legal") { LegalView() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

### Step 1.5 — Report Domain Filtering

**Step A — Add domain restriction to existing ReportViewModel (do this first):**

```swift
// In existing ReportViewModel.swift — add domain parameter
// Do NOT change any UI yet — only add the filtering capability

extension ReportViewModel {
    
    enum ReportDomainRestriction {
        case all
        case alarmOnly
        case habitAndPomodoroOnly
    }
    
    func loadData(restriction: ReportDomainRestriction = .all) {
        switch restriction {
        case .all:
            // existing behavior unchanged
            loadAllDomains()
        case .alarmOnly:
            loadDomain(.alarm)
        case .habitAndPomodoroOnly:
            loadDomains([.habit, .pomodoro])
        }
    }
    
    private func loadDomain(_ domain: ActivityDomain) {
        // Use your existing query mechanism but filter by domain
        // Example with SwiftData:
        // let predicate = #Predicate<ActivityRecord> { $0.domain == domain.rawValue }
        // Replace with your actual query pattern
    }
    
    private func loadDomains(_ domains: [ActivityDomain]) {
        // Similar but with multiple domains
    }
}
```

**Verify Step A before proceeding to Step B:**
- Run the alarm target
- Confirm alarm report shows only alarm records
- Run the habit target
- Confirm habit report shows only habit + pomodoro records

**Step B — Create per-app report view models (only after Step A is verified):**

```swift
// Reports/AlarmReportViewModel.swift
// Only included in AlarmoAlarm target.

import SwiftUI
import Combine

final class AlarmReportViewModel: ObservableObject {
    
    @Published var alarmHistory: [AlarmRecord] = []
    @Published var streakCount: Int = 0
    @Published var successRate: Double = 0.0
    @Published var totalAlarmsThisWeek: Int = 0
    @Published var snoozedCount: Int = 0
    
    func load() {
        // Query ONLY ActivityDomain.alarm
        // Never query habit or pomodoro domains
        loadAlarmDomain()
    }
    
    private func loadAlarmDomain() {
        // Replace with your actual SwiftData / persistence query
        // Predicate must restrict to alarm domain only
    }
}
```

```swift
// Reports/HabitReportViewModel.swift
// Only included in AlarmoHabit target.

import SwiftUI

final class HabitReportViewModel: ObservableObject {
    
    @Published var habitHistory: [HabitRecord] = []
    @Published var pomodoroSessions: [PomodoroSession] = []
    @Published var habitStreakCount: Int = 0
    @Published var totalFocusMinutes: Int = 0
    @Published var habitCompletionRate: Double = 0.0
    
    func load() {
        // Query ONLY ActivityDomain.habit and ActivityDomain.pomodoro
        // Never query alarm domain
        loadHabitAndPomodorodomains()
    }
    
    private func loadHabitAndPomodorodomains() {
        // Replace with your actual query
    }
}
```

```swift
// Reports/AlarmReportRootView.swift
// Only included in AlarmoAlarm target.

import SwiftUI

struct AlarmReportRootView: View {
    @StateObject private var viewModel = AlarmReportViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AlarmStreakCard(viewModel: viewModel)
                    AlarmSuccessRateChart(viewModel: viewModel)
                    AlarmWeeklyOverview(viewModel: viewModel)
                    AlarmHistoryList(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Report")
            .onAppear { viewModel.load() }
        }
    }
}
```

### Step 1.6 — Per-App Main Views

**Create `Navigation/AlarmMainView.swift`:**

```swift
// AlarmMainView.swift
// Root view for AlarmoAlarm target.
// Only included in AlarmoAlarm target.

import SwiftUI

struct AlarmMainView: View {
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm.fill")
                }
            
            AlarmReportRootView()
                .tabItem {
                    Label("Report", systemImage: "chart.bar.fill")
                }
            
            AlarmSettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

**Create `Navigation/HabitMainView.swift`:**

```swift
// HabitMainView.swift
// Root view for AlarmoHabit target.
// Only included in AlarmoHabit target.

import SwiftUI

struct HabitMainView: View {
    var body: some View {
        TabView {
            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "list.bullet.clipboard.fill")
                }
            
            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
            
            HabitReportRootView()
                .tabItem {
                    Label("Report", systemImage: "chart.bar.fill")
                }
            
            HabitSettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

**Create `Navigation/OverlapMainView.swift`:**

```swift
// OverlapMainView.swift
// Root view for AlarmoOverlap target.
// Only included in AlarmoOverlap target.

import SwiftUI

struct OverlapMainView: View {
    var body: some View {
        TabView {
            OverlapView()
                .tabItem {
                    Label("Overlap", systemImage: "arrow.triangle.2.circlepath")
                }
            
            OverlapSettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

### Step 1.7 — App Entry Points

**Create `EntryPoints/AlarmApp.swift`:**

```swift
// AlarmApp.swift
// Entry point for AlarmoAlarm target ONLY.
// This file must ONLY be in AlarmoAlarm target membership.

import SwiftUI

@main
struct AlarmApp: App {
    
    @StateObject private var alarmSettings = AlarmSettingsStore()
    @StateObject private var commonSettings = CommonSettingsStore()
    
    init() {
        AlarmSettingsMigration.runIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            AlarmMainView()
                .environmentObject(alarmSettings)
                .environmentObject(commonSettings)
        }
    }
}
```

**Create `EntryPoints/HabitApp.swift`:**

```swift
// HabitApp.swift
// Entry point for AlarmoHabit target ONLY.
// This file must ONLY be in AlarmoHabit target membership.

import SwiftUI

@main
struct HabitApp: App {
    
    @StateObject private var habitSettings = HabitSettingsStore()
    @StateObject private var commonSettings = CommonSettingsStore()
    
    init() {
        HabitSettingsMigration.runIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            HabitMainView()
                .environmentObject(habitSettings)
                .environmentObject(commonSettings)
        }
    }
}
```

**Create `EntryPoints/OverlapApp.swift`:**

```swift
// OverlapApp.swift
// Entry point for AlarmoOverlap target ONLY.
// This file must ONLY be in AlarmoOverlap target membership.

import SwiftUI

@main
struct OverlapApp: App {
    
    @StateObject private var commonSettings = CommonSettingsStore()
    
    var body: some Scene {
        WindowGroup {
            OverlapMainView()
                .environmentObject(commonSettings)
        }
    }
}
```

### Step 1.8 — Commit contracts.md

```bash
cd ../alarmo-foundation

# Create the contracts file
mkdir -p split
# (paste the full contracts.md content from Section 3 into this file)

git add split/contracts.md
git add .  # all new files from Phase 1
git commit -m "feat: foundation split — per-app targets, settings stores, report VMs, contracts"
git push origin split/foundation-modularization
```

---

## 8. CI Matrix Setup — Phase 1 Gate Prerequisite

A CI matrix must be running and green before app branches are created.

### GitHub Actions Workflow

Create `.github/workflows/split-foundation-ci.yml` in the foundation branch:

```yaml
name: Split Foundation CI

on:
  push:
    branches:
      - split/foundation-modularization
      - split/alarm-app
      - split/habit-app
      - split/overlap-app
  pull_request:
    branches:
      - split/foundation-modularization

jobs:
  build-alarm:
    name: Build AlarmoAlarm
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app
      - name: Build AlarmoAlarm
        run: |
          xcodebuild build \
            -project Alarmo.xcodeproj \
            -scheme AlarmoAlarm \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO
      - name: Test AlarmoAlarm
        run: |
          xcodebuild test \
            -project Alarmo.xcodeproj \
            -scheme AlarmoAlarm \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO

  build-habit:
    name: Build AlarmoHabit
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app
      - name: Build AlarmoHabit
        run: |
          xcodebuild build \
            -project Alarmo.xcodeproj \
            -scheme AlarmoHabit \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO
      - name: Test AlarmoHabit
        run: |
          xcodebuild test \
            -project Alarmo.xcodeproj \
            -scheme AlarmoHabit \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO

  build-overlap:
    name: Build AlarmoOverlap
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app
      - name: Build AlarmoOverlap
        run: |
          xcodebuild build \
            -project Alarmo.xcodeproj \
            -scheme AlarmoOverlap \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO
      - name: Test AlarmoOverlap
        run: |
          xcodebuild test \
            -project Alarmo.xcodeproj \
            -scheme AlarmoOverlap \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            CODE_SIGNING_ALLOWED=NO

  contract-violations:
    name: Check Contract Violations
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Check cross-feature imports
        run: |
          # Check for AlarmFeature imports in HabitFeature files
          if grep -r "AlarmContinuousAudioEngine\|AlarmRingCoordinator" \
               --include="*.swift" \
               PlanView.swift HabitView.swift TimerView.swift \
               BlockingManager.swift 2>/dev/null; then
            echo "CONTRACT VIOLATION: HabitFeature files import AlarmFeature symbols"
            exit 1
          fi
          
          # Check for HabitFeature imports in AlarmFeature files
          if grep -r "BlockingManager\|AccountabilityEnforcementManager\|PlanView" \
               --include="*.swift" \
               AlarmContinuousAudioEngine.swift AlarmRingCoordinator.swift \
               AlarmRingingView.swift 2>/dev/null; then
            echo "CONTRACT VIOLATION: AlarmFeature files import HabitFeature symbols"
            exit 1
          fi
          
          echo "Contract violation check passed"
      
      - name: Check for unprefixed AppStorage keys
        run: |
          # Warn on any @AppStorage key without a namespace prefix
          VIOLATIONS=$(grep -rn '@AppStorage("' --include="*.swift" . | \
            grep -v '"alarm\.' | \
            grep -v '"habit\.' | \
            grep -v '"overlap\.' | \
            grep -v '"common\.' | \
            grep -v 'test' | \
            grep -v 'migration' | \
            grep -v '//' )
          
          if [ -n "$VIOLATIONS" ]; then
            echo "WARNING: Unprefixed @AppStorage keys found:"
            echo "$VIOLATIONS"
            # Uncomment to make this a hard failure:
            # exit 1
          else
            echo "All @AppStorage keys are properly namespaced"
          fi
```

---

## 9. Foundation Gate Checklist

**Every item must be ✅ before running the app branch creation commands from Section 4.6.**

### Compile Gate
- [ ] `xcodebuild build -scheme AlarmoAlarm` exits with code 0
- [ ] `xcodebuild build -scheme AlarmoHabit` exits with code 0
- [ ] `xcodebuild build -scheme AlarmoOverlap` exits with code 0
- [ ] Zero errors across all three builds
- [ ] Zero warnings related to the split (missing files, duplicate symbols, etc.)

### Runtime Gate
- [ ] AlarmoAlarm runs on iPhone simulator and shows `AlarmMainView`
- [ ] AlarmoHabit runs on iPhone simulator and shows `HabitMainView`
- [ ] AlarmoOverlap runs on iPhone simulator and shows `OverlapMainView`
- [ ] No crash on launch for any target
- [ ] Correct tab structure visible for each app

### Settings Gate
- [ ] `AlarmSettingsStore` compiles and all keys are prefixed `alarm.*`
- [ ] `HabitSettingsStore` compiles and all keys are prefixed `habit.*`
- [ ] `CommonSettingsStore` compiles and all keys are prefixed `common.*`
- [ ] Migration matrix from Section 6 is complete (all real keys mapped)
- [ ] `AlarmSettingsMigrationTests` all pass
- [ ] `HabitSettingsMigrationTests` all pass

### Reports Gate
- [ ] Step A (domain filtering) verified: alarm target shows only alarm data
- [ ] Step A verified: habit target shows only habit + pomodoro data
- [ ] `AlarmReportViewModel.load()` does not query habit or pomodoro domains
- [ ] `HabitReportViewModel.load()` does not query alarm domain

### CI Gate
- [ ] `.github/workflows/split-foundation-ci.yml` committed and pushed
- [ ] CI workflow triggered and all jobs green
- [ ] Contract violation check passing

### Contracts Gate
- [ ] `split/contracts.md` committed to `split/foundation-modularization`
- [ ] Module ownership table reviewed and accurate
- [ ] Import rules reviewed and agreed
- [ ] Key namespace rules reviewed and agreed

### Final Check
- [ ] `git -C ../alarmo branch --show-current` outputs `green-theme` (original untouched)
- [ ] `git -C ../alarmo status` outputs `nothing to commit, working tree clean`

---

## 10. Alarm App Branch — Phase 2

**Prerequisite:** Foundation Gate (Section 9) fully passed.

**Work location:** `alarmo-alarm-app/` worktree  
**Branch:** `split/alarm-app`

### Step 10.1 — Branch Creation From Foundation

```bash
# Run from alarmo-foundation after foundation gate passes
cd ../alarmo-foundation
git branch split/alarm-app
cd ..
git -C alarmo worktree add ./alarmo-alarm-app split/alarm-app

# Verify
cd alarmo-alarm-app
git branch --show-current
# Expected: split/alarm-app

git log --oneline -3
# Expected: shows foundation commits at top
```

### Step 10.2 — Target Membership — Alarm Only

In Xcode with `alarmo-alarm-app.xcodeproj`, verify target membership:

**Files to exclude from AlarmoAlarm (uncheck in File Inspector):**

```
❌ PlanView.swift
❌ HabitView.swift
❌ TimerView.swift
❌ PomodoroView.swift
❌ StopwatchView.swift
❌ BlockingManager.swift
❌ AccountabilityEnforcementManager.swift
❌ AppListsView.swift
❌ HabitSettingsStore.swift
❌ HabitSettingsRootView.swift
❌ HabitMainView.swift
❌ HabitApp.swift
❌ HabitReportViewModel.swift
❌ HabitReportRootView.swift
❌ OverlapView.swift
❌ OverlapStore.swift
❌ OverlapMainView.swift
❌ OverlapApp.swift
❌ OverlapSettingsRootView.swift
```

**Files that must be in AlarmoAlarm:**

```
✅ AlarmApp.swift  ← the @main entry point
✅ AlarmMainView.swift
✅ AlarmListView.swift
✅ AlarmEditView.swift
✅ AlarmRingingView.swift
✅ AlarmMissionsView.swift
✅ AlarmContinuousAudioEngine.swift
✅ AlarmRingCoordinator.swift
✅ AlarmBackgroundAudioBridge.swift
✅ AlarmAudioStateController.swift
✅ AlarmSchedulerIOS26AlarmKit.swift
✅ AlarmSchedulerForeground.swift
✅ NotificationManager.swift
✅ AlarmSettingsStore.swift
✅ AlarmSettingsRootView.swift
✅ AlarmReportViewModel.swift
✅ AlarmReportRootView.swift
✅ AlarmSettingsMigration.swift
✅ AppFlavor.swift
✅ AppTheme.swift
✅ ThemeManager.swift
✅ CommonSettingsStore.swift
✅ SupportView.swift
✅ LegalView.swift
✅ AccountView.swift
✅ All SwiftData schema files (full schema initially)
```

### Step 10.3 — Alarm App Build Configuration

**Bundle Settings:**
```
Product Bundle Identifier:  com.yourcompany.alarmo
Product Name:               Alarmo
Display Name:               Alarmo
Deployment Target:          iOS 17.0
Other Swift Flags:          -DALARM_APP
Code Sign Entitlements:     AlarmoAlarm.entitlements
```

**Info.plist — required keys:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
<key>NSUserNotificationsUsageDescription</key>
<string>Alarmo uses notifications to ring your alarm.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Alarmo uses the microphone for voice missions.</string>
```

**Info.plist — keys to remove:**
```
❌ NSFaceIDUsageDescription (if habit-only)
❌ FamilyControls related keys
❌ Screen Time related keys
```

### Step 10.4 — Alarm App Gate Checklist

- [ ] `xcodebuild build -scheme AlarmoAlarm` passes with zero errors
- [ ] App launches on real iPhone (not simulator for alarm testing)
- [ ] Create alarm flow: name → time → sound → save → alarm appears in list
- [ ] Alarm fires at scheduled time on locked real iPhone
- [ ] Custom alarm UI appears on unlock
- [ ] AlarmKit lock screen surface appears
- [ ] Slide-to-stop dismisses alarm correctly
- [ ] Snooze reschedules alarm correctly
- [ ] Stop cleans up all surfaces and stops audio
- [ ] Alarm reschedules for next day after stop
- [ ] Alarm settings save and persist across app restarts
- [ ] Alarm report shows only alarm data (no habit/pomodoro data visible)
- [ ] Snooze duration from `alarm.snoozeDuration` key is respected
- [ ] No symbols from `BlockingManager` or `PlanView` in binary:
  ```bash
  nm .build/AlarmoAlarm.app/AlarmoAlarm | grep -i "BlockingManager"
  # Expected: no output
  ```

---

## 11. Habit App Branch — Phase 3

**Prerequisite:** Foundation Gate (Section 9) fully passed.

**Work location:** `alarmo-habit-app/` worktree  
**Branch:** `split/habit-app`

### Step 11.1 — Branch Creation From Foundation

```bash
cd ../alarmo-foundation
git branch split/habit-app
cd ..
git -C alarmo worktree add ./alarmo-habit-app split/habit-app

cd alarmo-habit-app
git branch --show-current
# Expected: split/habit-app
```

### Step 11.2 — Target Membership — Habit Only

**Files to exclude from AlarmoHabit:**

```
❌ AlarmContinuousAudioEngine.swift
❌ AlarmRingCoordinator.swift
❌ AlarmBackgroundAudioBridge.swift
❌ AlarmAudioStateController.swift
❌ AlarmSchedulerIOS26AlarmKit.swift
❌ AlarmSchedulerForeground.swift
❌ AlarmRingingView.swift
❌ AlarmListView.swift
❌ AlarmEditView.swift
❌ AlarmMissionsView.swift
❌ AlarmSettingsStore.swift
❌ AlarmSettingsRootView.swift
❌ AlarmMainView.swift
❌ AlarmApp.swift
❌ AlarmReportViewModel.swift
❌ AlarmReportRootView.swift
❌ AlarmSettingsMigration.swift
❌ OverlapView.swift
❌ OverlapStore.swift
❌ OverlapMainView.swift
❌ OverlapApp.swift
❌ OverlapSettingsRootView.swift
```

**Files that must be in AlarmoHabit:**

```
✅ HabitApp.swift  ← the @main entry point
✅ HabitMainView.swift
✅ PlanView.swift / HabitView.swift
✅ TimerView.swift
✅ PomodoroView.swift
✅ StopwatchView.swift
✅ BlockingManager.swift
✅ AccountabilityEnforcementManager.swift
✅ AppListsView.swift
✅ HabitSettingsStore.swift
✅ HabitSettingsRootView.swift
✅ HabitReportViewModel.swift
✅ HabitReportRootView.swift
✅ HabitSettingsMigration.swift
✅ AppFlavor.swift
✅ AppTheme.swift
✅ CommonSettingsStore.swift
✅ SupportView.swift
✅ LegalView.swift
✅ AccountView.swift
✅ All SwiftData schema files (full schema initially)
```

### Step 11.3 — Habit App Build Configuration

**Bundle Settings:**
```
Product Bundle Identifier:  com.yourcompany.alarmo.habits
Product Name:               AlarmoHabit
Display Name:               Alarmo Habits
Deployment Target:          iOS 17.0
Other Swift Flags:          -DHABIT_APP
Code Sign Entitlements:     AlarmoHabit.entitlements
```

**FamilyControls Requirement:**

App blocking requires the `FamilyControls` framework and the corresponding entitlement. This entitlement requires explicit approval from Apple.

```
1. In Apple Developer Portal → Certificates, Identifiers & Profiles
2. Select the AlarmoHabit app identifier
3. Enable "Family Controls" capability
4. This triggers a review — Apple may ask for explanation of use case
5. Once approved, add to AlarmoHabit.entitlements:
   com.apple.developer.family-controls = true
```

**Shield Extension:**

The Shield extension (for blocking app UI while apps are blocked) must be its own target:

```
Target: AlarmoHabitShield
Type: Shield Configuration Extension
Parent App: AlarmoHabit
App Group: group.com.yourcompany.alarmo.habits
```

### Step 11.4 — Habit App Gate Checklist

- [ ] `xcodebuild build -scheme AlarmoHabit` passes with zero errors
- [ ] App launches and shows `HabitMainView`
- [ ] Habit CRUD: create habit → appears in list → mark complete → streak updates
- [ ] Timer: start focus session → timer counts down → session recorded
- [ ] Pomodoro: complete session → break notification fires
- [ ] App blocking: select apps → start blocking session → apps are blocked
- [ ] Shield extension: blocked app shows shield UI
- [ ] Habit report shows habit and pomodoro data only (no alarm data)
- [ ] Habit settings save and persist
- [ ] FamilyControls entitlement approved by Apple
- [ ] No alarm symbols in binary:
  ```bash
  nm .build/AlarmoHabit.app/AlarmoHabit | grep -i "AlarmRingCoordinator"
  # Expected: no output
  ```

---

## 12. Overlap App Branch — Phase 4

**Prerequisite:** Foundation Gate (Section 9) fully passed.

**Work location:** `alarmo-overlap-app/` worktree  
**Branch:** `split/overlap-app`

### Step 12.1 — Branch Creation From Foundation

```bash
cd ../alarmo-foundation
git branch split/overlap-app
cd ..
git -C alarmo worktree add ./alarmo-overlap-app split/overlap-app

cd alarmo-overlap-app
git branch --show-current
# Expected: split/overlap-app
```

### Step 12.2 — Target Membership — Minimal

**Keep in AlarmoOverlap:**
```
✅ OverlapApp.swift
✅ OverlapMainView.swift
✅ OverlapView.swift
✅ OverlapStore.swift
✅ All Overlap-related sheets and subviews
✅ OverlapSettingsRootView.swift
✅ AppFlavor.swift
✅ AppTheme.swift
✅ CommonSettingsStore.swift
✅ SupportView.swift
✅ LegalView.swift
✅ AccountView.swift
✅ Minimal SwiftData schema (overlap entities only — prune later)
```

**Exclude from AlarmoOverlap:**
```
❌ Everything alarm-related
❌ Everything habit-related
❌ BlockingManager.swift
❌ FamilyControls-related files
❌ NotificationManager.swift (unless overlap needs notifications)
```

### Step 12.3 — Overlap App Build Configuration

```
Product Bundle Identifier:  com.yourcompany.alarmo.overlap
Product Name:               AlarmoOverlap
Display Name:               Alarmo Overlap
Deployment Target:          iOS 17.0
Other Swift Flags:          -DOVERLAP_APP
Code Sign Entitlements:     AlarmoOverlap.entitlements (minimal)
```

### Step 12.4 — SharedData Pruning Strategy

Do not prune SwiftData schema aggressively in the initial branch. Keep the full schema and prune iteratively:

```
Phase 4 initial: Full schema (safe, may have unused entities)
Phase 4 stable:  Run app, identify which entities overlap actually uses
Phase 4 cleanup: Remove unused entity definitions one at a time
                 Run tests after each removal
                 Stop if any test fails
```

### Step 12.5 — Overlap App Gate Checklist

- [ ] `xcodebuild build -scheme AlarmoOverlap` passes with zero errors
- [ ] App launches and shows `OverlapMainView`
- [ ] Core overlap flow works end to end
- [ ] Settings save and load correctly
- [ ] Theme changes apply correctly
- [ ] Language change works
- [ ] No alarm symbols in binary
- [ ] No habit symbols in binary:
  ```bash
  nm .build/AlarmoOverlap.app/AlarmoOverlap | grep -i "BlockingManager"
  nm .build/AlarmoOverlap.app/AlarmoOverlap | grep -i "AlarmRingCoordinator"
  # Both expected: no output
  ```

---

## 13. Data Migration Strategy

### UserDefaults / @AppStorage Migration

Each app runs its migration exactly once on first launch using the `migrationKey` pattern.

```
First launch of AlarmApp:
  → AlarmSettingsMigration.runIfNeeded()
  → Reads old unprefixed keys
  → Writes to new alarm.* keys
  → Sets alarm.settings.migration.v1.complete = true
  → Never runs again

First launch of HabitApp:
  → HabitSettingsMigration.runIfNeeded()
  → Reads old unprefixed keys
  → Writes to new habit.* keys
  → Sets habit.settings.migration.v1.complete = true
```

### Multiple Apps Installed

If a user installs all three apps on the same device, each app reads from independent key namespaces. There is no conflict. Common settings (`common.*`) are shared across all three apps — a theme change in one app is reflected in others (this is intentional, they share the same App Group for common keys if desired).

If isolation is preferred for common settings, each app can use its own `common.*` independently. Decide this in Phase 0c.

### SwiftData Schema

```
Initial approach: Keep full schema in all app targets
Reason: Safe, no data loss risk, allows gradual pruning

Pruning plan (post-launch):
1. Identify which entities each app actually reads/writes
2. Create minimal schema for each app
3. Test migration from full schema to minimal schema
4. Ship migration in a point release, not the initial split release
```

### Rollback Strategy

If migration causes data loss:

```swift
// In each migration file, add a rollback method
struct AlarmSettingsMigration {
    
    static func rollback() {
        // Clear new namespaced keys — app will re-read defaults
        let keysToRemove = [
            "alarm.snoozeDuration",
            "alarm.vibrationEnabled",
            // ... all migrated keys
            migrationKey  // Reset migration flag so it runs again
        ]
        keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
```

Rollback is triggered by a remote config flag or a hidden developer setting. It allows hot-fixing migration bugs without a full app release.

---

## 14. Verification Gates Summary

### Foundation Gate (Section 9)
| Check | Command | Expected |
|-------|---------|----------|
| AlarmoAlarm builds | `xcodebuild build -scheme AlarmoAlarm` | exit 0 |
| AlarmoHabit builds | `xcodebuild build -scheme AlarmoHabit` | exit 0 |
| AlarmoOverlap builds | `xcodebuild build -scheme AlarmoOverlap` | exit 0 |
| Migration tests pass | `xcodebuild test -scheme AlarmoAlarm` | All tests green |
| CI matrix green | GitHub Actions | All jobs passing |
| contracts.md exists | `cat split/contracts.md` | File present |
| Original untouched | `git -C ../alarmo status` | Clean |

### Alarm App Gate (Section 10.4)
| Check | Method | Expected |
|-------|--------|----------|
| Builds | `xcodebuild build -scheme AlarmoAlarm` | exit 0 |
| Alarm fires on locked iPhone | Manual test | Alarm rings + vibrates |
| Custom UI on unlock | Manual test | AlarmRingingView appears |
| Stop works | Manual test | Engine stops, phase = stopped |
| No habit symbols | `nm binary \| grep BlockingManager` | No output |

### Habit App Gate (Section 11.4)
| Check | Method | Expected |
|-------|--------|----------|
| Builds | `xcodebuild build -scheme AlarmoHabit` | exit 0 |
| App blocking works | Manual test | Selected apps blocked |
| No alarm symbols | `nm binary \| grep AlarmRingCoordinator` | No output |

### Overlap App Gate (Section 12.5)
| Check | Method | Expected |
|-------|--------|----------|
| Builds | `xcodebuild build -scheme AlarmoOverlap` | exit 0 |
| Core overlap flow | Manual test | Works end to end |
| No alarm/habit symbols | `nm binary \| grep BlockingManager` | No output |

---

## 15. What Not To Do

```
❌ NEVER commit to green-theme branch
   Consequence: corrupts the base snapshot, cannot be undone

❌ NEVER use `mv` as the primary file isolation strategy
   Consequence: git history lost, cherry-picks break, merges become unsolvable

❌ NEVER create app branches from the original green-theme commit
   Consequence: foundation work done 3x, diverging implementations

❌ NEVER share bundle IDs between apps
   Consequence: App Store rejects, entitlements conflict, data collision

❌ NEVER write migration code before the key audit matrix is complete
   Consequence: silent data loss for existing users

❌ NEVER skip a gate
   Consequence: compounding bugs in later phases that are untraceable

❌ NEVER have multiple @main structs in the same compilation target
   Consequence: Swift compile error, build fails

❌ NEVER remove migration code until 100% of active users have updated
   Consequence: users on old version lose settings after update

❌ NEVER write to unprefixed legacy keys after migration
   Consequence: migration runs again incorrectly on next launch

❌ NEVER add FamilyControls entitlement to AlarmApp binary
   Consequence: App Store review rejection (entitlement requires justification per app)

❌ NEVER prune SwiftData schema aggressively on first release
   Consequence: data loss for users upgrading from combined app
```

---

## 16. Execution Timeline

| Week | Phase | Tasks | Gate |
|------|-------|-------|------|
| Week 1, Day 1 | Phase 0 | Git setup, tag, worktree creation | — |
| Week 1, Day 2 | Phase 0b | Extension/entitlement audit, decisions locked | Extension table complete |
| Week 1, Day 3 | Phase 0c | Settings key audit, migration matrix | Matrix complete |
| Week 1, Day 4-5 | Phase 1 start | AppFlavor, Xcode targets, target membership | — |
| Week 2, Day 1-2 | Phase 1 cont | Settings stores + migration code | — |
| Week 2, Day 3 | Phase 1 cont | Settings root views | — |
| Week 2, Day 4 | Phase 1 cont | Report domain filtering (Step A) | Step A verified |
| Week 2, Day 5 | Phase 1 cont | Report root views (Step B), app entry points | — |
| Week 3, Day 1 | Phase 1 cont | CI matrix setup, contracts.md | — |
| Week 3, Day 2 | Phase 1 fix | Fix compile errors, all 3 targets green | **Foundation Gate** |
| Week 3, Day 3-5 | Phase 2 | Alarm app branch, target membership | — |
| Week 4, Day 1 | Phase 2 test | Real iPhone testing, alarm flows | **Alarm App Gate** |
| Week 4, Day 2-4 | Phase 3 | Habit app branch, blocking, FamilyControls | — |
| Week 4, Day 5 | Phase 3 test | Habit flows, blocking verification | **Habit App Gate** |
| Week 5, Day 1-2 | Phase 4 | Overlap app branch | — |
| Week 5, Day 3 | Phase 4 test | Overlap flows | **Overlap App Gate** |
| Week 5, Day 4-5 | Final | Binary verification all apps, TestFlight submission prep | All gates passed |

---

## 17. Troubleshooting Common Issues

### Duplicate `@main` Compile Error

**Error:**
```
error: 'main' attribute cannot be applied to a type in a module that contains top-level code
```

**Cause:** Two files with `@main` in the same compilation target.

**Fix:**
1. Open Xcode → select each `*App.swift` file
2. Open File Inspector (right panel)
3. Verify `AlarmApp.swift` is ONLY checked for `AlarmoAlarm` target
4. Verify `HabitApp.swift` is ONLY checked for `AlarmoHabit` target
5. Verify `OverlapApp.swift` is ONLY checked for `AlarmoOverlap` target

```bash
# Verify via project file (should show only one entry per target)
grep -A2 "AlarmApp.swift" Alarmo.xcodeproj/project.pbxproj
```

### Cross-Target Symbol Leakage

**Symptom:** AlarmApp binary contains `BlockingManager` symbols.

**Detection:**
```bash
nm .build/Debug-iphonesimulator/AlarmoAlarm.app/AlarmoAlarm | \
  grep -i "BlockingManager"
```

**Fix:** Open File Inspector for `BlockingManager.swift`, uncheck `AlarmoAlarm` from target membership.

### Migration Key Mismatch

**Symptom:** User settings reset after update.

**Detection:**
```swift
// Add to AlarmApp startup for debugging:
let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
let alarmKeys = allKeys.filter { $0.hasPrefix("alarm.") }
print("Alarm keys after migration: \(alarmKeys)")
```

**Fix:** Audit migration matrix against real keys in `SettingsStore.swift`. The old key string in the migration must exactly match what is in production.

### Worktree Checkout Conflict

**Error:**
```
fatal: 'split/alarm-app' is already checked out at '/path/to/alarmo-alarm-app'
```

**Fix:**
```bash
# List all worktrees
git worktree list

# Remove stale worktree reference if folder was deleted manually
git worktree prune

# Then recreate
git worktree add ./alarmo-alarm-app split/alarm-app
```

### SwiftData Schema Mismatch Between Targets

**Symptom:** App crashes on launch with `NSPersistentStoreIncompatibleVersionHashError`

**Cause:** One target has a different schema version than the persistent store on device.

**Fix:**
```swift
// In ModelContainer setup for each target, add migration plan:
let schema = Schema([
    // Only include entities this target actually uses
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true
)

// Add lightweight migration option
do {
    container = try ModelContainer(
        for: schema,
        migrationPlan: AlarmoMigrationPlan.self,
        configurations: [modelConfiguration]
    )
} catch {
    // Handle gracefully — do not crash
    fatalError("Schema mismatch: \(error)")
}
```

### CI Build Fails on Foundation Branch

**Symptom:** CI reports `xcodebuild: error: scheme 'AlarmoHabit' not found`

**Fix:**
```bash
# List available schemes
xcodebuild -project Alarmo.xcodeproj -list

# If scheme is missing, open Xcode → Product → Scheme → Manage Schemes
# Check "Shared" for each scheme so it appears in source control
```

### Green-Theme Branch Accidentally Modified

**If this happens, stop immediately:**

```bash
# Check what changed
cd alarmo
git diff
git status

# Revert ALL changes to green-theme
git checkout -- .
git clean -fd

# Verify back to clean state
git status
# Expected: nothing to commit, working tree clean

# Verify HEAD matches snapshot tag
git rev-parse HEAD
git rev-parse split-base-snapshot
# Both should output the same commit hash
```

---

*End of Alarmo Split Implementation Plan*  
*All code samples are illustrative. Replace key strings, type names, and query patterns with real values from the codebase.*  
*This document must be updated if any architectural decisions change during implementation.*
