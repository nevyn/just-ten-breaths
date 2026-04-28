import SwiftUI

// MARK: - Day Flower

/// A flower whose petals = sessions completed today.
/// Petals appear chronologically clockwise from 12 o'clock.
/// Up to 7 petals fill the outer ring; petals 8-14 fill an inner ring; 15+ fill a third inner ring.
struct DayFlowerView: View {
    let sessions: [BreathingSession]
    var size: CGFloat = 180
    /// When true, show "no breaths yet today" text in the empty state. Mini flowers should suppress this.
    var showsEmptyText: Bool = true

    private let petalsPerRing = 7

    var body: some View {
        ZStack {
            // Three rings, populated in chronological order
            ForEach(Array(displayedSessions.enumerated()), id: \.offset) { index, session in
                petal(for: session, at: index)
            }

            if displayedSessions.isEmpty && showsEmptyText {
                Text("no breaths yet today")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else if displayedSessions.isEmpty {
                // Mini flower empty state: a single tiny dot so the layout doesn't collapse.
                Circle()
                    .fill(Color.gray.opacity(0.18))
                    .frame(width: size * 0.08, height: size * 0.08)
            }
        }
        .frame(width: size, height: size)
    }

    /// Sessions that earned a petal (>= almost bucket).
    private var displayedSessions: [BreathingSession] {
        sessions.filter { $0.bucket != .dismissed }
    }

    @ViewBuilder
    private func petal(for session: BreathingSession, at index: Int) -> some View {
        let ring = index / petalsPerRing
        let positionInRing = index % petalsPerRing
        let totalInThisRing = min(displayedSessions.count - ring * petalsPerRing, petalsPerRing)
        // Petals fill clockwise from 12 o'clock as the day progresses.
        let angle = Double(positionInRing) * 360.0 / Double(petalsPerRing)

        let ringScale: CGFloat = ring == 0 ? 1.0 : (ring == 1 ? 0.78 : 0.58)
        let ringOffset: CGFloat = (size * 0.13) * ringScale
        let petalWidth: CGFloat = (size * 0.36) * ringScale
        let petalHeight: CGFloat = (size * 0.38) * ringScale

        LeafPetal()
            .fill(session.bucket.gradient)
            .opacity(ring == 0 ? 0.85 : 0.75)
            .frame(width: petalWidth, height: petalHeight)
            .shadow(color: session.bucket.shadowColor, radius: 5 * ringScale, y: 2)
            .offset(y: -ringOffset - petalHeight / 2)
            .rotationEffect(.degrees(angle))
            .transition(.scale.combined(with: .opacity))
            .id("\(index)-\(totalInThisRing)")
    }
}

// MARK: - Week Flower Row

/// Seven mini day-flowers, one per weekday. Sizes adapt to available width.
struct WeekFlowerRow: View {
    let week: [(label: String, sessions: [BreathingSession])]

    private let spacing: CGFloat = 4
    private let maxMiniSize: CGFloat = 88
    private let labelHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let mini = min(maxMiniSize, (geo.size.width - spacing * 6) / 7)
            HStack(spacing: spacing) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 8) {
                        DayFlowerView(sessions: day.sessions, size: mini, showsEmptyText: false)
                            .frame(width: mini, height: mini)
                        Text(day.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: maxMiniSize + 8 + labelHeight)
    }
}

// MARK: - Week × Hour Grid

/// 7 columns (days) × N rows (work hours). Cell color = best session that hour.
struct WeekHourGridView: View {
    let week: [(label: String, sessions: [BreathingSession])]
    let workHours: ClosedRange<Int>  // e.g. 8...17

    private let cellSize: CGFloat = 22
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(spacing: cellSpacing) {
            // Day-of-week headers
            HStack(spacing: cellSpacing) {
                Text("")
                    .frame(width: 28, alignment: .trailing)
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    Text(day.label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: cellSize)
                }
            }

            // One row per hour
            ForEach(Array(workHours), id: \.self) { hour in
                HStack(spacing: cellSpacing) {
                    Text(hourLabel(hour))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, alignment: .trailing)

                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        cell(for: day.sessions, hour: hour)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(h)\(hour < 12 ? "a" : "p")"
    }

