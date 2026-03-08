import Foundation

struct BreathingSettings: Codable, Equatable {
    var startHour: Int = 8
    var startMinute: Int = 0
    var endHour: Int = 17
    var endMinute: Int = 0
    var workDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    var launchAtLogin: Bool = false
    /// Duration of one inhale (or exhale) in seconds. Full cycle = cadence × 2.
    var breathingCadence: Double = 4.0
    /// Whether to log completed breathing sessions (≥60s) to Apple Health as mindfulness minutes.
    var logToHealth: Bool = false
    /// Set to true once the user has seen and dismissed the first-launch onboarding window.
    var hasCompletedOnboarding: Bool = false
    
    enum Weekday: Int, Codable, CaseIterable, Identifiable {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
        
        
        var id: Int { rawValue }

        /// Days ordered by the user's locale (e.g. Monday-first in most of Europe, Sunday-first in the US).
        static var localeOrdered: [Weekday] {
            let first = Calendar.current.firstWeekday  // 1 = Sunday, 2 = Monday, ...
            return allCases.sorted { a, b in
                let aIdx = (a.rawValue - first + 7) % 7
                let bIdx = (b.rawValue - first + 7) % 7
                return aIdx < bIdx
            }
        }
        
        var shortName: String {
            switch self {
            case .monday: "Mon"
            case .tuesday: "Tue"
            case .wednesday: "Wed"
            case .thursday: "Thu"
            case .friday: "Fri"
            case .saturday: "Sat"
            case .sunday: "Sun"
            }
        }
        
        var fullName: String {
            switch self {
            case .sunday: "Sunday"
            case .monday: "Monday"
            case .tuesday: "Tuesday"
            case .wednesday: "Wednesday"
            case .thursday: "Thursday"
            case .friday: "Friday"
            case .saturday: "Saturday"
            }
        }
    }
    
    func isWithinWorkHours(date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        
        guard let hour = components.hour,
              let minute = components.minute,
              let weekdayValue = components.weekday,
              let weekday = Weekday(rawValue: weekdayValue) else {
            return false
        }
        
        // Check if it's a work day
        guard workDays.contains(weekday) else {
            return false
        }
        
        // Convert to minutes since midnight for easier comparison
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + self.startMinute
        let endMinutes = endHour * 60 + self.endMinute
        
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }
    
    func isBreathingTime(date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        
        // Trigger at 55-59 minutes (5 minutes before the hour)
        return minute >= 55
    }
}

// MARK: - UserDefaults Storage

extension BreathingSettings {
    private static let storageKey = "breathingSettings"
    
    static func load() -> BreathingSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(BreathingSettings.self, from: data) else {
            return BreathingSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
