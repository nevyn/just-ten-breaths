# Todo

- [ ] Breathing history feature: "Breathing history…" menu item opens a translucent panel with Today (petal flower, one petal per session, color = bucket: yellow=almost 7-9, green=got it 10-14, purple=zen 15+), This Week (mini flower row + 7×N hour grid), Recent Weeks calendar heatmap, and Patterns insights. Prototype lives in `Views/BreathingHistoryPrototype.swift` for visual iteration before wiring data.
- [ ] Future: end-of-day mind-state check-in (single slider, optional, no notification) to enable correlation between session count and felt state. Owner wants to keep this app focused on "complement the felt sense" and uses external diary for mind-state today, but reconsider once the basic stats are in use.

# Completed

- [x] Auto-open breathing window setting (opens immediately at breathing time)
- [x] SettingsView #Preview verified working
- [x] Persist fullscreen preference across sessions
- [x] Fullscreen mode for breathing window (button + double-click flower)
- [x] Log to console and display red error text for login item and HealthKit failures
- [x] Setting to change the breathe window appearance (dark/light/system/inverse system)
- [x] Clicking the menu bar icon when breathing should dismiss the breathe window instead of opening the menu
- [x] Fix provisioning profile and code signing after adding healthkit
