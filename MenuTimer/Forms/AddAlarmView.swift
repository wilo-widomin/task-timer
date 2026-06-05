//
//  AddAlarmView.swift
//  MenuTimer
//
//  SwiftUI form for creating an absolute-time alarm. Validates that the chosen
//  instant is in the future and the description is non-empty.
//

import SwiftUI

/// Form for creating a new alarm at an absolute date/time.
struct AddAlarmView: View {

    /// Called with the absolute fire date and trimmed title.
    let onSubmit: (Date, String) -> Void
    /// Called when the user cancels.
    let onCancel: () -> Void

    /// Injectable clock for deterministic previews/tests.
    var now: () -> Date = { Date() }

    @State private var fireDate: Date
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    init(
        onSubmit: @escaping (Date, String) -> Void,
        onCancel: @escaping () -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.now = now
        // Default to five minutes from now, rounded to the minute.
        _fireDate = State(initialValue: now().addingTimeInterval(300))
    }

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    private var isValid: Bool {
        FormValidation.isValidAlarm(fireDate: fireDate, title: title, now: now())
    }

    var body: some View {
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

    private func submitIfValid() {
        guard isValid else { return }
        onSubmit(fireDate, trimmedTitle)
    }
}

#if DEBUG
#Preview {
    AddAlarmView(onSubmit: { _, _ in }, onCancel: {})
}
#endif
