import SwiftUI

// MARK: - Leaf Petal Shape

/// A teardrop/leaf shape matching the app icon silhouette.
struct LeafPetal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Tip at top center
        path.move(to: CGPoint(x: w * 0.5, y: 0))

        // Right side curve down to base
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.85, y: h * 0.25),
            control2: CGPoint(x: w * 0.75, y: h * 0.8)
        )

        // Left side curve back up to tip
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.25, y: h * 0.8),
            control2: CGPoint(x: w * 0.15, y: h * 0.25)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Popover Shape

/// A rounded rectangle with an upward-pointing arrow at the top center,
/// drawn as a single continuous path so the material fills seamlessly.
struct PopoverShape: Shape {
    var cornerRadius: CGFloat = 20
    var arrowWidth: CGFloat = 24
    var arrowHeight: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + arrowHeight,
            width: rect.width,
            height: rect.height - arrowHeight
        )
        let cr = cornerRadius
        let arrowMidX = rect.midX
        let arrowHalfW = arrowWidth / 2

        var path = Path()

        // Start at top-left corner of body (after corner radius)
        path.move(to: CGPoint(x: bodyRect.minX + cr, y: bodyRect.minY))

        // Top edge to left base of arrow
        path.addLine(to: CGPoint(x: arrowMidX - arrowHalfW, y: bodyRect.minY))

        // Arrow: up to tip, down to right base
        path.addLine(to: CGPoint(x: arrowMidX, y: rect.minY))
        path.addLine(to: CGPoint(x: arrowMidX + arrowHalfW, y: bodyRect.minY))

        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: bodyRect.maxX - cr, y: bodyRect.minY))

        // Top-right corner
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cr, y: bodyRect.minY + cr),
            radius: cr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )

        // Right edge to bottom-right corner
        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - cr))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cr, y: bodyRect.maxY - cr),
            radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: bodyRect.minX + cr, y: bodyRect.maxY))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cr, y: bodyRect.maxY - cr),
            radius: cr, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )

        // Left edge to top-left corner
        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + cr))

        // Top-left corner
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cr, y: bodyRect.minY + cr),
            radius: cr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Petal Flower View

/// A Mindfulness-style animated flower with two layers of leaf petals.
/// The layers rotate continuously for a sense of progression, while the
/// expansion/contraction loops in cadence with the breathing cycle.
struct PetalFlowerView: View {
    let expansion: Double
    let elapsed: Double
    let cycleLength: Double
    /// Multiplier for all sizes. 1.0 = base popover size, >1 for fullscreen.
    var scale: CGFloat = 1.0

    private let petalCount = 7

    var body: some View {
        // Continuous rotation independent of breathing phase
        let rotation1 = elapsed * 8    // ~45s per full turn
        let rotation2 = elapsed * -5   // counter-rotate, ~72s per full turn

        ZStack {
            // Layer 1: outer petals (green)
            ForEach(0..<petalCount, id: \.self) { index in
                let angle = Double(index) * 360.0 / Double(petalCount)
                let offset = (5.0 + expansion * 35.0) * scale

                LeafPetal()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.78, blue: 0.50),
                                Color(red: 0.25, green: 0.65, blue: 0.40),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.75)
                    .frame(width: 26 * scale, height: 52 * scale)
                    .shadow(color: Color(red: 0.15, green: 0.40, blue: 0.25).opacity(0.35), radius: 5 * scale, y: 2 * scale)
                    .offset(y: -offset)
                    .rotationEffect(.degrees(angle + rotation1))
            }

            // Layer 2: inner petals (teal, with slight timing offset)
            petalLayer2(rotation: rotation2)
        }
        .scaleEffect(0.88 + expansion * 0.12)
    }

    private func petalLayer2(rotation: Double) -> some View {
        let phase2 = -cos((elapsed - 0.4) * .pi * 2.0 / cycleLength)
        let expansion2 = phase2 * 0.5 + 0.5
        let halfAngle = 360.0 / Double(petalCount) / 2.0

        return ForEach(0..<petalCount, id: \.self) { index in
            let angle = Double(index) * 360.0 / Double(petalCount) + halfAngle
            let offset = (3.0 + expansion2 * 28.0) * scale

            LeafPetal()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.75, blue: 0.70),
                            Color(red: 0.35, green: 0.60, blue: 0.58),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.65)
                .frame(width: 22 * scale, height: 44 * scale)
                .shadow(color: Color(red: 0.15, green: 0.35, blue: 0.30).opacity(0.30), radius: 4 * scale, y: 1 * scale)
                .offset(y: -offset)
                .rotationEffect(.degrees(angle + rotation))
        }
    }
}

