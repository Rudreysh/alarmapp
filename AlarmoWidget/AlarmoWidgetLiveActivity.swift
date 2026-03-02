import ActivityKit
import WidgetKit
import SwiftUI

@main
struct AlarmoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmoWidgetLiveActivity()
    }
}

struct AlarmoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomoAttributes.self) { context in
            // Lock screen/banner UI
            ZStack {
                // Background
                Color(red: 0.1, green: 0.12, blue: 0.15)
                    .edgesIgnoringSafeArea(.all)
                
                HStack {
                    // Left Side: Title and Time
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Alarmo")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 52, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 170, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            Text("🔥")
                                .font(.system(size: 18))
                            Text(context.state.stateString)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            // Music controls (visuals)
                            if let sound = context.state.ambientSoundName, !sound.isEmpty {
                                Button(intent: ToggleTimerIntent()) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: context.state.isAmbientPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.red).frame(width: 14, height: 14))
                                            .offset(x: 2, y: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 10)
                            }
                        }
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                    
                    // Right Side: Circular Timer Visual
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 10)
                            .frame(width: 90, height: 90)
                        
                        ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                            .progressViewStyle(.circular)
                            .tint(Color.orange)
                            .scaleEffect(2.0)
                            .frame(width: 90, height: 90)
                        
                        // Sunray / Pomodoro Icon in the center
                        Image(systemName: "timer")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.trailing, 28)
                }
                .padding(.vertical, 16)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(context.attributes.focusName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.stateString)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Music controls (visuals)
                        if let sound = context.state.ambientSoundName, !sound.isEmpty {
                            Button(intent: ToggleTimerIntent()) {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                        
                                    Image(systemName: context.state.isAmbientPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.red).frame(width: 14, height: 14))
                                        .offset(x: 2, y: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            } compactTrailing: {
                HStack(spacing: 4) {
                    if let sound = context.state.ambientSoundName, !sound.isEmpty {
                        Button(intent: ToggleTimerIntent()) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: context.state.isAmbientPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.red).frame(width: 10, height: 10))
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(timerInterval: context.state.startTime...context.state.endTime, countsDown: true)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(width: 45)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            }
            .keylineTint(Color.orange)
        }
    }
}
