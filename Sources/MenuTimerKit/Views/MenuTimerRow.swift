import SwiftUI

/// SwiftUI row for a single timer/alarm/stopwatch/pomodoro item in the popover.
public struct MenuTimerRow: View {
    private let item: TimerItem
    private let now: Date
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?

    @State private var isHovering = false

    /// `onEdit`/`onDelete` are optional so the row stays usable as a read-only
    /// list item; the action buttons only appear when both are provided.
    public init(
        item: TimerItem,
        now: Date,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.now = now
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(timeDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(item.state == .finished ? .red : .primary)

            if let onEdit, let onDelete {
                HStack(spacing: 2) {
                    actionButton("pencil", help: "Editar", action: onEdit)
                    actionButton("trash", help: "Eliminar", action: onDelete)
                }
                // Reserved even when hidden so the time column never shifts.
                .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func actionButton(
        _ icon: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private var iconName: String {
        switch item.kind {
        case .timer: return "hourglass"
        case .alarm: return "alarm"
        case .stopwatch: return "stopwatch"
        case .pomodoro: return "leaf.fill"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .running: return .green
        case .paused: return .orange
        case .finished: return .red
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .timer: return item.isRepeating ? "Repeating" : "Timer"
        case .alarm: return item.isRepeating ? "Snoozing" : "Alarm"
        case .stopwatch: return "Stopwatch"
        case .pomodoro: return item.isBreakPhase ? "Break" : "Work"
        }
    }

    private var timeDisplay: String {
        switch item.kind {
        case .timer, .alarm, .pomodoro:
            if item.state == .finished { return "Done" }
            let remaining = max(0, item.fireDate.timeIntervalSince(now))
            return TimeFormatting.elapsed(remaining)
        case .stopwatch:
            return TimeFormatting.elapsed(item.elapsed(at: now))
        }
    }
}