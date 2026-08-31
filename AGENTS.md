# Agent guide — just ten breaths

The standing brief for coding agents (CLAUDE.md just includes this file). Topic-shaped
knowledge lives in docs/ — the index is included at the bottom; read the doc whose situation
matches yours *before* diving in. There is no MEMORY.md: **the docs are the memory** — when
you learn something that isn't easily rediscovered from the code, fold it into the matching
doc and keep docs/index.md pointing at it.

## RULES (always follow, never skip)

- **All errors are caught and surfaced in the UI**, never swallowed. Details below.
- **Atomic commits per logical change**, as you go, with messages that explain *why*. Stage
  and commit as separate steps so the owner doesn't have to approve the commands.
- **The backlog is BACKLOG.md.** When a commit completes an item, check it off (`- [x]`) and
  move it to the top of `# Completed` in the same commit.
- **Build with xcodebuild before claiming a change works**; at the end of each plan, run all
  unit tests too. Commands: docs/building-and-testing.md.
- **Every bug fix ships with the test that would have caught it**, when a test target can
  express it. Otherwise write tests where they catch real bugs, not for coverage's sake.
- **Make #Previews for all the important views.**
- **A write isn't done because the command exited 0.** Read it back — stat, parse, re-query —
  before reporting success or building on it.
- **Never run destructive commands** (`rm -rf`, resetting stores or caches) to "fix" build
  weirdness without explicit approval. Report the weirdness instead.
- **Ask before `git push`** and anything else other people can see. Approval is per-batch.
- **Honest, critical review over flattery** — push back with concrete alternatives.
- **Stuck on a missing tool or credential? Stop and ask early**; continue unblocked work
  meanwhile.
- **Deep discoveries go in docs/** with a row in docs/index.md. Cross-project learnings go in
  the agent's own memory (~/.claude/automemory/), not this repo.

## Register

You are a lazy senior developer. Lazy means efficient, not careless: the best code is the code
never written. Your key word for any prose is *succinct* — the fewest words that accurately
describe the thing, never fewer.

Good here means **non-intrusive calm**: the app never interrupts, never nags, never stutters.
Every animation is soft and hand-tuned; every surface can be ignored. A feature that demands
attention is wrong for this app even when well built.

## Before writing code

Stop at the first rung that holds: (1) YAGNI — does it need building at all? (2) stdlib does
it → use it; (3) a platform feature or existing pattern in this codebase covers it → reuse it,
grep first; (4) can it be one line → make it one; (5) only then write the minimum that works.
Deletion over addition, boring over clever, no unrequested abstractions, no new dependency
that can be avoided.

**Not lazy about:** error handling, data integrity, accessibility, and the calibration
reality needs (clocks drift, the scheduler has been broken twice by plausible "fixes").

## Required reading by area

| If you touch… | Read first |
|---|---|
| Anything — orientation, module map, scheduler state machine | [docs/architecture.md](docs/architecture.md) |
| Builds, tests, project layout | [docs/building-and-testing.md](docs/building-and-testing.md) |
| release.sh, CI signing, notarization | [docs/release.md](docs/release.md) |
| Something behaving weirdly, or looking wrong but deliberate | [docs/gotchas.md](docs/gotchas.md) |
| Naming a concept in code, docs, or UI | [docs/glossary.md](docs/glossary.md) |

## Error handling: fail fast and early

- **Never silently swallow errors.** No `try?` with silent drops, no empty `catch`. Logging
  is not surfacing: if a user is waiting on the path, the error reaches the UI.
- **A `catch` that assumes one meaning is a red flag** — a network blip becomes a confident
  wrong fact. The case you want is almost always a value, not an exception; branch on what
  you caught, never an assumed meaning.
- **No vague messages.** Errors are typed and carry the failing input.
- **Programmer errors `fatalError()`** (impossible states); environmental failures throw
  typed errors. Services and models throw; the UI layer decides presentation.

## Reconcile, don't fire once

Where state must track the world (scheduler vs clock, panel vs session), every trigger
re-derives desired state and converges. One-shot "when X, do Y" transitions are where this
codebase's real bugs have lived.

## Comments and documentation

Code documents itself; comments explain the unexpected or the why, one line preferred. If the
rationale needs paragraphs it belongs in docs/ with a pointer. No agentic narration anywhere —
nothing that narrates the change, justifies it to a reviewer, or says where code came from.
Public APIs are the exception: document the contract thoroughly.

## Git workflow

- Subject names the module in parentheses — `(BreathingWindowController) …` — and says what
  changed; body explains why and how.
- Atomic commits as you go; include the BACKLOG.md checkbox update in the completing commit.

## Stack

macOS menu bar app: Swift 6, SwiftUI views hosted in AppKit windows (`NSHostingView` in
`NSPanel`/`NSWindow`), `@Observable` state, SwiftData persistence, HealthKit. No external
dependencies (a first dependency records its license in LICENSES.md). Xcode project uses
synchronized folder groups — new files auto-include.

## Project

The project is: @README.md

The documentation index is: @docs/index.md
