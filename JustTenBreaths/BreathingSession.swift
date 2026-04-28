import Foundation
import SwiftData
import SwiftUI

// MARK: - Persistence Model

/// One completed (or attempted) breathing session.
///
/// `breaths` is denormalized at insert time so bucket-based predicates stay simple.
/// `duration` and `cadence` are kept so the count can be recomputed if the formula changes.
@Model
final class BreathingSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var duration: TimeInterval
    /// Seconds per inhale at the time the session ended.
    var cadence: Double
    /// Floor of duration / (cadence * 2). Stored to keep queries trivial.
    var breaths: Int

    init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval, cadence: Double) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.cadence = cadence
        self.breaths = Self.breathCount(duration: duration, cadence: cadence)
    }

    static func breathCount(duration: TimeInterval, cadence: Double) -> Int {
        guard cadence > 0, duration > 0 else { return 0 }
        return Int(duration / (cadence * 2.0))
    }

    var bucket: SessionBucket { SessionBucket(breaths: breaths) }
}

// MARK: - Bucket

/// Quality bucket for a session, derived from the number of breaths completed.
/// Boundaries are deliberate product choices — see the breathing history prototype discussion.
enum SessionBucket {
    case dismissed   // < 5 — clicked but bailed; high-stress signal, not a petal
    case almost      // 5-9 — reached for it
    case settled     // 10-14 — landed the practice
    case zen         // 15+ — lingered

    init(breaths: Int) {
        switch breaths {
        case ..<5: self = .dismissed
        case 5...9: self = .almost
        case 10...14: self = .settled
        default: self = .zen
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .dismissed:
            // Warm grey leaning rust — reads as "tired/strained" against ultraThinMaterial,
            // distinct from the empty/unlogged state.
            return LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.56, blue: 0.56),
                    Color(red: 0.80, green: 0.46, blue: 0.46),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .almost:
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.80, blue: 0.40),
                    Color(red: 0.85, green: 0.65, blue: 0.20),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .settled:
            // Same green as the breathing flower
            return LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.78, blue: 0.50),
                    Color(red: 0.25, green: 0.65, blue: 0.40),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .zen:
            return LinearGradient(
                colors: [
                    Color(red: 0.65, green: 0.48, blue: 0.85),
                    Color(red: 0.50, green: 0.32, blue: 0.72),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    var shadowColor: Color {
        switch self {
        case .dismissed: return Color(red: 0.40, green: 0.20, blue: 0.20).opacity(0.30)
        case .almost: return Color(red: 0.55, green: 0.40, blue: 0.10).opacity(0.35)
        case .settled: return Color(red: 0.15, green: 0.40, blue: 0.25).opacity(0.35)
        case .zen: return Color(red: 0.30, green: 0.18, blue: 0.50).opacity(0.35)
        }
    }

    var displayName: String {
        switch self {
        case .dismissed: return "dismissed"
        case .almost: return "almost"
        case .settled: return "settled"
        case .zen: return "zen"
        }
    }
}

/// Solid color (not a gradient) for small dismiss indicators — base dots on the day flower,
/// corner pips in the hour grid, corner dots in the calendar heatmap. Matches the dismissed
/// gradient's tone so the visual identity is consistent across surfaces.
extension Color {
    static let dismissTint = Color(red: 0.92, green: 0.56, blue: 0.56)
}
