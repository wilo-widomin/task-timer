# Menu Timer

macOS menubar app for timers & alarms.

## Architecture

- **Hybrid AppKit + SwiftUI**: AppKit (NSStatusItem, NSMenu) for the menubar, SwiftUI (NSHostingController) for forms and About window.
- **Fire date absolute truth**: remaining = fireDate - Date.now. Always derived, never stored.
- **JSON persistence** via Codable in ~/Library/Application Support/MenuTimer/store.json
- **Single 1Hz tick engine** refreshes all running items
- **macOS 13+** minimum target
- **LSUIElement = YES** (agent app, no Dock)

## Models

TimerItem: id, kind(.timer/.alarm), title, createdAt, fireDate, configuredDuration(only timer), state(.running/.finished), didNotify

## Code Standards

- Swift 5.9+
- @MainActor for UI, async/await for persistence
- MVVM: TimerStore (ObservableObject) as single source of truth
- Write atomic JSON (Data.write with .atomic option)
- Tests for models, persistence, and scheduling

## Version Management (CRITICAL)

- **Every commit that touches production code MUST bump MARKETING_VERSION** first.
- The version lives in `project.pbxproj` in 4 places (Debug + Release × app target + test target).
- Semver: bugfix = patch (+1), new feature = minor (+1.0), breaking = major (+1.0.0).
- Always update all 4 occurrences to the same value before committing.
- Current version: 1.0.1.
- Commits that changed code without bumping: 3f3b154, ef0542c (left at 1.0.1 — should have been 1.0.2).