import Foundation
import HealthKit

/// Thin wrapper around HKHealthStore for logging mindfulness sessions.
/// All methods are @MainActor — callers live on the main actor and
/// HKHealthStore dispatches internally as needed.
///
/// Note: if the project fails to link HealthKit at build time, open Xcode >
/// Target > General > Frameworks, Libraries, and Embedded Content > + >
/// HealthKit.framework  (usually not needed — it auto-links on macOS 13+).
@MainActor
final class HealthKitManager {

    private let store = HKHealthStore()

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func authorizationStatus() -> HKAuthorizationStatus {
        guard isAvailable,
              let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else { return .notDetermined }
        return store.authorizationStatus(for: mindfulType)
    }

    /// Presents the system authorization sheet. Throws on failure.
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.mindfulSessionTypeUnavailable
        }
        try await store.requestAuthorization(toShare: [mindfulType], read: [])
    }

    enum HealthKitError: LocalizedError {
        case unavailable
        case mindfulSessionTypeUnavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "HealthKit is not available on this device."
            case .mindfulSessionTypeUnavailable:
                "Mindful session type is not available."
            }
        }
    }

    // MARK: - Logging

    /// Saves a mindful session sample. Silent no-op if unavailable, unauthorized, or on error.
    func logMindfulSession(start: Date, end: Date) async {
        guard isAvailable,
              authorizationStatus() == .sharingAuthorized,
              let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await store.save(sample)
            print("HealthKit: logged mindful session \(end.timeIntervalSince(start))s")
        } catch {
            print("HealthKit save error: \(error)")
        }
    }
}
