import SwiftUI

struct CountdownPresetView: View {
    @ObservedObject var store: CountdownPresetStore
    @StateObject var engine: CountdownEngine
    @State private var showAddPreset = false
    
    // For handling the active timer overlay
    @State private var showActiveTimer = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Presets Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(store.presets) { preset in
                            PresetCard(preset: preset) {
                                engine.updatePreset(preset)
                                engine.start()
                                withAnimation { showActiveTimer = true }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let index = store.presets.firstIndex(where: { $0.id == preset.id }) {
                                        withAnimation {
                                            store.delete(at: IndexSet(integer: index))
                                        }
                                    }
                                } label: {
                                    Label("Delete Preset", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Add Custom Preset Button (Pro Feature)
                PrimaryButton(title: "Add Custom Preset", style: .blueGlass) {
                    showAddPreset = true
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Active Timer Overlay
            if showActiveTimer {
                ActiveCountdownOverlay(engine: engine) {
                    withAnimation { showActiveTimer = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showAddPreset) {
            AddCountdownPresetView(store: store)
        }
    }
}

struct PresetCard: View {
    let preset: CountdownPreset
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle().fill(preset.color.swiftUIColor.opacity(0.15))
                        Text(preset.emoji)
                            .font(.system(size: 24))
                    }
                    .frame(width: 44, height: 44)
                    
                    Spacer()
                    
                    if preset.autoRepeat {
                        Image(systemName: "repeat")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(preset.color.swiftUIColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(formatDuration(preset.duration))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
    
    private func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}

struct ActiveCountdownOverlay: View {
    @ObservedObject var engine: CountdownEngine
    var onDismiss: () -> Void
    @State private var showEditSheet = false
    
    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Colors.textSecondary)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(engine.preset.name)
                        .font(.system(size: 16, weight: .bold))
                    if engine.preset.autoRepeat {
                        Text("Cycle \(engine.currentRepeat)")
                            .font(.system(size: 12))
                            .foregroundColor(engine.preset.color.swiftUIColor)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Large Ring
            ZStack {
                ProgressRing(progress: engine.remaining / engine.preset.duration, 
                             color: engine.preset.color.swiftUIColor, showTicks: false)
                    .frame(width: 260, height: 260)
                    .scaleEffect(1.05)
                
                VStack(spacing: 8) {
                    Text(swFormatTime(engine.remaining, showHundredths: false))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .onTapGesture {
                            if engine.state == .running || engine.state == .paused {
                                showEditSheet = true
                            }
                        }
                    
                    Text("\(Int(engine.progress * 100))%")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 40) {
                Button(action: { engine.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                
                Button(action: {
                    if engine.state == .running {
                        engine.pause()
                    } else {
                        engine.start()
                    }
                }) {
                    Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(engine.preset.color.swiftUIColor))
                        .shadow(color: engine.preset.color.swiftUIColor.opacity(0.4), radius: 20)
                }
                
                Button(action: {
                    engine.reset()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                // Ambient glow
                engine.preset.color.swiftUIColor.opacity(0.08)
                    .blur(radius: 100)
                    .ignoresSafeArea()
            }
        )
        .sheet(isPresented: $showEditSheet) {
            TimerDurationPickerView(
                initialTotalSeconds: Int(engine.remaining),
                segmentTitle: engine.preset.name,
                onSave: { seconds in
                    engine.adjustRemainingTime(to: seconds)
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
    }
}
