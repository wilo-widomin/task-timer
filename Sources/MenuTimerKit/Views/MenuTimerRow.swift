import SwiftUI

/// SwiftUI row for a single timer/alarm/stopwatch/pomodoro item in the popover.
public struct MenuTimerRow: View {
    private let item: TimerItem
    private let now: Date

    public init(item: TimerItem, now: Date) {
        self.item = item
        self.now = now
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
        }
        .padding(.vertical, 3)
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