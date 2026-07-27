//
//  EditItemView.swift
//  MenuTimer
//
//  SwiftUI form for editing an existing timer, alarm, stopwatch or pomodoro.
//  Pre-fills all fields from the current item and recalculates fire dates
//  from `now` on save (so changing a running timer's duration resets its
//  countdown from the moment you save).
//

import SwiftUI

/// Form for editing an existing item.
public struct EditItemView: View {

    /// Called with the updated values. The caller recalculates fireDate etc.
    public let onSave: (EditValues) -> Void
    /// Called when the user cancels.
    public let onCancel: () -> Void

    // ── Timer fields ──
    @State private var timerHours = 0
    @State private var timerMinutes = 5
    @State private var timerRepeatEnabled = false
    @State private var timerRepeatInfinite = false
    @State private var timerRepeatCount = 4

    // ── Alarm fields ──
    @State private var alarmFireDate: Date = Date()
    @State private var alarmSnoozeEnabled = false
    @State private var alarmSnoozeMinutes = 5
    @State private var alarmSnoozeInfinite = false
    @State private var alarmSnoozeCount = 3

    // ── Pomodoro fields ──
    @State private var pomoWorkHours = 0
    @State private var pomoWorkMinutes = 25
    @State private var pomoBreakMinutes = 5
    @State private var pomoInfinite = false
    @State private var pomoCycleCount = 4

    // ── Common ──
    @State private var title: String
    @FocusState private var titleFocused: Bool

    private let kind: ItemKind
    private let now: () -> Date

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    // ── Validators ──

    private var isTimerValid: Bool {
        let duration = TimeInterval(timerHours * 3_600 + timerMinutes * 60)
        return duration > 0 && !trimmedTitle.isEmpty
    }

    private var isAlarmValid: Bool {
        alarmFireDate > now() && !trimmedTitle.isEmpty
    }

    private var isPomodoroValid: Bool {
        let work = TimeInterval(pomoWorkHours * 3_600 + pomoWorkMinutes * 60)
        return work > 0 && !trimmedTitle.isEmpty
    }

    private var isStopwatchValid: Bool {
        !trimmedTitle.isEmpty
    }

    private var isValid: Bool {
        switch kind {
        public case .timer:     isTimerValid
        public case .alarm:     isAlarmValid
        public case .stopwatch: isStopwatchValid
        public case .pomodoro:  isPomodoroValid
        }
    }

    // ── Init ──

    public init(
        item: TimerItem,
        onSave: @escaping (EditValues) -> Void,
        onCancel: @escaping () -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.kind = item.kind
        self.onSave = onSave
        self.onCancel = onCancel
        self.now = now

        // Pre-fill common
        _title = State(initialValue: item.title)

        // Pre-fill kind-specific
        switch item.kind {
        public case .timer:
            let dur = item.configuredDuration ?? 0
            let h = Int(dur) / 3_600
            let m = (Int(dur) % 3_600) / 60
            _timerHours = State(initialValue: h)
            _timerMinutes = State(initialValue: max(m, 1))
            if let _ = item.repeatInterval {
                _timerRepeatEnabled = State(initialValue: true)
                _timerRepeatInfinite = State(initialValue: item.isInfinite)
                _timerRepeatCount = State(initialValue: item.remainingCycles ?? 4)
            }

        public case .alarm:
            _alarmFireDate = State(initialValue: item.fireDate)
            if let _ = item.repeatInterval {
                _alarmSnoozeEnabled = State(initialValue: true)
                _alarmSnoozeMinutes = State(initialValue: Int(item.repeatInterval! / 60))
                _alarmSnoozeInfinite = State(initialValue: item.isInfinite)
                _alarmSnoozeCount = State(initialValue: item.remainingCycles ?? 3)
            }

        public case .stopwatch:
            break // only title

        public case .pomodoro:
            let work = item.configuredDuration ?? 1500
            let h = Int(work) / 3_600
            let m = (Int(work) % 3_600) / 60
            _pomoWorkHours = State(initialValue: h)
            _pomoWorkMinutes = State(initialValue: max(m, 1))
            _pomoBreakMinutes = State(initialValue: Int(item.breakDuration / 60))
            _pomoInfinite = State(initialValue: item.isInfinite)
            _pomoCycleCount = State(initialValue: item.remainingCycles ?? 4)
        }
    }

    // ── Body ──

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            switch kind {
            public case .timer:     timerBody
            public case .alarm:     alarmBody
            public case .stopwatch: stopwatchBody
            public case .pomodoro:  pomodoroBody
            }