    @ViewBuilder
    private func cell(for sessions: [BreathingSession], hour: Int) -> some View {
        let cal = Calendar.current
        let hourSessions = sessions.filter { cal.component(.hour, from: $0.startedAt) == hour }
        let best = hourSessions.map { $0.bucket }.max(by: bucketRank)

        RoundedRectangle(cornerRadius: 4)
            .fill(best?.gradient ?? LinearGradient(colors: [Color.gray.opacity(0.08)], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }

    private func bucketRank(_ a: SessionBucket, _ b: SessionBucket) -> Bool {
        rank(a) < rank(b)
    }

    private func rank(_ b: SessionBucket) -> Int {
        switch b {
        case .dismissed: return 0
        case .almost: return 1
        case .settled: return 2
        case .zen: return 3
        }
    }
}

// MARK: - Calendar Heatmap

/// 8-week trailing heatmap. Cell intensity = total breaths that day.
/// Layout: columns = weeks (oldest left), rows = weekdays (Mon top, Sun bottom).
struct CalendarHeatmapView: View {
    let days: [(date: Date, totalBreaths: Int)]  // ordered oldest → newest

    private let cellSize: CGFloat = 20
    private let cellSpacing: CGFloat = 4
    private let labelColumnWidth: CGFloat = 24
    /// Mon-first for European convention (matches the work-days picker in Settings).
    private let weekdayLabels = ["Mon", "", "Wed", "", "Fri", "", "Sun"]

    var body: some View {
        // Group into weeks (columns), days within week as rows (Mon-Sun).
        let weeks = groupedByWeek(days: days)
        let maxBreaths = max(1, days.map { $0.totalBreaths }.max() ?? 1)

        VStack(alignment: .leading, spacing: cellSpacing) {
            // Month labels along the top
            HStack(spacing: cellSpacing) {
                Text("")
                    .frame(width: labelColumnWidth)
                ForEach(Array(weeks.enumerated()), id: \.offset) { i, week in
                    Text(monthLabel(for: week, previousWeek: i > 0 ? weeks[i - 1] : nil))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: cellSize, alignment: .leading)
                }
            }

            // 7 rows: one per weekday
            ForEach(0..<7, id: \.self) { rowIndex in
                HStack(spacing: cellSpacing) {
                    Text(weekdayLabels[rowIndex])
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: labelColumnWidth, alignment: .trailing)

                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        // Mon=2 ... Sun=1 in Calendar; map row 0=Mon ... row 6=Sun.
                        let weekdayValue = rowIndex == 6 ? 1 : rowIndex + 2
                        let day = week.first(where: { Calendar.current.component(.weekday, from: $0.date) == weekdayValue })
                        cell(for: day, max: maxBreaths)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    private func monthLabel(for week: [(date: Date, totalBreaths: Int)], previousWeek: [(date: Date, totalBreaths: Int)]?) -> String {
        guard let firstDate = week.first?.date else { return "" }
        let cal = Calendar.current
        let thisMonth = cal.component(.month, from: firstDate)
        if let prev = previousWeek?.first?.date {
            let prevMonth = cal.component(.month, from: prev)
            if prevMonth == thisMonth { return "" }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: firstDate)
    }

    @ViewBuilder
    private func cell(for day: (date: Date, totalBreaths: Int)?, max: Int) -> some View {
        if let day, day.totalBreaths > 0 {
            let intensity = min(1.0, Double(day.totalBreaths) / Double(max))
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.78, blue: 0.50).opacity(0.30 + intensity * 0.70),
                            Color(red: 0.25, green: 0.65, blue: 0.40).opacity(0.30 + intensity * 0.70),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.08))
        }
    }

    private func groupedByWeek(days: [(date: Date, totalBreaths: Int)]) -> [[(date: Date, totalBreaths: Int)]] {
        let cal = Calendar.current
        var weeks: [[(date: Date, totalBreaths: Int)]] = []
        var current: [(date: Date, totalBreaths: Int)] = []
        var lastWeekOfYear: Int? = nil

        for day in days {
            let week = cal.component(.weekOfYear, from: day.date)
            if week != lastWeekOfYear, !current.isEmpty {
                weeks.append(current)
                current = []
            }
            current.append(day)
            lastWeekOfYear = week
        }
        if !current.isEmpty { weeks.append(current) }
        return weeks
    }
}

// MARK: - Patterns Section

struct PatternsSection: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.50).opacity(0.7))
                        .padding(.top, 3)
                    Text(insight)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Smaller header for sub-sections within a major section.
private struct SubsectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Whole Panel

struct BreathingHistoryPrototypeView: View {
    let today: [BreathingSession]
    let week: [(label: String, sessions: [BreathingSession])]
    let workHours: ClosedRange<Int>
    let calendar: [(date: Date, totalBreaths: Int)]
    let insights: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 56) {
                // Today
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Today", subtitle: todayCaption)
                    DayFlowerView(sessions: today, size: 240)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                // This week — two related visualizations under one header
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeader(title: "This week")

                    VStack(alignment: .leading, spacing: 8) {
                        SubsectionHeader(title: "One petal per session")
                        WeekFlowerRow(week: week)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SubsectionHeader(title: "Hour by hour — color = best session that hour")
                        WeekHourGridView(week: week, workHours: workHours)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }

                // Calendar
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Recent weeks", subtitle: "intensity = breaths that day")
                    CalendarHeatmapView(days: calendar)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Patterns
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Patterns")
                    PatternsSection(insights: insights)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 440, idealWidth: 500)
        .background(.ultraThinMaterial)
    }

    private var todayCaption: String {
        let counted = today.filter { $0.bucket != .dismissed }
        guard !counted.isEmpty else { return "a fresh day" }
        let zen = counted.filter { $0.bucket == .zen }.count
        let settled = counted.filter { $0.bucket == .settled }.count
        let almost = counted.filter { $0.bucket == .almost }.count
        var parts: [String] = ["\(counted.count) session\(counted.count == 1 ? "" : "s")"]
        if zen > 0 { parts.append("\(zen) \(SessionBucket.zen.displayName)") }
        if settled > 0 { parts.append("\(settled) \(SessionBucket.settled.displayName)") }
        if almost > 0 { parts.append("\(almost) \(SessionBucket.almost.displayName)") }
        return parts.joined(separator: "  •  ")
    }
}

