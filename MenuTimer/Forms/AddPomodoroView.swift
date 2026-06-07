//
//  AddPomodoroView.swift
//  MenuTimer
//
//  SwiftUI form for creating a pomodoro timer. The pomodoro technique alternates
//  between work sessions and short breaks, with a configurable number of cycles.
//

import SwiftUI

/// Form for creating a new pomodoro timer.
struct AddPomodoroView: View {

    /// Called with work duration (seconds), break duration, cycles (nil = infinite),
    /// and trimmed title.
    let onSubmit: (TimeInterval, TimeInterval, Int?, String) -> Void
    /// Called when the user cancels.
    let onCancel: () -> Void

    @State private var workHours = 0
    @State private var workMinutes = 25
    @State private var breakMinutes = 5
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    @State private var infinite = false
    @State private var cycleCount = 4

    private var workDuration: TimeInterval {
        TimeInterval(workHours * 3_600 + workMinutes * 60)
    }

    private var breakDuration: TimeInterval {
        TimeInterval(breakMinutes * 60)
    }

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    private var isValid: Bool {
        workDuration > 0 && !trimmedTitle.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Pomodoro")
                .font(.headline)

            // Work duration
            HStack(spacing: 12) {
                durationField("Work h", value: $workHours, range: 0...23)
                durationField("Work min", value: $workMinutes, range: 1...59)
            }

            // Break duration
            HStack(spacing: 12) {
                durationField("Break min", value: $breakMinutes, range: 1...59)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. Deep Work", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
                    .onSubmit(submitIfValid)
            }

            // Cycles
            Toggle(isOn: $infinite) {
                Text("Infinite cycles")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)

            if !infinite {
                HStack {
                    Text("Cycles:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Stepper("\(cycleCount)", value: $cycleCount, in: 1...99)
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
        .frame(width: 340)
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
        let cycles: Int? = infinite ? nil : cycleCount
        onSubmit(workDuration, breakDuration, cycles, trimmedTitle)
    }
}

#if DEBUG
#Preview {
    AddPomodoroView(onSubmit: { _, _, _, _ in }, onCancel: {})
}
#endif