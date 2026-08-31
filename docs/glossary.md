# Glossary

One canonical term per concept. When prose and this table disagree, this table wins.

| Term | Definition | Avoid |
| --- | --- | --- |
| breathing time | The :55–:59 window each hour when the icon pulses. | reminder window, nag time |
| primed | Scheduler armed: within work hours, reminders active. | enabled, active |
| done | User dismissed this hour's reminder (`markDone()`); un-primes until :00. | acknowledged, completed |
| session | One run of the breathing panel, persisted as `BreathingSession`. | exercise, workout |
| cadence | Duration of one inhale (or exhale) in seconds; cycle = 2 × cadence. | pace (UI label only), tempo |
| bucket | Session quality tier by breath count: dismissed <7, almost 7–9, settled 10–14, zen 15+. | grade, score |
| panel | The floating breathing window (NSPanel), popover- or fullscreen-sized. | popover, overlay |
| pulse | The animated menu-bar icon during breathing time. | throb, blink |
