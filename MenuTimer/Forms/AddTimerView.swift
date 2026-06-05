//
//  AddTimerView.swift
//  MenuTimer
//
//  SwiftUI form for creating a countdown timer. Validates that the duration is
//  positive and the description is non-empty before allowing submission.
//

import SwiftUI

/// Form for creating a new countdown timer.
struct AddTimerView: View {

    /// Called with the configured duration (seconds) and trimmed title.
    let onSubmit: (TimeInterval, String) -> Void
    /// Called when the user cancels.
    let onCancel: () -> Void

    @State private var hours = 0
    @State private var minutes = 5
    @State private var title = ""
    @FocusState private var titleFocused: Bool

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
        onSubmit(duration, trimmedTitle)
    }
}

#if DEBUG
#Preview {
    AddTimerView(onSubmit: { _, _ in }, onCancel: {})
}
#endif
