# 📱 Alarm App – Complete Product, UI, System & Data Design Context (iOS)

> **Purpose of this document**  
> This Markdown file provides **full end-to-end context** for an AI coding agent or developer to understand and implement a modern iOS alarm app.  
> It consolidates **product vision, UI intent, onboarding flow, system design, database schema, asset handling, offline vs online strategy, and future extensibility** — without missing any detail discussed so far.

---

## 1. 🎯 Product Objective

Build a **modern, offline-first alarm app** inspired by Alarmy, with emphasis on:

- Reliable alarms that **always ring**, even offline
- Highly customizable alarms:
  - Alarm time
  - Wallpaper
  - Alarm sound
  - Volume & gentle wake-up
  - Snooze rules
  - Wake-up missions
- **Premium-quality UI**
  - Dark-mode first
  - Rounded cards
  - Smooth animations
  - Soft shadows
  - Modern typography
- Scalable architecture supporting:
  - Large wallpaper & sound libraries
  - Offline + online content delivery
  - Future health & wearable integrations

The app must feel **fast, polished, dependable, and delightful**.

---

## 2. 🧭 Core Principles

- **Offline-first**
  - Alarms must work without internet
- **Content-driven**
  - Wallpapers & sounds organized by categories
- **Scalable**
  - Architecture supports future features without refactor
- **Apple-native**
  - SwiftUI
  - SQLite
  - Apple On-Demand Resources (ODR)
  - HealthKit (future)

---

## 3. 🧩 Onboarding Flow (UI-Driven)

### Step 1 – App Intro / Preview
**Purpose**
- Communicate app value instantly
- Show comparison with default alarms

**UI**
- Dark background
- Large bold headline
- Card-style comparison
- Primary red CTA: **Next**

---

### Step 2 – Set Alarm Time
**Purpose**
- Set initial alarm time
- Persist as default preference

**Interaction**
- Vertical wheel picker
- Separate hour & minute columns
- Scroll gesture

**Stored State**
- Selected hour
- Selected minute

CTA: **Next**

---

### Step 3 – Permissions (future)
**Purpose**
- Ensure alarm reliability

**Permissions**
- Notifications
- Alarm / background audio

**UX**
- Pre-permission explanation
- System permission modal

---

### Step 4 – Choose Wallpaper
**Purpose**
- Select visual shown during alarm

**Features**
- Category-based browsing
- Horizontal category selector
- Carousel or grid per category

**Sources**
- Offline bundled wallpapers
- On-Demand Resources (ODR)
- User Photos (“My Photos”)

---

### Step 5 – My Photos (Album Access)
**Purpose**
- Use personal photos as alarm wallpaper

**Implementation**
- `PhotosPicker` / `PHPicker`
- Limited photo access
- Store `PHAsset.localIdentifier`

**Fallback**
- If permission revoked → fallback wallpaper

---

### Step 6 – Wallpaper Preview
**Purpose**
- Confirm selected wallpaper

**UI**
- Full-screen preview
- Time/date overlay
- CTA: **Select / Next**

---

### Step 7 – Choose Alarm Sound
**Purpose**
- Select alarm sound

**Features**
- Category tabs
- Single selection
- Tap to preview

**Sources**
- Offline bundled sounds
- ODR sound packs

---

### Step 8 – Audio Settings
**Settings**
- Volume slider (0–100%)
- Gentle wake-up toggle
- Ramp duration (e.g. 30 sec)
- Preview button

---

### Step 9 – Wake-Up Mission
**Purpose**
- Prevent easy dismissal

**Options**
- Off
- Math
- Typing
- Find color tiles
- Shake

Each mission has configurable difficulty.

---

## 4. ⏰ App Behavior After Onboarding

### Alarm Management
- Create / edit / delete alarms
- Enable / disable
- Repeat rules (days)
- Snooze configuration

### Alarm Ringing
- Full-screen UI
- Wallpaper background
- Sound playback
- Gentle wake-up ramp
- Mission enforcement

### Snooze Logic
- Interval
- Max count
- Forced dismissal after max

---

## 5. 📦 Offline vs Online Asset Strategy

### Offline (Bundled)
Must include:
- 1–3 wallpapers
- 3–8 alarm sounds
- Core UI assets

Criteria:
- Small size
- Loud + gentle options

---

### Online (Expanded)
Delivered via **Apple On-Demand Resources (ODR)**:
- Wallpaper packs
- Sound packs
- Category-based delivery

**Benefits**
- Smaller app size
- iOS-managed caching
- Automatic cleanup

---

### ODR Flow
1. Load catalog metadata
2. User selects asset
3. If missing → request ODR pack
4. Show progress
5. Cache + persist availability

---

## 6. 🧾 Required Inputs Before Coding

### Media
- Wallpapers (optimized resolutions)
- Sounds (normalized loudness)

### Metadata
- `catalog.categories.json`
- `catalog.assets.json`
- `odr.packs.json`
- `missions.json`
- `entitlements.json`

### UX
- Copy strings
- Permission text
- Error messages

### Other
- App icons
- Launch screen
- Localization scaffolding
- Preview audio clips (optional)

---

## 7. 🗄 Database Choice

### Why Local DB
- Offline reliability
- Fast access
- Alarm persistence
- Asset availability tracking

### Recommended
**SQLite + GRDB**

---

## 8. 🧱 SQLite Schema

### app_settings
```sql
id INTEGER PRIMARY KEY
onboarding_completed INTEGER
created_at TEXT
updated_at TEXT
