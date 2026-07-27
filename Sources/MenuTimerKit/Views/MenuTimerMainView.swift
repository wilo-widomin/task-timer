import SwiftUI

/// Primary view for the MenuTimer module inside Widomin's popover.
public struct MenuTimerMainView: View {
    @ObservedObject private var store: TimerStore

    public init(store: TimerStore) {
        self._store = ObservedObject(wrappedValue: store)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Sin temporizadores")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.items) { item in
                            MenuTimerRow(item: item, now: Date())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            HStack(spacing: 12) {
                addBtn("Timer", icon: "hourglass") { addTimer() }
                addBtn("Alarma", icon: "alarm") { addAlarm() }
                addBtn("Crono", icon: "stopwatch") { addStopwatch() }
                addBtn("Pomodoro", icon: "leaf.fill") { addPomodoro() }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    private func addBtn(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func addTimer() {
        presentWindow(title: "Add Timer", root: AddTimerView(
            onSubmit: { duration, title, interval, cycles in
                if let interval {
                    store.addRepeatingTimer(title: title, duration: duration, repeatInterval: interval, cycles: cycles, now: Date())
                } else {
                    store.addTimer(title: title, duration: duration, now: Date())
                }
            },
            onCancel: {}
        ))
    }

    private func addAlarm() {
        presentWindow(title: "Add Alarm", root: AddAlarmView(
            onSubmit: { date, title, snooze, cycles in
                if let snooze {
                    store.addRepeatingAlarm(title: title, fireDate: date, snoozeInterval: snooze, cycles: cycles, now: Date())
                } else {
                    store.addAlarm(title: title, fireDate: date, now: Date())
                }
            },
            onCancel: {}
        ))
    }

    private func addStopwatch() {
        presentWindow(title: "Add Stopwatch", root: AddStopwatchView(
            onSubmit: { title in
                store.addStopwatch(title: title, now: Date())
            },
            onCancel: {}
        ))
    }

    private func addPomodoro() {
        presentWindow(title: "Add Pomodoro", root: AddPomodoroView(
            onSubmit: { work, brk, cycles, title in
                store.addPomodoro(title: title, workDuration: work, breakDuration: brk, cycles: cycles, now: Date())
            },
            onCancel: {}
        ))
    }

    private func presentWindow(title: String, root: some View) {
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = title
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}