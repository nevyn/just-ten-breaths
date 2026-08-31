# Architecture

just ten breaths is a macOS menu bar app for hourly breathing reminders. Core philosophy:
**non-intrusive**. No notifications, no alerts, no Dock icon (`LSUIElement = YES`) — just a
subtle icon pulse the user can ignore until they're ready.

## In one paragraph

`AppState` (@Observable) owns a 5-second polling timer and all mutable state. `AppDelegate`
wires `AppState` to the four AppKit controllers (`StatusItemController`,
`BreathingWindowController`, `SettingsWindowController`, `OnboardingWindowController`) using
`withObservationTracking`. Views are SwiftUI hosted inside AppKit windows — **don't try to
manage windows from SwiftUI scenes**, and don't add a `WindowGroup`.

## Scheduler state machine

Three booleans interact non-obviously across `AppState` and `BreathingSettings`:

- `isPrimed` — within work hours, reminders active
- `isBreathingTime` — it's :55–:59, show the pulse
- `breathingDone` — user dismissed this hour's reminder

`markDone()` does **not** re-prime the scheduler; only the clock rolling past :00 does. This
prevents the reminder re-firing within the same 5-minute window. If you touch scheduler logic,
read the comments in `AppState.updateScheduler()` carefully — it's been fixed at least twice.

## State and data

- **`@Observable`** (Swift 6 macro), not `ObservableObject`/`@Published`. Don't mix them.
- **Settings** are a JSON blob under `"breathingSettings"` in `UserDefaults.standard`. New
  fields with defaults decode safely from old JSON.
- **Breathing sessions** are SwiftData (`@Model BreathingSession`). The container lives on
  `AppDelegate`, is passed into `AppState`, forwarded to `BreathingHistoryWindowController`
  via `appState.modelContainer`. Inserts happen in `AppState.markDone`. The store is real
  SQLite at `~/Library/Containers/dev.nevyn.just-ten-breaths/Data/Library/Application
  Support/default.store` (`sqlite3 default.store "SELECT * FROM ZBREATHINGSESSION;"` works).
- **Bucket boundaries** live on `SessionBucket(breaths:)`: <7 dismissed (no petal), 7–9
  almost, 10–14 settled, 15+ zen. Deliberate product choices; check with the owner before
  changing.
- **HealthKit** — `HealthKitManager` wraps `HKHealthStore`. Sessions ≥60 s are logged as
  `mindfulSession`. Requires sandbox + HealthKit entitlements and a provisioning profile
  (even for Developer ID).
- **Onboarding** — one-time setup window (`settings.hasCompletedOnboarding`): work schedule,
  Launch at Login, Health opt-in.

## Dependencies

Exactly one: **Sparkle 2** (SPM) for autoupdate — license recorded in LICENSES.md. The
updater lives on `AppDelegate` (`SPUStandardUpdaterController`); the status menu's "Check
for updates…" item targets it directly. Feed and signing details: release.md. Don't add
further dependencies unless they earn their keep.

## Website

GitHub Pages at https://nevyn.github.io/just-ten-breaths/ (gh-pages branch, `.nojekyll`,
root source).
