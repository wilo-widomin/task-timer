import SwiftUI

/// Primary view for the MenuTimer module inside Widomin's popover.
public struct MenuTimerMainView: View {
    @ObservedObject private var store: TimerStore
    private let presenter: WindowPresenter

    public init(store: TimerStore, presenter: WindowPresenter) {
        self._store = ObservedObject(wrappedValue: store)
        self.presenter = presenter
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
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Self.sections) { section in
                            let items = store.items.filter { $0.kind == section.kind }
                            if !items.isEmpty {
                                Section {
                                    ForEach(items) { item in
                                        MenuTimerRow(
                                            item: item,
                                            now: Date(),
                                            onEdit: { edit(item) },
                                            onDelete: { store.remove(id: item.id) }
                                        )
                                    }
                                } header: {
                                    sectionHeader(section.title)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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

    /// The list is grouped by kind, in this fixed order. Empty groups are skipped,
    /// so the order stays stable no matter what the user creates first.
    private struct KindSection: Identifiable {
        let kind: ItemKind
        let title: String
        var id: ItemKind { kind }
    }

    private static let sections: [KindSection] = [
        KindSection(kind: .timer, title: "Temporizadores"),
        KindSection(kind: .alarm, title: "Alarmas"),
        KindSection(kind: .pomodoro, title: "Pomodoros"),
        KindSection(kind: .stopwatch, title: "Cronómetros"),
    ]

    /// Plain text, no background: inside a translucent popover any material reads as
    /// a washed-out band, especially while the window is not key.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 1)
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
        let id = "add-timer"
        presenter.present(id: id, title: "Add Timer", root: AddTimerView(
            onSubmit: { [store, presenter] duration, title, interval, cycles in
                if let interval {
                    store.addRepeatingTimer(title: title, duration: duration, repeatInterval: interval, cycles: cycles, now: Date())
                } else {
                    store.addTimer(title: title, duration: duration, now: Date())
                }
                presenter.close(id: id)
            },
            onCancel: { [presenter] in presenter.close(id: id) }
        ))
    }

    private func addAlarm() {
        let id = "add-alarm"
        presenter.present(id: id, title: "Add Alarm", root: AddAlarmView(
            onSubmit: { [store, presenter] date, title, snooze, cycles in
                if let snooze {
                    store.addRepeatingAlarm(title: title, fireDate: date, snoozeInterval: snooze, cycles: cycles, now: Date())
                } else {
                    store.addAlarm(title: title, fireDate: date, now: Date())
                }
                presenter.close(id: id)
            },
            onCancel: { [presenter] in presenter.close(id: id) }
        ))
    }

    private func addStopwatch() {
        let id = "add-stopwatch"
        presenter.present(id: id, title: "Add Stopwatch", root: AddStopwatchView(
            onSubmit: { [store, presenter] title in
                store.addStopwatch(title: title, now: Date())
                presenter.close(id: id)
            },
            onCancel: { [presenter] in presenter.close(id: id) }
        ))
    }

    private func edit(_ item: TimerItem) {
        let id = "edit-\(item.id)"
        presenter.present(id: id, title: "Editar", root: EditItemView(
            item: item,
            onSave: { [store, presenter] values in
                applyEdit(store: store, item: item, values: values)
                presenter.close(id: id)
            },
            onCancel: { [presenter] in presenter.close(id: id) }
        ))
    }

    /// Routes the form values to the right `TimerStore` mutator. Stopwatches only
    /// carry a title — the rest of `EditValues` does not apply to them.
    private func applyEdit(store: TimerStore, item: TimerItem, values: EditValues) {
        let now = Date()
        switch item.kind {
        case .timer:
            store.updateTimer(
                id: item.id,
                title: values.title,
                duration: values.timerDuration ?? item.configuredDuration ?? 300,
                repeatInterval: values.repeatInterval,
                remainingCycles: values.remainingCycles,
                now: now
            )
        case .alarm:
            store.updateAlarm(
                id: item.id,
                title: values.title,
                fireDate: values.alarmFireDate ?? item.fireDate,
                repeatInterval: values.repeatInterval,
                remainingCycles: values.remainingCycles,
                now: now
            )
        case .pomodoro:
            store.updatePomodoro(
                id: item.id,
                title: values.title,
                workDuration: values.pomoWorkDuration ?? item.configuredDuration ?? 1500,
                breakDuration: values.pomoBreakDuration ?? item.breakDuration,
                remainingCycles: values.remainingCycles,
                now: now
            )
        case .stopwatch:
            store.updateItemTitle(id: item.id, title: values.title)
        }
    }

    private func addPomodoro() {
        let id = "add-pomodoro"
        presenter.present(id: id, title: "Add Pomodoro", root: AddPomodoroView(
            onSubmit: { [store, presenter] work, brk, cycles, title in
                store.addPomodoro(title: title, workDuration: work, breakDuration: brk, cycles: cycles, now: Date())
                presenter.close(id: id)
            },
            onCancel: { [presenter] in presenter.close(id: id) }
        ))
    }
}