// MARK: - Breathing Session View

/// The guided breathing UI shown as a floating panel.
struct BreathingSessionView: View {
    let startDate: Date
    let onDone: () -> Void
    let onCadenceChanged: ((Double) -> Void)?
    let onToggleFullscreen: ((Bool) -> Void)?

    /// Duration of one inhale (or exhale) in seconds — mutable so the in-session slider can adjust it.
    @State private var cadence: Double
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isFullscreen = false

    /// The highest threshold (5/10/15 breaths) we've fired a celebration for this session.
    /// Locked monotonic so a mid-session cadence change doesn't re-fire.
    @State private var highestThresholdReached: Int = 0
    @State private var flashColor: Color? = nil
    @State private var flashOpacity: Double = 0
    @State private var particles: [BreathingParticle] = []

    init(startDate: Date, cadence: Double, isFullscreen: Bool = false, onDone: @escaping () -> Void, onCadenceChanged: ((Double) -> Void)? = nil, onToggleFullscreen: ((Bool) -> Void)? = nil) {
        self.startDate = startDate
        self.onDone = onDone
        self.onCadenceChanged = onCadenceChanged
        self.onToggleFullscreen = onToggleFullscreen
        self._cadence = State(initialValue: cadence)
        self._isFullscreen = State(initialValue: isFullscreen)
    }

    /// Full breathing cycle = inhale + exhale.
    private var cycleLength: Double { cadence * 2.0 }

    private var cadenceLabel: String {
        String(format: "Pace: %.1fs", cadence)
    }

    private var backgroundShape: AnyShape {
        isFullscreen ? AnyShape(Rectangle()) : AnyShape(PopoverShape())
    }

