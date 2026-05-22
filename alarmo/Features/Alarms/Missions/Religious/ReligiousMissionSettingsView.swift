import SwiftUI

struct ReligiousMissionSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let initialMission: AlarmMission
    let onSave: (AlarmMission) -> Void

    @State private var selectedIDs: Set<String>
    @State private var showAlarmPreview = false
    @State private var pendingPreviewLaunch = false
    @State private var preparedPreview: ReligiousPreviewPayload?
    @State private var activePreview: ReligiousPreviewPayload?

    init(initialMission: AlarmMission, onSave: @escaping (AlarmMission) -> Void) {
        self.initialMission = initialMission
        self.onSave = onSave
        _selectedIDs = State(initialValue: ReligiousMissionContentStore.selectedIDs(from: initialMission))
    }

    private var missionType: WakeUpMissionType { initialMission.type }
    private var items: [SpokenVerseItem] { ReligiousMissionContentStore.items(for: missionType) }
    private var theme: ReligiousTheme { ReligiousTheme.forType(missionType) }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        heroCard
                        selectionControls

                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                verseCard(item: item, isSelected: selectedIDs.contains(item.id))
                            }
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }

            footerButtons
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: initialMission.title,
                missionIcon: initialMission.iconName
            ) {
                launchGamePreviewAfterAlarmPreview()
            }
        }
        .onChange(of: showAlarmPreview) { _, isPresented in
            guard !isPresented, pendingPreviewLaunch, let preparedPreview else { return }
            pendingPreviewLaunch = false
            DispatchQueue.main.async {
                activePreview = preparedPreview
            }
        }
        .fullScreenCover(item: $activePreview) { payload in
            ReligiousMissionLaunchView(
                mission: payload.mission,
                onComplete: {
                    activePreview = nil
                },
                verse: payload.verse
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Colors.cardSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.shortTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.accent)
                Text("Recitation Mission")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: theme.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.accent)
                    .frame(width: 32, height: 32)
                    .background(theme.accent.opacity(0.18))
                    .clipShape(Circle())

                Text("Select Verses to Practice")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Colors.cardSurface
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(20)
    }

    private var selectionControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 7, height: 7)
                Text("\(selectedIDs.count) selected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Colors.cardSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )

            Spacer()

            Button("Select All") {
                selectedIDs = Set(items.map(\.id))
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Colors.accentTeal)

            Text("•")
                .foregroundColor(Colors.textSecondary)

            Button("Clear") {
                selectedIDs.removeAll()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Colors.accentRed)
        }
    }

    private func verseCard(item: SpokenVerseItem, isSelected: Bool) -> some View {
        Button {
            toggle(item.id)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(isSelected ? theme.accent : Colors.cardStroke.opacity(0.7))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? theme.accent : Colors.textSecondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.title.uppercased())
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(isSelected ? theme.accent : Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Spacer(minLength: 6)

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(isSelected ? theme.accent : Colors.textSecondary.opacity(0.75))
                        }

                        Text("“\(item.text)”")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Colors.cardSurface
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? theme.accent.opacity(0.55) : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }

    private var footerButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button(action: startPreview) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black.opacity(0.56))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                        .cornerRadius(32)
                }

                Button(action: saveMission) {
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Colors.accentTeal,
                                    Colors.accentBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(32)
                        .shadow(color: Colors.shadow.opacity(0.25), radius: 12, x: 0, y: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(y: -40)
                .allowsHitTesting(false)
            )
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func saveMission() {
        onSave(builtMissionForCurrentSelection())
        dismiss()
    }

    private func startPreview() {
        let missionForPreview = builtMissionForCurrentSelection()
        guard let verse = ReligiousMissionContentStore.pickRandomItem(for: missionForPreview) else { return }
        preparedPreview = ReligiousPreviewPayload(mission: missionForPreview, verse: verse)
        pendingPreviewLaunch = false
        showAlarmPreview = true
    }

    private func launchGamePreviewAfterAlarmPreview() {
        guard preparedPreview != nil else { return }
        pendingPreviewLaunch = true
        showAlarmPreview = false
    }

    private func builtMissionForCurrentSelection() -> AlarmMission {
        var updated = AlarmMission(
            type: missionType,
            difficulty: initialMission.difficulty,
            rounds: initialMission.rounds,
            config: initialMission.config,
            customData: initialMission.customData
        )
        let effectiveSelection = selectedIDs.isEmpty ? ReligiousMissionContentStore.defaultSelectionIDs(for: missionType) : selectedIDs
        updated.customData[ReligiousMissionContentStore.selectedIDsKey] = ReligiousMissionContentStore.serializedIDs(effectiveSelection)
        return updated
    }
}

private struct ReligiousPreviewPayload: Identifiable {
    let id = UUID()
    let mission: AlarmMission
    let verse: SpokenVerseItem
}

private struct ReligiousTheme {
    let shortTitle: String
    let symbol: String
    let accent: Color

    static func forType(_ type: WakeUpMissionType) -> ReligiousTheme {
        let religionBlue = Color(red: 0.44, green: 0.80, blue: 0.98)
        switch type {
        case .bibleVerse:
            return .init(shortTitle: "Bible", symbol: "book.closed.fill", accent: religionBlue)
        case .quranVerse:
            return .init(shortTitle: "Quran", symbol: "moon.stars.fill", accent: religionBlue)
        case .bhagavadGitaVerse:
            return .init(shortTitle: "Bhagavad Gita", symbol: "sun.max.fill", accent: religionBlue)
        case .affirmation:
            return .init(shortTitle: "Affirmations", symbol: "sparkles", accent: religionBlue)
        default:
            return .init(shortTitle: "Recitation", symbol: "quote.bubble.fill", accent: religionBlue)
        }
    }
}