            buttons
        }
        .padding(20)
        .frame(width: kind == .alarm ? 370 : kind == .pomodoro ? 340 : 320)
        .onAppear { titleFocused = true }
    }

    // ── Header ──

    private var header: some View {
        let label: String
        switch kind {
        public case .timer:     label = "Edit Timer"
        public case .alarm:     label = "Edit Alarm"
        public case .stopwatch: label = "Edit Stopwatch"
        public case .pomodoro:  label = "Edit Pomodoro"
        }
        return Text(label)
            .font(.headline)
    }

    // ── Timer body ──

    private var timerBody: some View {
        Group {
            HStack(spacing: 12) {
                durationField("Hours", value: $timerHours, range: 0...23)
                durationField("Minutes", value: $timerMinutes, range: 1...59)
            }

            TextField("Description", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            Toggle(isOn: $timerRepeatEnabled) {
                Text("Repeat").font(.subheadline)
            }
            .toggleStyle(.switch)

            if timerRepeatEnabled {
                repeatPicker(
                    infinite: $timerRepeatInfinite,
                    count: $timerRepeatCount
                )
            }
        }
    }

    // ── Alarm body ──

    private var alarmBody: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fires at")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "Fires at",
                    selection: $alarmFireDate,
                    in: now()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.field)
                .labelsHidden()
            }

            TextField("Description", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            if !title.isEmpty && alarmFireDate <= now() {
                Text("Pick a time in the future.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle(isOn: $alarmSnoozeEnabled) {
                Text("Repeat (snooze)").font(.subheadline)
            }
            .toggleStyle(.switch)

            if alarmSnoozeEnabled {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Every").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("min", value: $alarmSnoozeMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 56)
                                .multilineTextAlignment(.trailing)
                            Stepper("", value: $alarmSnoozeMinutes, in: 1...1440)
                                .labelsHidden()
                            Text("min")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    repeatPicker(
                        infinite: $alarmSnoozeInfinite,
                        count: $alarmSnoozeCount
                    )
                }
                .padding(.leading, 20)
            }
        }
    }

    // ── Stopwatch body ──

    private var stopwatchBody: some View {
        TextField("Description", text: $title)
            .textFieldStyle(.roundedBorder)
            .focused($titleFocused)
    }

    // ── Pomodoro body ──

    private var pomodoroBody: some View {
        Group {
            HStack(spacing: 12) {
                durationField("Work h", value: $pomoWorkHours, range: 0...23)
                durationField("Work min", value: $pomoWorkMinutes, range: 1...59)
            }

            HStack(spacing: 12) {
                durationField("Break min", value: $pomoBreakMinutes, range: 1...59)
            }

            TextField("Description", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            Toggle(isOn: $pomoInfinite) {
                Text("Infinite cycles").font(.subheadline)
            }
            .toggleStyle(.switch)

            if !pomoInfinite {
                HStack {
                    Text("Cycles:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Stepper("\(pomoCycleCount)", value: $pomoCycleCount, in: 1...99)
                }
                .padding(.leading, 20)
            }
        }
    }

    // ── Shared components ──

    private func durationField(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(label, value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                Stepper(label, value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    private func repeatPicker(
        infinite: Binding<Bool>,
        count: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cycles").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Picker("", selection: infinite) {
                    Text("\\(count.wrappedValue) times").tag(false)
                    Text("∞ Infinite").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if !infinite.wrappedValue {
                    Stepper("", value: count, in: 1...999)
                        .labelsHidden()
                }
            }
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Save", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
    }

    // ── Submit ──

    private func submit() {
        guard isValid else { return }

        let values: EditValues
        switch kind {
        public case .timer:
            let duration = TimeInterval(timerHours * 3_600 + timerMinutes * 60)
            let repeatInterval: TimeInterval? = timerRepeatEnabled ? duration : nil
            let cycles: Int? = timerRepeatEnabled ? (timerRepeatInfinite ? nil : timerRepeatCount) : nil
            values = EditValues(
                title: trimmedTitle,
                timerDuration: duration,
                repeatInterval: repeatInterval,
                remainingCycles: cycles
            )

        public case .alarm:
            let snoozeSeconds: TimeInterval? = alarmSnoozeEnabled ? TimeInterval(alarmSnoozeMinutes * 60) : nil
            let cycles: Int? = alarmSnoozeEnabled ? (alarmSnoozeInfinite ? nil : alarmSnoozeCount) : nil
            values = EditValues(
                title: trimmedTitle,
                alarmFireDate: alarmFireDate,
                repeatInterval: snoozeSeconds,
                remainingCycles: cycles
            )

        public case .stopwatch:
            values = EditValues(title: trimmedTitle)

        public case .pomodoro:
            let work = TimeInterval(pomoWorkHours * 3_600 + pomoWorkMinutes * 60)
            let brk = TimeInterval(pomoBreakMinutes * 60)
            let cycles: Int? = pomoInfinite ? nil : pomoCycleCount
            values = EditValues(
                title: trimmedTitle,
                pomoWorkDuration: work,
                pomoBreakDuration: brk,
                remainingCycles: cycles
            )
        }

        onSave(values)
    }
}

// MARK: - Edit values payload

/// Payload returned by `EditItemView` on save.
public struct EditValues {
    public let title: String

    // Timer
    public var timerDuration: TimeInterval?

    // Alarm
    public var alarmFireDate: Date?

    // Pomodoro
    public var pomoWorkDuration: TimeInterval?
    public var pomoBreakDuration: TimeInterval?

    // Shared
    public var repeatInterval: TimeInterval?
    public var remainingCycles: Int?

    public init(
        title: String,
        timerDuration: TimeInterval? = nil,
        alarmFireDate: Date? = nil,
        pomoWorkDuration: TimeInterval? = nil,
        pomoBreakDuration: TimeInterval? = nil,
        repeatInterval: TimeInterval? = nil,
        remainingCycles: Int? = nil
    ) {
        self.title = title
        self.timerDuration = timerDuration
        self.alarmFireDate = alarmFireDate
        self.pomoWorkDuration = pomoWorkDuration
        self.pomoBreakDuration = pomoBreakDuration
        self.repeatInterval = repeatInterval
        self.remainingCycles = remainingCycles
    }
}

#if DEBUG
#Preview("Timer") {
    EditItemView(
        item: TimerItem.timer(title: "Pasta", duration: 300),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Alarm") {
    EditItemView(
        item: TimerItem.alarm(title: "Standup", fireDate: Date().addingTimeInterval(3600)),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Stopwatch") {
    EditItemView(
        item: TimerItem.stopwatch(title: "Meeting"),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Pomodoro") {
    EditItemView(
        item: TimerItem.pomodoro(title: "Deep Work", workDuration: 1500, breakDuration: 300, cycles: 4),
        onSave: { _ in },
        onCancel: {}
    )
}
#endif
