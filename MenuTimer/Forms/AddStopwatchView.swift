//
//  AddStopwatchView.swift
//  MenuTimer
//
//  SwiftUI form for creating a stopwatch. Unlike timers and alarms, a stopwatch
//  has no duration or fire date — it only needs a title. It starts counting
//  upward immediately from zero.
//

import SwiftUI

/// Form for creating a new stopwatch.
struct AddStopwatchView: View {

    /// Called with the trimmed title.
    let onSubmit: (String) -> Void
    /// Called when the user cancels.
    let onCancel: () -> Void

    @State private var title = ""
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String {
        FormValidation.normalizedTitle(title)
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Stopwatch")
                .font(.headline)

            Text("A stopwatch counts elapsed time from zero. You can pause and resume it from the menu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g. Meeting", text: $title)
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

    private func submitIfValid() {
        guard isValid else { return }
        onSubmit(trimmedTitle)
    }
}

#if DEBUG
#Preview {
    AddStopwatchView(onSubmit: { _ in }, onCancel: {})
}
#endif