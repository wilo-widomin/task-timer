# Menu Timer

macOS menubar app for timers, alarms & stopwatches.

## Architecture

- **Hybrid AppKit + SwiftUI**: AppKit (NSStatusItem, NSMenu) for the menubar, SwiftUI (NSHostingController) for forms and About window.
- **Fire date absolute truth**: remaining = fireDate - Date.now. Always derived, never stored.
- **JSON persistence** via Codable in ~/Library/Application Support/MenuTimer/store.json
- **Single 1Hz tick engine** refreshes all running items
- **macOS 13+** minimum target
- **LSUIElement = YES** (agent app, no Dock)

## Models

- `TimerItem`: id, kind(.timer/.alarm/.stopwatch/.pomodoro), title, createdAt, fireDate, configuredDuration(only timer/pomodoro), state(.running/.paused/.finished), didNotify, accumulatedElapsed, lastStartedDate, repeatInterval, remainingCycles, breakDuration, isBreakPhase
- **Timers & alarms**: `fireDate` is the single source of truth. remaining = fireDate - now.
- **Stopwatches**: elapsed is derived from `lastStartedDate` + `accumulatedElapsed`.
- **Repeating items**: when `repeatInterval` is set, the item resets its fireDate after firing instead of finishing. `remainingCycles` tracks remaining firings (nil = infinite).
- **Pomodoros**: `.pomodoro` items alternate between work (`configuredDuration`) and break (`breakDuration`). `isBreakPhase` tracks current phase. `remainingCycles` tracks work cycles remaining.

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
- Current version: 1.5.2.
- Commits that changed code without bumping: 3f3b154, ef0542c (left at 1.0.1 — should have been 1.0.2).

## Auto-bump hook

A `prepare-commit-msg` hook lives in `.githooks/` that **automatically bumps the version** using proper semver based on your commit message:

| Commit message | Bump | Ejemplo |
|---|---|---|
| `feat!: breaking change` | major+1, minor=0, patch=0 | 1.3.2 → 2.0.0 |
| `feat: new feature` | minor+1, patch=0 | 1.3.2 → 1.4.0 |
| `fix: bug fix` | patch+1 | 1.3.2 → 1.3.3 |
| chore/docs/refactor | no bump | — |

Activate it (one time):
```bash
git config core.hooksPath .githooks
```