    var body: some View {
        Group {
            if isFullscreen {
                GeometryReader { geo in
                    breathingContent(flowerSize: geo.size.height * 0.75)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                breathingContent(flowerSize: 160)
                    .frame(width: 250)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: toggleFullscreen) {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, isFullscreen ? 36 : 20)
            .padding(.trailing, 8)
            .opacity(isFullscreen ? 0.6 : (isHovering ? 0.8 : 0.01))
            .animation(.easeInOut(duration: 0.25), value: isHovering)
        }
        .background(.ultraThinMaterial, in: backgroundShape)
        .overlay {
            // Threshold celebration flash — clipped to the same shape as the background
            // so the wash respects the rounded popover corners.
            backgroundShape
                .fill(flashColor ?? .clear)
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .onHover { isHovering = $0 }
        .onChange(of: cadence) { _, newValue in
            onCadenceChanged?(newValue)
        }
    }

    private func breathingContent(flowerSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)

                // -cos starts at -1 (contracted), rises to +1 (expanded)
                let breathPhase = -cos(elapsed * .pi * 2.0 / cycleLength)
                let expansion = breathPhase * 0.5 + 0.5
                // Text opacity: fade through zero at phase transitions
                let s = sin(elapsed * .pi * 2.0 / cycleLength)
                let inhaleOpacity = max(0, min(1, (s - 0.15) * 5.0))
                let exhaleOpacity = max(0, min(1, (-s - 0.15) * 5.0))
                let breathsCompleted = Int(elapsed / cycleLength)

                VStack(spacing: isFullscreen ? 32 : 16) {
                    ZStack {
                        Text("Breathe in…")
                            .opacity(inhaleOpacity)
                        Text("Breathe out…")
                            .opacity(exhaleOpacity)
                    }
                    .font(.system(size: isFullscreen ? 24 : 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: isFullscreen ? 30 : 20)

                    PetalFlowerView(expansion: expansion, elapsed: elapsed, cycleLength: cycleLength, scale: flowerSize / 160)
                        .frame(width: flowerSize, height: flowerSize)
                        .overlay {
                            // Particles emanate from the flower's center on settled/zen crossings.
                            ForEach(particles) { particle in
                                BreathingParticleView(particle: particle)
                            }
                        }
                        .onTapGesture(count: 2) { toggleFullscreen() }

                    Button(action: onDone) {
                        Text("Done breathing")
                            .font(.system(size: isFullscreen ? 16 : 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.40, green: 0.72, blue: 0.55))
                }
                .padding(.horizontal, 30)
                .padding(.top, isFullscreen ? 40 : 32)
                .padding(.bottom, 16)
                .onChange(of: breathsCompleted) { _, newValue in
                    checkThresholds(breathsCompleted: newValue)
                }
            }

            tempoSlider
        }
    }

    // MARK: - Threshold celebrations

    private func checkThresholds(breathsCompleted: Int) {
        if breathsCompleted >= 15, highestThresholdReached < 15 {
            highestThresholdReached = 15
            triggerCelebration(threshold: 15)
        } else if breathsCompleted >= 10, highestThresholdReached < 10 {
            highestThresholdReached = 10
            triggerCelebration(threshold: 10)
        } else if breathsCompleted >= 5, highestThresholdReached < 5 {
            highestThresholdReached = 5
            triggerCelebration(threshold: 5)
        }
    }

    private func triggerCelebration(threshold: Int) {
        switch threshold {
        case 5:
            // Almost: just a soft yellow wash.
            triggerFlash(Color(red: 1.0, green: 0.92, blue: 0.55))
        case 10:
            // Settled: green wash + a gentle burst of green particles.
            triggerFlash(Color(red: 0.65, green: 0.95, blue: 0.75))
            emitParticles(color: Color(red: 0.40, green: 0.78, blue: 0.55), count: 8)
        case 15:
            // Zen: lavender wash + a denser purple burst.
            triggerFlash(Color(red: 0.85, green: 0.72, blue: 1.0))
            emitParticles(color: Color(red: 0.65, green: 0.48, blue: 0.85), count: 14)
        default:
            break
        }
    }

    private func triggerFlash(_ color: Color) {
        flashColor = color
        flashOpacity = 0
        withAnimation(.easeOut(duration: 0.4)) { flashOpacity = 0.20 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.9)) { flashOpacity = 0 }
        }
    }

    private func emitParticles(color: Color, count: Int) {
        let newParticles = (0..<count).map { _ in
            BreathingParticle(
                color: color,
                angle: Double.random(in: 0..<(2 * .pi)),
                distance: CGFloat.random(in: 60...140),
                size: CGFloat.random(in: 3.5...6.0)
            )
        }
        particles.append(contentsOf: newParticles)
        let ids = Set(newParticles.map { $0.id })
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            particles.removeAll { ids.contains($0.id) }
        }
    }

    private var tempoSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "hare")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Slider(value: $cadence, in: 2...10, step: 0.5, onEditingChanged: { isDragging = $0 })
                .overlay {
                    GeometryReader { geo in
                        let fraction = (cadence - 2.0) / (10.0 - 2.0)
                        let thumbR: CGFloat = 8.5
                        let thumbCenterX = thumbR + fraction * (geo.size.width - thumbR * 2)

                        Text(cadenceLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: Capsule())
                            .fixedSize()
                            .position(x: thumbCenterX, y: geo.size.height / 2)
                            .offset(y: -24)
                            .opacity(isDragging ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isDragging)
                            .allowsHitTesting(false)
                    }
                }
            Image(systemName: "tortoise")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: isFullscreen ? 230 : .infinity)
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
        .opacity(isHovering ? 0.6 : 0.01)
        .animation(.easeInOut(duration: 0.25), value: isHovering)
    }

    private func toggleFullscreen() {
        isFullscreen.toggle()
        onToggleFullscreen?(isFullscreen)
    }
}

// MARK: - Particles

/// One emitted celebration particle. Each renders as a small circle that drifts outward
/// from the flower's center along `angle` while fading.
struct BreathingParticle: Identifiable {
    let id = UUID()
    let color: Color
    let angle: Double      // radians
    let distance: CGFloat  // final distance from origin
    let size: CGFloat
}

private struct BreathingParticleView: View {
    let particle: BreathingParticle
    @State private var phase: Double = 0  // 0 = at origin, 1 = fully drifted out + faded

    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .offset(x: cos(particle.angle) * particle.distance * phase,
                    y: sin(particle.angle) * particle.distance * phase)
            .opacity(1.0 - phase)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6)) { phase = 1.0 }
            }
    }
}

#Preview("Popover") {
    BreathingSessionView(startDate: Date(), cadence: 4.0, onDone: {})
        .frame(width: 250, height: 350)
}

#Preview("Fullscreen") {
    BreathingSessionView(startDate: Date(), cadence: 4.0, isFullscreen: true, onDone: {})
        .frame(width: 1200, height: 800)
}
