import SwiftData
import SwiftUI

/// Data-aware wrapper around `BreathingHistoryPrototypeView`.
/// Owns the SwiftData fetch + the slicing/grouping the panel needs, so the prototype panel
/// stays a pure presentation component (and remains useful for design iteration with mock arrays).
struct BreathingHistoryView: View {
    let appState: AppState

    @Query(sort: \BreathingSession.startedAt, order: .reverse)
    private var sessions: [BreathingSession]

    var body: some View {
        BreathingHistoryPrototypeView(
            today: todaySessions,
            week: thisWeek,
            workHours: workHours,
            calendar: calendarTotals,
            insights: insights
        )
    }

    // MARK: - Slicing

    private var workHours: ClosedRange<Int> {
        appState.settings.startHour...appState.settings.endHour
    }

    private var todaySessions: [BreathingSession] {
        let cal = Calendar.current
        return sessions.filter { cal.isDateInToday($0.startedAt) }
    }

    /// Mon-Sun for the current week, with `BreathingSession` arrays per day.
    private var thisWeek: [(label: String, sessions: [BreathingSession])] {
        let cal = Calendar.current
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let monday = startOfThisWeek()

        return labels.enumerated().map { offset, label in
            let dayStart = cal.date(byAdding: .day, value: offset, to: monday)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let inDay = sessions.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            return (label, inDay)
        }
    }

    /// Trailing 8 weeks of days (oldest -> newest), with total breaths per day.
    private var calendarTotals: [(date: Date, totalBreaths: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totalDays = 8 * 7
        return (0..<totalDays).reversed().map { offset in
            let dayStart = cal.date(byAdding: .day, value: -offset, to: today)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let totalBreaths = sessions
                .filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
                .reduce(0) { $0 + $1.breaths }
            return (dayStart, totalBreaths)
        }
    }

    // MARK: - Insights

    private var insights: [String] {
        let qualifying = sessions.filter { $0.breaths >= 10 }
        guard qualifying.count >= 10 else {
            return ["Not enough data yet — keep breathing and patterns will appear here."]
        }
        var out: [String] = []
        if let hourPhrase = mostCommonCompletionHour(qualifying) {
            out.append(hourPhrase)
        }
        if let weekdayPhrase = bestWeekday(qualifying) {
            out.append(weekdayPhrase)
        }
        return out
    }

    private func mostCommonCompletionHour(_ qualifying: [BreathingSession]) -> String? {
        let cal = Calendar.current
        let counts = Dictionary(grouping: qualifying) { cal.component(.hour, from: $0.startedAt) }
            .mapValues { $0.count }
        guard let (hour, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        return "You complete most often around \(hourLabel(hour))."
    }

    private func bestWeekday(_ qualifying: [BreathingSession]) -> String? {
        let cal = Calendar.current
        let counts = Dictionary(grouping: qualifying) { cal.component(.weekday, from: $0.startedAt) }
            .mapValues { $0.count }
        guard let (weekday, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let formatter = DateFormatter()
        let name = formatter.weekdaySymbols[weekday - 1]  // Calendar weekday is 1-based with Sunday=1
        return "\(name)s are your strongest weekday so far."
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }

    private func startOfThisWeek() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // weekday is 1-based with Sunday=1 ... Saturday=7. We want Monday as the start.
        let weekday = cal.component(.weekday, from: today)
        let offsetToMonday = (weekday + 5) % 7  // Sun=6, Mon=0, Tue=1, ... Sat=5
        return cal.date(byAdding: .day, value: -offsetToMonday, to: today)!
    }
}

// MARK: - Preview

#Preview("Whole Panel — real data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: BreathingSession.self, configurations: config)
    let context = container.mainContext

    // Seed a realistic week + calendar of sessions.
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let monday = cal.date(byAdding: .day, value: -((cal.component(.weekday, from: today) + 5) % 7), to: today)!

    // This week: spread sessions across Mon-Fri
    for dayOffset in 0..<5 {
        guard let dayStart = cal.date(byAdding: .day, value: dayOffset, to: monday) else { continue }
        let counts = [3, 5, 1, 0, 4][dayOffset]
        for i in 0..<counts {
            let hour = 9 + i * 2
            let breaths = [4, 8, 11, 13, 17].randomElement()!
            // We back-derive duration from breaths so the @Model's computed `breaths` matches.
            let cadence = 4.0
            let duration = TimeInterval(breaths) * cadence * 2.0
            let date = cal.date(byAdding: .hour, value: hour, to: dayStart)!
            context.insert(BreathingSession(startedAt: date, duration: duration, cadence: cadence))
        }
    }

    // Older history for the heatmap
    for offset in 7..<55 {
        guard let dayStart = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
        let weekday = cal.component(.weekday, from: dayStart)
        let isWeekend = (weekday == 1 || weekday == 7)
        let count = isWeekend ? Int.random(in: 0...2) : Int.random(in: 0...5)
        for i in 0..<count {
            let breaths = [3, 7, 10, 12, 16].randomElement()!
            let cadence = 4.0
            let duration = TimeInterval(breaths) * cadence * 2.0
            let date = cal.date(byAdding: .hour, value: 9 + i, to: dayStart)!
            context.insert(BreathingSession(startedAt: date, duration: duration, cadence: cadence))
        }
    }

    return BreathingHistoryView(appState: AppState(modelContainer: container))
        .modelContainer(container)
        .frame(width: 540, height: 1100)
}
