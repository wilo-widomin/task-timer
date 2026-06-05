# Menu Timer

A native macOS menu-bar app for **timers** (countdown by duration) and **alarms**
(absolute time). No Dock icon — it lives entirely in the menu bar. State is
persisted to JSON and survives quits and restarts.

## Highlights

- **Hybrid AppKit + SwiftUI** — AppKit (`NSStatusItem` / `NSMenu`) for the menu
  bar, SwiftUI (`NSHostingController`) for the forms and the About window.
- **Fire-date as the single source of truth** — `remaining = fireDate - now`,
  always derived, never stored. This makes the app robust across sleep,
  reboots and clock drift.
- **JSON persistence** with atomic writes to
  `~/Library/Application Support/MenuTimer/store.json`.
- **Single 1 Hz tick engine** refreshes every running item.
- **User notifications** when a timer/alarm fires (idempotent).

## Requirements

- macOS 13 Ventura or later
- Xcode 16+ (Swift 5.9+)

## Building

```sh
open MenuTimer.xcodeproj
```

Select the **MenuTimer** scheme and run (⌘R). Tests: ⌘U.

> Note: this is a macOS app and can only be compiled with Xcode on macOS.

## Architecture

```
main.swift ──> AppDelegate ──> StatusItemController ──> MenuBuilder ──> TimerRowView
                   │                                          ▲
                   ├──> TimerStore (ObservableObject) ────────┘  (single source of truth)
                   │        │
                   │        ├──> JSONPersistenceService (atomic, background)
                   │        └──> FireScheduler + NotificationService
                   └──> TickEngine (1 Hz) ──> store.tick(now:)
```

See `CLAUDE.md` for the full design notes.
