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
    case dismissed   // < 7 — not displayed as a petal
    case almost      // 7-9 — reached for it
    case settled     // 10-14 — landed the practice
    case zen         // 15+ — lingered

    init(breaths: Int) {
        switch breaths {
        case ..<7: self = .dismissed
        case 7...9: self = .almost
        case 10...14: self = .settled
        default: self = .zen
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .dismissed:
            return LinearGradient(
                colors: [Color(white: 0.6), Color(white: 0.45)],
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
        case .dismissed: return Color.black.opacity(0.20)
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
