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