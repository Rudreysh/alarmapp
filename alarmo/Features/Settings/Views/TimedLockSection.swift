import SwiftUI

/// "Block Now" — a standalone timed lock that shields the active block list's apps
/// for a chosen duration, independent of the Pomodoro timer. Rendered as one List
/// row (a single VStack) so it never flattens into empty rows.
struct TimedLockSectionContent: View {
    let blockLists: [AppList]

    @ObservedObject private var lock = TimedAppLockManager.shared
    private let settings = SettingsStore.shared

    @State private var selectedMinutes: Int = 60
    @State private var strictness: TimedAppLockManager.Strictness = .locked
    @State private var note: String = ""
    @State private var missions: [UnblockChallenge] = [.math]
    @State private var showUnlock = false
    @State private var showMissionPicker = false

    private let presets: [(label: String, minutes: Int)] = [
        ("15m", 15), ("30m", 30), ("1h", 60), ("2h", 120), ("4h", 240), ("8h", 480)
    ]

    private var activeBlockList: AppList? {
        blockLists.first { $0.id.uuidString == settings.selectedBlockListId } ?? blockLists.first
    }

    private var hasAppsSelected: Bool {
        guard let list = activeBlockList else { return false }
        #if targetEnvironment(simulator)
        return !list.mockAppIDs.isEmpty || !list.mockCategoryIDs.isEmpty
        #elseif canImport(FamilyControls)
        return list.selectedApplicationsCount > 0 || list.selectedCategoriesCount > 0
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if lock.isActive {
                activeView
            } else {
                setupView
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showUnlock) { unlockSheet }
        .sheet(isPresented: $showMissionPicker) {
            TimedLockMissionPicker(selected: $missions)
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lock.state?.blockListName ?? "Apps locked")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text("Locked for \(TimedAppLockManager.formatRemaining(lock.remaining))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Colors.accentRed)
                }
                Spacer()
            }

            if let note = lock.state?.note, !note.isEmpty {
                Text("“\(note)”")
                    .font(.system(size: 13))
                    .foregroundColor(Colors.textSecondary)
            }

