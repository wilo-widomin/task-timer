//
//  AddAlarmView.swift
//  MenuTimer
//
//  SwiftUI form for creating an absolute-time alarm. Supports snooze/repeat
//  behaviour: after firing, the alarm resets to fire again after the snooze
//  interval, up to a configurable number of cycles.
//

import SwiftUI

/// Form for creating a new alarm at an absolute date/time.
public struct AddAlarmView: View {

    /// Called with the absolute fire date, trimmed title, snooze interval
    /// (nil = no repeat), and total cycles (nil = infinite).
    public let onSubmit: (Date, String, TimeInterval?, Int?) -> Void
    /// Called when the user cancels.
    public let onCancel: () -> Void

    /// Injectable clock for deterministic previews/tests.
    public var now: () -> Date = { Date() }

    @State private var fireDate: Date
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    @State private var snoozeEnabled = false
    @State private var snoozeMinutes = 5
    @State private var snoozeInfinite = false
    @State private var snoozeCount = 3

    public init(
        onSubmit: @escaping (Date, String, TimeInterval?, Int?) -> Void,
        onCancel: @escaping () -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.now = now
        _fireDate = State(initialValue: now().addingTimeInterval(300))
    }

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    private var isValid: Bool {
        FormValidation.isValidAlarm(fireDate: fireDate, title: title, now: now())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Alarm")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Fires at")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "Fires at",
                    selection: $fireDate,
                    in: now()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.field)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. Standup", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
                    .onSubmit(submitIfValid)
            }

            if !title.isEmpty && fireDate <= now() {
                Text("Pick a time in the future.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // ── Snooze / Repeat ──────────────────────────────
            Toggle(isOn: $snoozeEnabled) {
                Text("Repeat (snooze)")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)

            if snoozeEnabled {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Every")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            TextField("min", value: $snoozeMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 56)
                                .multilineTextAlignment(.trailing)
                            Stepper("", value: $snoozeMinutes, in: 1...1440)
                                .labelsHidden()
                            Text("min")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cycles")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Picker("", selection: $snoozeInfinite) {
                                Text("\(snoozeCount) times").tag(false)
                                Text("∞ Infinite").tag(true)
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()

                            if !snoozeInfinite {
                                Stepper("", value: $snoozeCount, in: 1...999)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.leading, 20)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Start", action: submitIfValid)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { titleFocused = true }
    }

    private func submitIfValid() {
        guard isValid else { return }
        public let snoozeSeconds: TimeInterval? = snoozeEnabled ? TimeInterval(snoozeMinutes * 60) : nil
        public let cycles: Int? = snoozeEnabled ? (snoozeInfinite ? nil : snoozeCount) : nil
        onSubmit(fireDate, trimmedTitle, snoozeSeconds, cycles)
    }
}

#if DEBUG
#Preview {
    AddAlarmView(onSubmit: { _, _, _, _ in }, onCancel: {})
}
#endif