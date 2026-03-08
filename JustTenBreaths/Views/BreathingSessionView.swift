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

    private let petalCount = 7

    var body: some View {
        // Continuous rotation independent of breathing phase
        let rotation1 = elapsed * 8    // ~45s per full turn
        let rotation2 = elapsed * -5   // counter-rotate, ~72s per full turn

        ZStack {
            // Layer 1: outer petals (green)
            ForEach(0..<petalCount, id: \.self) { index in
                let angle = Double(index) * 360.0 / Double(petalCount)
                let offset = 5.0 + expansion * 35.0

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
                    .frame(width: 26, height: 52)
                    .shadow(color: Color(red: 0.15, green: 0.40, blue: 0.25).opacity(0.35), radius: 5, y: 2)
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
            let offset = 3.0 + expansion2 * 28.0

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
                .frame(width: 22, height: 44)
                .shadow(color: Color(red: 0.15, green: 0.35, blue: 0.30).opacity(0.30), radius: 4, y: 1)
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

    /// Duration of one inhale (or exhale) in seconds — mutable so the in-session slider can adjust it.
    @State private var cadence: Double
    @State private var isHovering = false
    @State private var isDragging = false

    init(startDate: Date, cadence: Double, onDone: @escaping () -> Void, onCadenceChanged: ((Double) -> Void)? = nil) {
        self.startDate = startDate
        self.onDone = onDone
        self.onCadenceChanged = onCadenceChanged
        self._cadence = State(initialValue: cadence)
    }

    /// Full breathing cycle = inhale + exhale.
    private var cycleLength: Double { cadence * 2.0 }

    private var cadenceLabel: String {
        String(format: "Pace: %.1fs", cadence)
    }

    var body: some View {
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

                VStack(spacing: 16) {
                    ZStack {
                        Text("Breathe in…")
                            .opacity(inhaleOpacity)
                        Text("Breathe out…")
                            .opacity(exhaleOpacity)
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: 20)

                    PetalFlowerView(expansion: expansion, elapsed: elapsed, cycleLength: cycleLength)
                        .frame(width: 160, height: 160)

                    Button(action: onDone) {
                        Text("Done breathing")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.40, green: 0.72, blue: 0.55))
                }
                .padding(.horizontal, 30)
                .padding(.top, 32)  // 12pt arrow + 20pt visual padding
                .padding(.bottom, 16)
            }

            // Tempo slider — always in the layout (keeps window size stable),
            // fades in only when the mouse is over the window.
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
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
            .opacity(isHovering ? 0.6 : 0.01)
            .animation(.easeInOut(duration: 0.25), value: isHovering)
        }
        .frame(width: 250)
        .background(.ultraThinMaterial, in: PopoverShape())
        .onHover { isHovering = $0 }
        .onChange(of: cadence) { _, newValue in
            onCadenceChanged?(newValue)
        }
    }
}
