# Gotchas

## Panel teardown must nil contentView

An orphaned `NSHostingView` with a `TimelineView(.animation)` keeps its display link (and the
whole panel) alive after `orderOut`, rendering an invisible window at full refresh rate
(~20% CPU forever). `BreathingWindowController.teardown` exists for this; route any new
dismissal path through it. One inert AppKit-cached window shell lingering after `close()` is
normal and costs nothing.

## Things that look wrong but aren't

- **Breathing panel appearance** defaults to dark (`.darkAqua`) but is user-configurable via
  `settings.appearanceStyle` (dark/light/system/inverse system).
- **Animation values in `StatusItemController`** (damping, burst timing, hue step of 137°)
  are hand-tuned over iterations. Don't "fix" them without visual testing.
- **The :55–:59 window is fixed** — not a bug, not a missing setting. Deliberate design
  constraint.
- **`LSUIElement = YES`** — no Dock icon by design. Don't add a `WindowGroup` scene.

## Scheduler

`markDone()` not re-priming the scheduler is intentional; see architecture.md. It's been
"fixed" (broken) at least twice.
