import Foundation
import SwiftUI
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
    
    let healthKitManager = HealthKitManager()

    private var timer: Timer?
    
    init() {
        self.settings = BreathingSettings.load()
        startScheduler()
        updateLaunchAtLogin()
    }
    
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
        guard settings.logToHealth, duration >= 60 else { return }
        Task { await healthKitManager.logMindfulSession(start: sessionStart, end: sessionEnd) }
    }

    /// Requests HealthKit write authorization when logToHealth is enabled.
    /// Silently disables the setting if HealthKit is unavailable on this device.
    func requestHealthKitAuthorizationIfNeeded() async {
        guard settings.logToHealth else { return }
        guard healthKitManager.isAvailable else {
            settings.logToHealth = false
            return
        }
        _ = await healthKitManager.requestAuthorization()
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
        } catch {
            // Silently fail - user can retry in settings
            print("Failed to update launch at login: \(error)")
        }
    }
}