// MARK: - Mock Data (preview-only)

extension BreathingSession {
    /// Convenience for previews and mock data. Back-derives `duration` from a target breath count
    /// so the @Model's computed `breaths` field comes out right.
    static func mock(date: Date, breaths: Int, cadence: Double = 4.0) -> BreathingSession {
        let duration = TimeInterval(breaths) * cadence * 2.0
        return BreathingSession(startedAt: date, duration: duration, cadence: cadence)
    }
}

private enum MockData {
    static func today(seed: Int) -> [BreathingSession] {
        var rng = SeededRNG(seed: seed)
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        var sessions: [BreathingSession] = []
        let hours: [Int] = [9, 10, 11, 13, 15]
        for hour in hours {
            let breaths = [3, 7, 8, 10, 11, 13, 15, 18].randomElement(using: &rng)!
            let date = cal.date(byAdding: .hour, value: hour, to: startOfDay)!
            sessions.append(.mock(date: date, breaths: breaths))
        }
        return sessions
    }

    static func emptyDay() -> [BreathingSession] { [] }

    static func zenDay() -> [BreathingSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (8...17).map { hour in
            .mock(date: cal.date(byAdding: .hour, value: hour, to: start)!, breaths: 12 + (hour % 5))
        }
    }

    static func week(seed: Int) -> [(label: String, sessions: [BreathingSession])] {
        var rng = SeededRNG(seed: seed)
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let monday = cal.date(byAdding: .day, value: -(cal.component(.weekday, from: today) - 2), to: today) ?? today

        return labels.enumerated().map { i, label in
            let dayStart = cal.date(byAdding: .day, value: i, to: monday)!
            let sessionCount = [0, 1, 2, 3, 4, 5, 6, 8].randomElement(using: &rng)!
            var sessions: [BreathingSession] = []
            for _ in 0..<sessionCount {
                let hour = (8...17).randomElement(using: &rng)!
                let breaths = [4, 7, 8, 10, 11, 12, 14, 16].randomElement(using: &rng)!
                let date = cal.date(byAdding: .hour, value: hour, to: dayStart)!
                sessions.append(.mock(date: date, breaths: breaths))
            }
            return (label, sessions)
        }
    }

    static func calendar(seed: Int, weeks: Int = 8) -> [(date: Date, totalBreaths: Int)] {
        var rng = SeededRNG(seed: seed)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totalDays = weeks * 7
        return (0..<totalDays).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7)
            let total = isWeekend
                ? [0, 0, 0, 0, 5, 12].randomElement(using: &rng)!
                : [0, 0, 8, 14, 20, 30, 45, 60, 80, 110].randomElement(using: &rng)!
            return (date, total)
        }
    }

    static let insights: [String] = [
        "You complete most often around 10am.",
        "Tuesdays are your strongest weekday so far.",
        "After a long pause, you usually go zen.",
    ]
}

// Tiny seedable RNG so previews are stable across reloads.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) | 1 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Previews

#Preview("Whole Panel") {
    BreathingHistoryPrototypeView(
        today: MockData.today(seed: 7),
        week: MockData.week(seed: 13),
        workHours: 8...17,
        calendar: MockData.calendar(seed: 21),
        insights: MockData.insights
    )
    .frame(width: 500, height: 1400)
}

#Preview("Day Flower — empty") {
    DayFlowerView(sessions: MockData.emptyDay(), size: 200)
        .padding(40)
        .background(.ultraThinMaterial)
}

#Preview("Day Flower — partial") {
    DayFlowerView(sessions: MockData.today(seed: 7), size: 200)
        .padding(40)
        .background(.ultraThinMaterial)
}

#Preview("Day Flower — zen overflow") {
    DayFlowerView(sessions: MockData.zenDay(), size: 200)
        .padding(40)
        .background(.ultraThinMaterial)
}

#Preview("Week Flower Row") {
    WeekFlowerRow(week: MockData.week(seed: 13))
        .padding(24)
        .frame(width: 380)
        .background(.ultraThinMaterial)
}

#Preview("Hour Grid") {
    WeekHourGridView(week: MockData.week(seed: 13), workHours: 8...17)
        .padding(24)
        .background(.ultraThinMaterial)
}

#Preview("Calendar Heatmap") {
    CalendarHeatmapView(days: MockData.calendar(seed: 21))
        .padding(24)
        .background(.ultraThinMaterial)
}
