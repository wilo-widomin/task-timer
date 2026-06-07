//
//  AddTimerView.swift
//  MenuTimer
//
//  SwiftUI form for creating a countdown timer. Supports repeating timers
//  (pomodoro-style) with configurable cycles.
//

import SwiftUI

/// Form for creating a new countdown timer.
struct AddTimerView: View {

    /// Called with the configured duration (seconds), trimmed title,
    /// repeat interval (nil = no repeat), and total cycles (nil = infinite).
    let onSubmit: (TimeInterval, String, TimeInterval?, Int?) -> Void
    /// Called when the user cancels.
    let onCancel: () -> Void

    @State private var hours = 0
    @State private var minutes = 5
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    @State private var repeatEnabled = false
    @State private var repeatInfinite = false
    @State private var repeatCount = 4

    private var duration: TimeInterval {
        FormValidation.duration(hours: hours, minutes: minutes)
    }

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    private var isValid: Bool {
        FormValidation.isValidTimer(hours: hours, minutes: minutes, title: title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Timer")
                .font(.headline)

            HStack(spacing: 12) {
                durationField("Hours", value: $hours, range: 0...23)
                durationField("Minutes", value: $minutes, range: 0...59)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. Pasta", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
                    .onSubmit(submitIfValid)
            }

            // ── Repeat ─────────────────────────────────────────
            Toggle(isOn: $repeatEnabled) {
                Text("Repeat")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)

            if repeatEnabled {
                HStack {
                    Picker("", selection: $repeatInfinite) {
                        Text("\(repeatCount) times").tag(false)
                        Text("∞ Infinite").tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    if !repeatInfinite {
                        Stepper("", value: $repeatCount, in: 1...999)
                            .labelsHidden()
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
        .frame(width: 320)
        .onAppear { titleFocused = true }
    }

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

    private func submitIfValid() {
        guard isValid else { return }
        let repeatInterval: TimeInterval? = repeatEnabled ? duration : nil
        let cycles: Int? = repeatEnabled ? (repeatInfinite ? nil : repeatCount) : nil
        onSubmit(duration, trimmedTitle, repeatInterval, cycles)
    }
}

#if DEBUG
#Preview {
    AddTimerView(onSubmit: { _, _, _, _ in }, onCancel: {})
}
#endif