            Button {
                showUnlock = true
            } label: {
                Text(endButtonTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(lock.state?.strictness == .locked ? Colors.textTertiary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(lock.state?.strictness == .locked ? Color.white.opacity(0.08) : Colors.accentBlue)
                    )
            }
            .buttonStyle(.plain)

            Text(activeFooter)
                .font(.system(size: 12))
                .foregroundColor(Colors.textTertiary)
        }
    }

    private var endButtonTitle: String {
        switch lock.state?.strictness {
        case .flexible: return "End Lock"
        case .committed: return "Complete Mission to Unlock"
        case .locked, .none: return "Locked — No Escape"
        }
    }

    private var activeFooter: String {
        switch lock.state?.strictness {
        case .flexible: return "You can end this lock anytime."
        case .committed: return "Finish your unlock mission to end early."
        case .locked, .none: return "This lock cannot be ended until the timer runs out."
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Block the active list for a set time. Stronger levels can't be stopped early.")
                .font(.system(size: 13))
                .foregroundColor(Colors.textSecondary)

            // Duration
            Text("DURATION")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            HStack(spacing: 8) {
                ForEach(presets, id: \.minutes) { preset in
                    presetChip(preset.label, preset.minutes)
                }
            }

            // Strictness
            Text("STRICTNESS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            HStack(spacing: 8) {
                ForEach(TimedAppLockManager.Strictness.allCases, id: \.self) { level in
                    strictnessChip(level)
                }
            }
            Text(strictnessDescription(strictness))
                .font(.system(size: 13))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if strictness == .committed {
                Button { showMissionPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.accentBlue).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock Mission").font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text(missions.filter { $0 != .off }.isEmpty ? "Tap to choose a mission" : "\(missions.filter { $0 != .off }.count) selected")
                                .font(.system(size: 13))
                                .foregroundColor(missions.filter { $0 != .off }.isEmpty ? Colors.accentRed : Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Optional note
            TextField("Optional: what are you focusing on?", text: $note)
                .font(.system(size: 14))
                .foregroundColor(Colors.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !hasAppsSelected {
                Text("Select apps in a block list below before starting a lock.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.accentRed)
            }

            Button {
                startLock()
            } label: {
                Text("Start Lock — \(presets.first { $0.minutes == selectedMinutes }?.label ?? "\(selectedMinutes)m")")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule().fill(canStart ? Colors.accentRed : Color.gray.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canStart)
        }
    }

    private var canStart: Bool {
        guard hasAppsSelected, activeBlockList != nil else { return false }
        if strictness == .committed && missions.filter({ $0 != .off }).isEmpty { return false }
        return true
    }

    private func startLock() {
        guard canStart, let list = activeBlockList else { return }
        lock.start(
            blockList: list,
            duration: TimeInterval(selectedMinutes * 60),
            strictness: strictness,
            missions: missions,
            note: note
        )
    }

    // MARK: - Unlock sheet (reuses the existing mission intervention UI)

    private var unlockSheet: some View {
        SessionInterventionView(
            breakMode: breakMode(for: lock.state?.strictness ?? .locked),
            enabledChallenges: lock.state?.missions ?? [],
            onStopConfirmed: {
                _ = lock.requestStop(missionCompleted: true)
                showUnlock = false
            },
            onTakeBreak: { showUnlock = false },
            onDismiss: { showUnlock = false }
        )
    }

    private func breakMode(for strictness: TimedAppLockManager.Strictness) -> SessionBreakMode {
        switch strictness {
        case .flexible: return .easy
        case .committed: return .harder
        case .locked: return .hardcore
        }
    }

    // MARK: - Chips

    private func presetChip(_ label: String, _ minutes: Int) -> some View {
        let selected = selectedMinutes == minutes
        return Button { selectedMinutes = minutes } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(selected ? .white : Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Colors.accentRed : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func strictnessChip(_ level: TimedAppLockManager.Strictness) -> some View {
        let selected = strictness == level
        let accent: Color = level == .locked ? .red : Colors.accentBlue
        return Button { strictness = level } label: {
            VStack(spacing: 5) {
                Image(systemName: strictnessIcon(level)).font(.system(size: 16, weight: .semibold))
                Text(strictnessLabel(level)).font(.system(size: 12, weight: .bold))
                    .minimumScaleFactor(0.7).lineLimit(1)
            }
            .foregroundColor(selected ? .white : Colors.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? accent : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func strictnessLabel(_ level: TimedAppLockManager.Strictness) -> String {
        switch level {
        case .flexible: return "Flexible"
        case .committed: return "Committed"
        case .locked: return "Locked"
        }
    }
    private func strictnessIcon(_ level: TimedAppLockManager.Strictness) -> String {
        switch level {
        case .flexible: return "lock.open"
        case .committed: return "target"
        case .locked: return "lock.fill"
        }
    }
    private func strictnessDescription(_ level: TimedAppLockManager.Strictness) -> String {
        switch level {
        case .flexible: return "End the lock anytime."
        case .committed: return "Complete a mission to end the lock early."
        case .locked: return "No escape — apps stay blocked until the timer ends."
        }
    }
}

/// Local multi-select mission picker for the timed lock setup.
private struct TimedLockMissionPicker: View {
    @Binding var selected: [UnblockChallenge]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(UnblockChallenge.allCases.filter { $0 != .off }) { challenge in
                    let isOn = selected.contains(challenge)
                    Toggle(isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            if newValue {
                                if !selected.contains(challenge) { selected.append(challenge) }
                            } else {
                                selected.removeAll { $0 == challenge }
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: challenge.iconForFocus)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isOn ? Colors.accentBlue : Colors.textTertiary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(challenge.titleForFocus)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                Text(challenge.subtitleForFocus)
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                    }
                    .tint(Colors.accentBlue)
                }
            }
            .navigationTitle("Unlock Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .scrollContentBackground(.hidden)
            .background(SettingsGlassBackground())
        }
    }
}
