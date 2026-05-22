import SwiftUI
import UIKit

struct AddCountdownPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CountdownPresetStore

    @State private var name: String = ""
    @State private var emoji: String = "⏱️"
    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
    @State private var selectedColor: Color = TimerPalette.accent
    @State private var autoRepeat: Bool = false
    @State private var repeatCount: Int = 1
    @State private var selectedAudience: CountdownAudience = .everyday
    @State private var details: String = ""

    private let colors: [Color] = [
        Colors.accentTeal,
        Colors.accentBlue,
        Colors.accentGreen,
        Colors.accentRed,
        Colors.accentOrange
    ]

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hours == 0 && minutes == 0 && seconds == 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TimerGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        iconAndNameCard
                        durationCard
                        audienceCard
                        colorCard
                        repeatCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }

                VStack {
                    Spacer()
                    PrimaryButton(title: "Save Preset", style: .blueGlass) {
                        savePreset()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .disabled(isSaveDisabled)
                    .opacity(isSaveDisabled ? 0.5 : 1.0)
                }
            }
            .navigationTitle("New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
    }

    private var iconAndNameCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(selectedColor.opacity(0.18))
                    .frame(width: 90, height: 90)
                Text(emoji)
                    .font(.system(size: 44))
            }

            TextField("Preset Name", text: $name)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textPrimary)

            TextField("Short description (optional)", text: $details)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textSecondary)

            TextField("Emoji", text: $emoji)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(Colors.textSecondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Colors.cardSurface))
                .overlay(Capsule().stroke(Colors.cardStroke, lineWidth: 1))
                .frame(maxWidth: 120)
        }
        .padding(16)
        .timerGlassCard(cornerRadius: 18)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Duration")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            HStack {
                TimePickerColumn(value: $hours, range: 0...23, suffix: "h")
                TimePickerColumn(value: $minutes, range: 0...59, suffix: "m")
                TimePickerColumn(value: $seconds, range: 0...59, suffix: "s")
            }
            .frame(height: 124)
        }
        .padding(14)
        .timerGlassCard(cornerRadius: 18)
    }

    private var audienceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CountdownAudience.allCases) { audience in
                        Button {
                            selectedAudience = audience
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: audience.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(audience.title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(selectedAudience == audience ? Colors.textPrimary : Colors.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selectedAudience == audience ? TimerPalette.accent.opacity(0.22) : Colors.cardSurface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedAudience == audience ? TimerPalette.accent.opacity(0.55) : Colors.cardStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .timerGlassCard(cornerRadius: 18)
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Colors.textPrimary.opacity(selectedColor == color ? 1 : 0), lineWidth: 2)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedColor = color
                            }
                        }
                }
            }
        }
        .padding(14)
        .timerGlassCard(cornerRadius: 18)
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $autoRepeat) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Repeat")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Text("Use this for rounds, sets, and interval loops")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .tint(TimerPalette.accent)

            if autoRepeat {
                HStack {
                    Text("Repeat Count")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    Spacer()

                    Stepper("\(repeatCount == 0 ? "Infinite" : "\(repeatCount)")", value: $repeatCount, in: 0...200)
                        .labelsHidden()

                    Text(repeatCount == 0 ? "Infinite" : "\(repeatCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(minWidth: 72, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .timerGlassCard(cornerRadius: 18)
    }

    private func savePreset() {
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)
        let components = selectedColor.rgbComponents

        let preset = CountdownPreset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emoji.isEmpty ? "⏱️" : emoji,
            duration: max(1, totalSeconds),
            color: CountdownPreset.CodableColor(r: components.r, green: components.g, blue: components.b),
            autoRepeat: autoRepeat,
            repeatCount: repeatCount,
            audience: selectedAudience,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            isSystemTemplate: false
        )

        store.add(preset)
        dismiss()
    }
}

private extension Color {
    var rgbComponents: (r: Double, g: Double, b: Double) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b))
        }

        return (0.10, 0.66, 0.95)
    }
}

struct TimePickerColumn: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { i in
                    Text("\(i)").tag(i)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()

            Text(suffix)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
