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

    /// Presents the system authorization sheet and returns whether write access was granted.
    func requestAuthorization() async -> Bool {
        guard isAvailable,
              let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
            return authorizationStatus() == .sharingAuthorized
        } catch {
            print("HealthKit authorization error: \(error)")
            return false
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
