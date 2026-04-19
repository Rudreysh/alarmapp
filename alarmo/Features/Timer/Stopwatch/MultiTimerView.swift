import SwiftUI

struct MultiTimerView: View {
    @ObservedObject var store: MultiTimerStore
    @State private var showAddTimerSheet = false
    @State private var newTimerName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if store.timers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(store.timers) { timer in
                            ParallelTimerRow(timer: timer, onRemove: {
                                withAnimation { store.remove(timer) }
                            })
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            
            Spacer()
            
            // Multi-controls
            if !store.timers.isEmpty {
                HStack(spacing: 20) {
                    Button(action: { store.resetAll() }) {
                        Label("Reset All", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                    }
                    
                    Button(action: {
                        if store.anyRunning {
                            store.pauseAll()
                        } else {
                            store.startOrResumeAll()
                        }
                    }) {
                        Label(store.anyRunning ? "Pause All" : "Start All", 
                              systemImage: store.anyRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(TimerPalette.accent))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            
            // Add Button
            PrimaryButton(title: "Add New Timer", style: .blueGlass) {
                showAddTimerSheet = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddTimerSheet) {
            addTimerSheet
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 60))
                .foregroundColor(Colors.textTertiary)
            Text("Track multiple tasks simultaneously")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    private var addTimerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("New Parallel Timer")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIMER NAME")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                    
                    TextField("e.g. Cooking, Workout, Meeting", text: $newTimerName)
                        .font(.system(size: 18, weight: .semibold))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        .foregroundColor(Colors.textPrimary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                PrimaryButton(title: "Create Timer", style: .blueGlass) {
                    let finalName = newTimerName.trimmingCharacters(in: .whitespaces).isEmpty 
                        ? "Task \(store.timers.count + 1)" 
                        : newTimerName
                    store.addTimer(name: finalName)
                    newTimerName = ""
                    showAddTimerSheet = false
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
            .background(Colors.bgPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTimerSheet = false }
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct ParallelTimerRow: View {
    @ObservedObject var timer: ParallelTimer
    var onRemove: () -> Void
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    private var accentSunYellow: Color {
        Color(red: 0.98, green: 0.84, blue: 0.30)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle Progress indicator
            ZStack {
                Circle()
                    .stroke(timer.colorHex.color.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: timer.elapsed.truncatingRemainder(dividingBy: 60) / 60)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Colors.accentBlue.opacity(0.45),
                                timer.colorHex.color,
                                accentSunYellow.opacity(0.70),
                                Colors.accentBlue.opacity(0.65)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timer.elapsed)
                
                Image(systemName: timer.state == .running ? "stopwatch.fill" : "stopwatch")
                    .font(.system(size: 14))
                    .foregroundColor(timer.colorHex.color)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(timer.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)

                    Button {
                        renameText = timer.name
                        showRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Colors.textTertiary)
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit timer name")
                }
                
                Text(timer.timeDisplay)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(timer.state == .running ? timer.colorHex.color : Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Pause/Start
                Button(action: {
                    if timer.state == .running {
                        timer.pause()
                    } else if timer.state == .paused {
                        timer.resume()
                    } else {
                        timer.start()
                    }
                }) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(timer.colorHex.color))
                }
                
                // Reset
                Button(action: { timer.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(timer.state == .running ? timer.colorHex.color.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .contextMenu {
            Button {
                renameText = timer.name
                showRenameAlert = true
            } label: {
                Label("Edit Name", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onRemove) {
                Label("Delete Timer", systemImage: "trash")
            }
        }
        .alert("Edit Timer Name", isPresented: $showRenameAlert) {
            TextField("Timer Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    timer.name = trimmed
                }
            }
        } message: {
            Text("Update the timer label.")
        }
    }
}
