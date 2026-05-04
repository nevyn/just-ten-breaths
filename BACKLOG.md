# Todo

- [ ] Future: end-of-day mind-state check-in (single slider, optional, no notification) to enable correlation between session count and felt state. Owner wants to keep this app focused on "complement the felt sense" and uses external diary for mind-state today, but reconsider once the basic stats are in use.
- [ ] When screen geometry changes, make sure fullscreen window adapts (size and position); or non-fullscreen window moves (position)
- [ ] Rename `Views/BreathingHistoryPrototype.swift` → `BreathingHistoryPanel.swift` now that it backs a real feature (deferred from the SwiftData migration to keep that diff focused).
- [ ] Add a `JustTenBreathsTests` target — at minimum, bucket-boundary tests on `SessionBucket(breaths:)` and a markDone-inserts-record test using an in-memory `ModelContainer`.
- [ ] Surface `persistenceError` and `healthKitError` in the History or Settings UI (they're set on `AppState` but not yet displayed).
- [ ] Settings: "Clear breathing history…" destructive action.
- [ ] Export breathing sessions to CSV.
- [ ] When changing pace during a breathing session, offset phase so that the animation doesn't jump while changing the slider.
- [ ] Iterate on breathing history window (general polish pass — proportions, spacing, color tuning, edge cases).
- [ ] Breathing history: paginate / toggle between weeks to see older historical data (the heatmap currently only shows the trailing 8 weeks).
- [ ] Add Sparkle / autoupdate. Look at how Melur (Nevyn's other macOS app) wired it for a working reference.

# Completed

- [x] Breathing history feature backed by SwiftData: "Breathing history…" menu item opens a translucent panel with Today (petal flower, color = bucket: amber=almost 7-9, green=settled 10-14, purple=zen 15+), This Week (mini flower row + 7×N hour grid), Recent Weeks calendar heatmap, and derived Patterns insights. Persists via `@Model BreathingSession`; data file is queryable with `sqlite3`.

- [x] Auto-open breathing window setting (opens immediately at breathing time)
- [x] SettingsView #Preview verified working
- [x] Persist fullscreen preference across sessions
- [x] Fullscreen mode for breathing window (button + double-click flower)
- [x] Log to console and display red error text for login item and HealthKit failures
- [x] Setting to change the breathe window appearance (dark/light/system/inverse system)
- [x] Clicking the menu bar icon when breathing should dismiss the breathe window instead of opening the menu
- [x] Fix provisioning profile and code signing after adding healthkit
