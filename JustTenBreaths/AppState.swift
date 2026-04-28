import Foundation
import SwiftUI
import SwiftData
import ServiceManagement
import HealthKit

@Observable
@MainActor
final class AppState {
    /// Is it currently time for the user to take a breathing break?
    var isBreathingTime: Bool = false
    /// Whether we have already breathed this hour. Don't reactivate if the user does their breathing break before the hour has ended.
    var breathingTimeTriggeredThisHour: Bool = false

    /// Is the user interested in getting breathing reminders?
    var isPrimed: Bool = true
    /// Have we already auto-(un)-primed based on schedule this day? Then don't override user's settings
    var hasAutoPrimedDay: Int? = nil
    var hasAutoUnprimedDay: Int? = nil

    var settings: BreathingSettings {
        didSet {
            settings.save()
            updateLaunchAtLogin()
        }
    }

    /// Error message from the last failed login item registration/unregistration, or nil if successful.
    var loginItemError: String?
    /// Error message from the last failed HealthKit operation, or nil if successful.
    var healthKitError: String?
    /// Error message from the last failed local persistence operation, or nil if successful.
    var persistenceError: String?

    let healthKitManager = HealthKitManager()
    let modelContainer: ModelContainer

    private var timer: Timer?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.settings = BreathingSettings.load()
        startScheduler()
        updateLaunchAtLogin()
    }

    #if DEBUG
    /// Convenience for SwiftUI previews — uses an in-memory SwiftData container so previews don't touch disk.
    static func previewInstance() -> AppState {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: BreathingSession.self, configurations: config)
        return AppState(modelContainer: container)
    }
    #endif
    
    func cleanup() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Actions
    
    /// Call when the user finishes a breathing session.
    /// Pass real start/end dates from the breathing window to enable HealthKit logging;
    /// the default Date() args produce a zero-duration session that safely skips logging.
    func markDone(sessionStart: Date = Date(), sessionEnd: Date = Date()) {
        print("Done breathing.")
        isBreathingTime = false

        let duration = sessionEnd.timeIntervalSince(sessionStart)

        // Local persistence: log every session, including short dismisses, so the
        // history view can surface "how often did I bail" patterns.
        if duration > 0 {
            recordSession(startedAt: sessionStart, duration: duration)
        }

        // HealthKit: gated on user opt-in and the 60s minimum (mindful-session convention).
        guard settings.logToHealth, duration >= 60 else { return }
        Task { await healthKitManager.logMindfulSession(start: sessionStart, end: sessionEnd) }
    }

    private func recordSession(startedAt: Date, duration: TimeInterval) {
        let context = modelContainer.mainContext
        let session = BreathingSession(
            startedAt: startedAt,
            duration: duration,
            cadence: settings.breathingCadence
        )
        context.insert(session)
        do {
            try context.save()
            persistenceError = nil
        } catch {
            persistenceError = "Failed to save breathing session: \(error.localizedDescription)"
            print("SwiftData save error: \(error)")
        }
    }

    /// Requests HealthKit write authorization when logToHealth is enabled.
    /// Sets `healthKitError` on failure and disables the setting if HealthKit is unavailable.
    func requestHealthKitAuthorizationIfNeeded() async {
        guard settings.logToHealth else { return }
        do {
            try await healthKitManager.requestAuthorization()
            healthKitError = nil
        } catch {
            healthKitError = "Failed to set up HealthKit: \(error.localizedDescription)"
            settings.logToHealth = false
            print("HealthKit authorization error: \(error)")
        }
    }
    
    func togglePrimed() {
        isPrimed.toggle()
        if !isPrimed {
            print("Unpriming...")
            isBreathingTime = false
            hasAutoPrimedDay = Calendar.current.component(.day, from: Date())
        } else {
            print("Priming...")
            hasAutoUnprimedDay = Calendar.current.component(.day, from: Date())
        }
    }
    
    // MARK: - Scheduler
    
    private func startScheduler() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.checkPrimedWithinWorkingHours()
                // Only check for breathing time if we're active
                if self.isPrimed {
                    self.checkBreathingTime()
                }
            }
        }
    }
    
    private func checkPrimedWithinWorkingHours()
    {
        let now = Date()
        let day = Calendar.current.component(.day, from: now)
        let withinWorkingHours = settings.isWithinWorkHours(date: now)
        if !withinWorkingHours && isPrimed && hasAutoUnprimedDay != day {
            print("Workday ended. Unpriming.")
            isPrimed = false
            hasAutoUnprimedDay = day
        } else if withinWorkingHours && !isPrimed && hasAutoPrimedDay != day {
            print("Workday started. Priming.")
            isPrimed = true
            hasAutoPrimedDay = day
        }
    }
    
    private func checkBreathingTime() {
        let now = Date()
        let shouldBeBreathingTime = settings.isBreathingTime(date: now)
        if shouldBeBreathingTime && !isBreathingTime && !breathingTimeTriggeredThisHour {
            print("Time to breathe!")
            isBreathingTime = true
            breathingTimeTriggeredThisHour = true
        } else if breathingTimeTriggeredThisHour && !shouldBeBreathingTime {
            print("Getting ready to remind about breathing again.")
            // Breathing window has passed -- re-prime for next hour.
            breathingTimeTriggeredThisHour = false
        }
    }
    
    // MARK: - Launch at Login
    
    private func updateLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Failed to \(settings.launchAtLogin ? "register" : "unregister") login item: \(error.localizedDescription)"
            print("Failed to update launch at login: \(error)")
        }
    }
}
