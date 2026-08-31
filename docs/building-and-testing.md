# Building and testing

## Build

```bash
xcodebuild -project "just ten breaths.xcodeproj" -scheme "just ten breaths" -configuration Debug build
```

- **Build without signing** (compile checks on machines with no Developer ID cert):
  append `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.
- Debug config uses Automatic signing; Release uses Manual (see release.md).

## Project layout

The project uses Xcode's `PBXFileSystemSynchronizedRootGroup`: new `.swift` files under
`JustTenBreaths/` auto-include in the target — no `project.pbxproj` edits for additions.

## Testing

There is **no test target yet** (adding one is on the backlog: bucket boundaries,
markDone-inserts-record with an in-memory `ModelContainer`). Until then, verification is
building plus driving the app; window/CPU behavior can be probed from Bash with
`sample <pid>`, `CGWindowListCopyWindowInfo` via `swift -e`, and System Events clicks on the
status item.

## Debug helpers

- Hidden "Test Animation" menu item in debug builds toggles breathing time.
