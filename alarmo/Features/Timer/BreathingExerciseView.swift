import SwiftUI
import AVFoundation

// MARK: - Breathing Sound Engine
/// Generates a soothing, meditation sine-wave tone that pitches up/down with the breath
class BreathingSoundGenerator {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    
    var frequency: Double = 300.0
    var volume: Double = 0.0
    private var time: Double = 0
    
    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let self = self else { return noErr }
            
            let dt = 1.0 / 44100.0
            // Apply a slight tremolo for a more organic "bowl" feel
            let tremoloSpeed = 4.0
            
            for frame in 0..<Int(frameCount) {
                let currentVolume = self.volume * (1.0 + 0.1 * sin(self.time * 2.0 * .pi * tremoloSpeed))
                let sample = Float(sin(self.time * 2.0 * .pi * self.frequency) * currentVolume)
                self.time += dt
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        
        engine.mainMixerNode.outputVolume = 0.8
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }
    
    func start() {
        try? engine.start()
    }
    
    func stop() {
        engine.stop()
    }
}


// MARK: - Breathing Exercise View
/// A beautiful full-screen breathing exercise with gradient animations,
/// pulsing orb, and meditation music. User must complete 3 breath cycles.
struct BreathingExerciseView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var breathPhase: BreathPhase = .breatheIn
    @State private var completedCycles: Int = 0
    @State private var orbScale: CGFloat = 0.6
    @State private var orbOpacity: Double = 0.7
    @State private var glowRadius: CGFloat = 20
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding: Bool = false
    @State private var holdTimer: Timer? = nil
    @State private var phaseTimer: Timer? = nil
    @State private var gradientAngle: Double = 0
    @State private var isCompleted: Bool = false
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var particleSystem = ParticleSystem()
    @State private var soundGen = BreathingSoundGenerator()
    @State private var soundTimer: Timer? = nil
    
    private let requiredCycles = 1
    private let breatheInDuration: Double = 4.0
    private let holdDuration: Double = 4.0
    private let breatheOutDuration: Double = 6.0
    
    enum BreathPhase: String {
        case breatheIn = "Breathe In"
        case hold = "Hold"
        case breatheOut = "Breathe Out"
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            animatedGradientBackground
            
            // Floating particles
            floatingParticles
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Breathing orb
                breathingOrb
                    .padding(.bottom, 16)
                
                // Phase label
                Text(breathPhase.rawValue)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .animation(.easeInOut(duration: 0.5), value: breathPhase)
                
                // Progress dots
                HStack(spacing: 12) {
                    ForEach(0..<requiredCycles, id: \.self) { index in
                        Circle()
                            .fill(index < completedCycles ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index < completedCycles ? 1.2 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: completedCycles)
                    }
                }
                .padding(.top, 24)
                
                Text("\(completedCycles) of \(requiredCycles) breaths")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
                
                Spacer()
                
                // Bottom buttons
                VStack(spacing: 12) {
                    if isCompleted {
                        // Continue button
                        Button(action: {
                            stopMusic()
                            onComplete()
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Waiting / hold indicator
                        if breathPhase == .hold {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.8), Color.white, Color.white.opacity(0.9)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, geo.size.width * holdProgress))
                                        .shadow(color: .white.opacity(0.7), radius: 8, x: 0, y: 0)
                                        .shadow(color: .white.opacity(1.0), radius: 4, x: 0, y: 0)
                                }
                                .frame(height: 52)
                            }
                            .frame(height: 52)
                            .overlay(
                                Text("Hold…")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                    }
                    
                    Button(action: {
                        stopMusic()
                        onCancel()
                    }) {
                        Text("Nevermind")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startMusic()
            // soundGen.start() // Disabled to prevent conflicting sounds
            startBreathCycle()
            startGradientAnimation()
        }
        .onDisappear {
            stopMusic()
            // soundGen.stop()
            phaseTimer?.invalidate()
            holdTimer?.invalidate()
            soundTimer?.invalidate()
        }
    }
    
    // MARK: - Animated Gradient Background
    private var animatedGradientBackground: some View {
        ZStack {
            // Base waterfall gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.15, green: 0.10, blue: 0.25), location: 0),
                    .init(color: Color(red: 0.25, green: 0.20, blue: 0.40), location: 0.3),
                    .init(color: Color(red: 0.40, green: 0.30, blue: 0.50), location: 0.5),
                    .init(color: Color(red: 0.50, green: 0.35, blue: 0.45), location: 0.7),
                    .init(color: Color(red: 0.20, green: 0.15, blue: 0.30), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Warm accent gradient overlay
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.75, blue: 0.50).opacity(0.25),
                    Color(red: 0.70, green: 0.45, blue: 0.65).opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .scaleEffect(1.0 + sin(gradientAngle * 0.5) * 0.15)
            
            // Moving light pillar (waterfall effect)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.08),
                            Color(red: 1.0, green: 0.9, blue: 0.7).opacity(0.12),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200)
                .offset(x: sin(gradientAngle * 0.3) * 60)
                .blur(radius: 40)
        }
    }
    
    // MARK: - Floating Particles
    private var floatingParticles: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particleSystem.particles {
                    let age = now - particle.createdAt
                    let lifetime = particle.lifetime
                    guard age < lifetime else { continue }
                    let progress = age / lifetime
                    let alpha = sin(progress * .pi) * particle.maxAlpha
                    let y = particle.startY - progress * size.height * 0.6
                    let x = particle.startX + sin(progress * 4 + particle.phase) * 20
                    let radius = particle.radius * (1 - progress * 0.5)
                    
                    context.opacity = alpha
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
        .onAppear { particleSystem.start() }
        .onDisappear { particleSystem.stop() }
    }
    
    // MARK: - Breathing Orb
    private var breathingOrb: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.15 - Double(ring) * 0.04),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40 + CGFloat(ring) * 15,
                            endRadius: 80 + CGFloat(ring) * 30
                        )
                    )
                    .frame(width: 200 + CGFloat(ring) * 40, height: 200 + CGFloat(ring) * 40)
                    .scaleEffect(orbScale)
                    .opacity(orbOpacity * (1 - Double(ring) * 0.2))
            }
            
            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.7),
                            Color(red: 0.85, green: 0.80, blue: 0.90).opacity(0.5),
                            Color(red: 0.70, green: 0.60, blue: 0.80).opacity(0.2)
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 10,
                        endRadius: 70
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(orbScale)
                .shadow(color: Color.white.opacity(0.4), radius: glowRadius, x: 0, y: 0)
                .shadow(color: Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.3), radius: glowRadius * 1.5, x: 0, y: 0)
        }
    }
    
    // MARK: - Breath Cycle Logic
    private func startBreathCycle() {
        guard completedCycles < requiredCycles else {
            withAnimation(.spring(response: 0.6)) { isCompleted = true }
            return
        }
        
        // Breathe In
        breathPhase = .breatheIn
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.easeInOut(duration: breatheInDuration)) {
            orbScale = 1.2
            orbOpacity = 1.0
            glowRadius = 50
        }
        
        animateSound(fromFreq: 260.0, toFreq: 432.0, fromVol: 0.02, toVol: 0.25, duration: breatheInDuration)
        
        phaseTimer = Timer.scheduledTimer(withTimeInterval: breatheInDuration, repeats: false) { _ in
            DispatchQueue.main.async { startHoldPhase() }
        }
    }
    
    private func startHoldPhase() {
        breathPhase = .hold
        holdProgress = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        let interval: Double = 0.05
        let steps = holdDuration / interval
        var current: Double = 0
        
        // Gentle sustained tone during hold
        animateSound(fromFreq: 432.0, toFreq: 432.0, fromVol: 0.25, toVol: 0.15, duration: holdDuration / 2.0)
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                current += 1
                withAnimation(.linear(duration: interval)) {
                    holdProgress = min(CGFloat(current / steps), 1.0)
                }
                
                if current >= steps {
                    timer.invalidate()
                    startBreatheOutPhase()
                }
            }
        }
    }
    
    private func startBreatheOutPhase() {
        breathPhase = .breatheOut
        holdProgress = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.easeInOut(duration: breatheOutDuration)) {
            orbScale = 0.6
            orbOpacity = 0.5
            glowRadius = 15
        }
        
        animateSound(fromFreq: 432.0, toFreq: 260.0, fromVol: 0.15, toVol: 0.0, duration: breatheOutDuration)
        
        phaseTimer = Timer.scheduledTimer(withTimeInterval: breatheOutDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                completedCycles += 1
                startBreathCycle()
            }
        }
    }
    
    // MARK: - Procedural Sound Animation
    private func animateSound(fromFreq: Double, toFreq: Double, fromVol: Double, toVol: Double, duration: Double) {
        soundTimer?.invalidate()
        let interval: Double = 1.0 / 30.0
        let steps = duration / interval
        var currentStep: Double = 0
        
        soundGen.frequency = fromFreq
        soundGen.volume = fromVol
        
        soundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                currentStep += 1
                if currentStep >= steps {
                    timer.invalidate()
                    self.soundGen.frequency = toFreq
                    self.soundGen.volume = toVol
                } else {
                    let progress = currentStep / steps
                    // Ease-in-out interpolation
                    let eased = 0.5 * (1.0 - cos(.pi * progress))
                    self.soundGen.frequency = fromFreq + (toFreq - fromFreq) * eased
                    self.soundGen.volume = fromVol + (toVol - fromVol) * eased
                }
            }
        }
    }
    
    // MARK: - Gradient Animation
    private func startGradientAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { timer in
            DispatchQueue.main.async {
                gradientAngle += 0.02
            }
        }
    }
    
    // MARK: - Music
    private func startMusic() {
        var musicUrl: URL?
        let preferredExtensions = ["caf", "mp3", "wav", "aiff", "m4a"]
        
        // 1. Check folder reference path first
        for ext in preferredExtensions {
            if let url = Bundle.main.url(forResource: "Rain Sound", withExtension: ext, subdirectory: "sounds/Nature") {
                musicUrl = url
                break
            }
        }
        // 2. Check flat bundle (fallback)
        if musicUrl == nil {
            for ext in preferredExtensions {
                if let url = Bundle.main.url(forResource: "Rain Sound", withExtension: ext) {
                    musicUrl = url
                    break
                }
            }
        }
        // 3. Fallback to Documents/AppSupport if downloaded dynamically
        if musicUrl == nil,
           let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
           let bundleId = Bundle.main.bundleIdentifier {
            for ext in preferredExtensions where musicUrl == nil {
                let hostedPath = appSupport.appendingPathComponent(bundleId)
                    .appendingPathComponent("HostedAssets/sounds/Nature/Rain Sound.\(ext)")
                if FileManager.default.fileExists(atPath: hostedPath.path) {
                    musicUrl = hostedPath
                } else {
                    let fallbackPath = appSupport.appendingPathComponent("HostedAssets/sounds/Nature/Rain Sound.\(ext)")
                    if FileManager.default.fileExists(atPath: fallbackPath.path) {
                        musicUrl = fallbackPath
                    }
                }
            }
        }
        
        if let url = musicUrl {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 0.4
                audioPlayer?.play()
                print("[BreathingExercise] Playing music from \(url)")
            } catch {
                print("[BreathingExercise] Music error: \(error)")
            }
        } else {
            print("[BreathingExercise] Could not find meditation music in bundle or documents")
        }
    }
    
    private func stopMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - Particle System

struct BreathingParticle {
    let startX: CGFloat
    let startY: CGFloat
    let radius: CGFloat
    let maxAlpha: Double
    let lifetime: Double
    let phase: Double
    let createdAt: TimeInterval
}

class ParticleSystem {
    var particles: [BreathingParticle] = []
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.addParticle()
            self?.removeOldParticles()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func addParticle() {
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let screenHeight: CGFloat = UIScreen.main.bounds.height
        
        let particle = BreathingParticle(
            startX: CGFloat.random(in: 0...screenWidth),
            startY: CGFloat.random(in: screenHeight * 0.5...screenHeight),
            radius: CGFloat.random(in: 1.5...4),
            maxAlpha: Double.random(in: 0.15...0.4),
            lifetime: Double.random(in: 4...8),
            phase: Double.random(in: 0...(.pi * 2)),
            createdAt: Date.timeIntervalSinceReferenceDate
        )
        particles.append(particle)
    }
    
    private func removeOldParticles() {
        let now = Date.timeIntervalSinceReferenceDate
        particles.removeAll { now - $0.createdAt > $0.lifetime }
    }
}
