# Timer Mode Documentation

This document provides a detailed overview of the **Timer Mode** features implemented in the Alarmo app, including Pomodoro and Stopwatch functionalities, UI components, and state management.

---

## 1. Overview of Features

Timer Mode is a core module of the application, now accessible directly from the bottom navigation bar. It includes:

- **Pomodoro Mode**: A countdown timer for focus sessions with customizable durations.
- **Stopwatch Mode**: A precision count-up timer with decorative visual feedback.
- **Dynamic Progress Rings**: Visual indicators that update in real-time based on session progress.
- **Duration Management**: A grid-based selection for frequent Pomodoro times, including the ability to add, edit (via long-press), and delete presets.
- **Focus Note System**: Ability to add thoughts/notes during an active focus session.
- **Extended Settings**: Advanced toggles for "Strict Mode", "Flip Start", and OLED "Anti Burn-in".
- **Focus Records**: A dedicated logging system to track completed tasks and session times.

---

## 2. File-by-File Technical Breakdown

### Core Logic & Models

- **`Features/Timer/TimerModels.swift`**
  - Defined `TimerMode` (Pomo, Stopwatch) and `TimerState` (Idle, Running, Paused).
- **`Features/Timer/TimerViewModel.swift`**
  - **Purpose**: Centralized state management for the entire Timer module.
  - **Key Changes**:
    - Implemented the `Timer` engine using Combine's `Timer.publish`.
    - Logic for Pomo countdown and Stopwatch count-up.
    - Persistence placeholders for "Frequently Used" durations.
    - Dynamic calculation of `timeDisplay` (handling hours/minutes/seconds) and `progress` (0.0 to 1.0).
    - State flags for all 6+ modal sheets.

### UI Components (Reusable)

- **`Core/UIComponents/ProgressRing.swift`**
  - A versatile circular graphic.
  - **Pomo**: Displays a continuous stroke that trims as time passes.
  - **Stopwatch**: Displays a decorative 60-tick ring that animates based on elapsed seconds.
- **`Core/UIComponents/FocusRow.swift`**
  - A standardized tappable header for selecting focus categories (e.g., "Focus", "Study", "Work").

### Main Views

- **`Features/Timer/TimerRootView.swift`**
  - **Composition**: The container view for the module.
  - **Changes**: Integrated the pill-shaped segmented control for mode switching. Managed the presentation of all sheets (Settings, Goal, Record, etc.).
- **`Features/Timer/PomoTimerView.swift`**
  - Displays the large Pomo time.
  - Implemented "State-Aware Controls": Transitions from a large "Start" button to a control bar (Pause, Stop, Sound) during active sessions.
- **`Features/Timer/StopwatchView.swift`**
  - Displays the count-up timer with tick-mark feedback.

### Modals & Interaction Sheets

- **`Features/Timer/FrequentlyUsedPomoSheet.swift`**
  - **Features**: A 2-column grid of time tiles. Supports selection (single tap), editing (long press), and adding new durations (tap on "+").
- **`Features/Timer/PomoDurationPickerSheet.swift`**
  - A wheel-picker for selecting custom minutes (1–180), used for both adding new presets and editing existing ones.
- **`Features/Timer/FocusNoteSheet.swift`**
  - A specialized modal with a `TextEditor` and auto-focusing keyboard for capturing thoughts during a session.
- **`Features/Timer/FocusSettingsView.swift`**
  - Implementation of advanced behavioral toggles (Strict Mode, Sync, Flip Start) using native `Toggle` and card-based styling.
- **`Features/Timer/AddFocusRecordView.swift`**
  - A form to manually log focus history, including task name, start/end times, and notes.
- **`Features/Timer/AddTimerView.swift`**
  - A creation flow for new timer presets with an icon/emoji picker and radio buttons for mode selection.

### Navigation Integration

- **`Features/Home/MainTabContainerView.swift`**
  - **Changes**: Updated the `MainTab` enum and the master `switch` statement to include the **Timer** tab. Positioned the tab between "Alarm" and "Sleep".
- **`Features/Home/HomeView.swift`**
  - Updated UI spacing constants to ensure the bottom navigation bar never obscures Timer session controls.

---

## 3. Design Aesthetics

All features were built using the Alarmo design system:

- **Colors**: `accentRed` for highlights, `bgPrimary` for depth, and `cardSurface` for grouping.
- **Typography**: Large, bold numerical displays (64pt) for high readability.
- **Animations**: Smooth spring transitions between modes and modal presentations.
