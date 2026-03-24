# just ten breaths - Coding Standards

## RULES (always follow, never skip)
- All errors must be caught and forwarded so they can be surfaced in the UI.
- Always make atomic commits with detailed commit messages after each completed subtask. Do staging and committing as separate tasks so I don't have to approve the commands.
- Check off todo items in BACKLOG.md and put them into Completed at the bottom of the document. Include this change in the commit.
- Write unit tests when it makes sense. Especially when you fix a bug, see if you can write a unit test to make sure it doesn't happen again.
- Make #Previews for all the important views.
- Always build with xcodebuild to make sure things compile. Always verify that the app builds, and at the end of each plan, also run all unit tests with xcodebuild.
- Keep a MEMORY.md as a memory for you between sessions. Keep it under 100 lines. Focus on things you can't easily rediscover from code: architecture overview, build commands, non-obvious pitfalls/gotchas (where you'd waste time if you forgot), test infrastructure quirks, and user preferences. Don't document settled features in detail — you can read the code for those. Update with each commit.
- At the start of every new task, re-read AGENTS.md and MEMORY.md.

More details follow, but keep the above always in memory with highest priority.

## Git Workflow

* **Atomic commits per logical change.** Each distinct feature, fix, or refactor gets its own commit — do not bundle unrelated changes together.
* **Detailed commit messages.** The subject line names the module in parentheses and describes *what* changed. The body explains *why* and *how*.
* **Check off completed backlog items.** When a commit completes a BACKLOG.md item, include the checkbox update (`- [x]`) in the same commit, and move the item to the top of the "# Completed" section.

## Error Handling: Fail Fast and Early

* **Never silently swallow errors.** No `try?` with silent drops. No `catch { }` with empty bodies.
* **No vague error messages.** Errors should carry meaningful context about what failed and why.
* **Programmer errors should `fatalError()`.** If a code path represents a bug, use `fatalError()` or `preconditionFailure()`.
* **User-facing errors should be typed and descriptive.** Use custom error types. Include the failing input in the error message.
* **Propagate errors up to the UI layer.** Services and models throw; the UI layer decides how to present them.
