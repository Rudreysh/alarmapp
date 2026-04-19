import SwiftUI

struct ReligiousMissionSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let initialMission: AlarmMission
    let onSave: (AlarmMission) -> Void

    @State private var selectedIDs: Set<String>

    init(initialMission: AlarmMission, onSave: @escaping (AlarmMission) -> Void) {
        self.initialMission = initialMission
        self.onSave = onSave
        _selectedIDs = State(initialValue: ReligiousMissionContentStore.selectedIDs(from: initialMission))
    }

    private var missionType: WakeUpMissionType { initialMission.type }
    private var items: [SpokenVerseItem] { ReligiousMissionContentStore.items(for: missionType) }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("\(selectedIDs.count) selected")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Button("Deselect All") {
                                selectedIDs.removeAll()
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.accentOrange)
                        }

                        Text(ReligiousMissionContentStore.infoText(for: missionType))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        Text("POPULAR")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)

                        VStack(spacing: 12) {
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

            VStack {
                Spacer()
                Button("Done") {
                    saveMission()
                }
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Colors.cardSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
            }
            Spacer()
            Text(ReligiousMissionContentStore.sectionTitle(for: missionType))
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func verseCard(item: SpokenVerseItem, isSelected: Bool) -> some View {
        Button {
            toggle(item.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.accentOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Colors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.green.opacity(0.9) : Colors.cardStroke, lineWidth: isSelected ? 3 : 1)
            )
            .cornerRadius(22)
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
        var updated = AlarmMission(
            type: missionType,
            difficulty: initialMission.difficulty,
            rounds: initialMission.rounds,
            config: initialMission.config,
            customData: initialMission.customData
        )
        let effectiveSelection = selectedIDs.isEmpty ? ReligiousMissionContentStore.defaultSelectionIDs(for: missionType) : selectedIDs
        updated.customData[ReligiousMissionContentStore.selectedIDsKey] = ReligiousMissionContentStore.serializedIDs(effectiveSelection)
        onSave(updated)
        dismiss()
    }
}
