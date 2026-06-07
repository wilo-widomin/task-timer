//
//  TimerRowView.swift
//  MenuTimer
//
//  Custom AppKit view used as an `NSMenuItem.view` for each active timer/alarm.
//  Layout: [ title / config ]  …  [ remaining ]  [ 🗑 ]
//  For stopwatches: [ title / config ]  …  [ elapsed ]  [⏸/▶️]  [ 🗑 ]
//
//  An AppKit view (rather than a hosted SwiftUI view) is used deliberately:
//  custom views inside `NSMenu` are far better behaved with AppKit, and we need
//  to mutate just the countdown label every second without rebuilding the menu.
//

import AppKit

/// A single row in the menu's dynamic section.
@MainActor
final class TimerRowView: NSView {

    /// The identity of the item this row represents.
    let itemID: TimerItem.ID

    /// Invoked when the trash button is clicked.
    var onDelete: (() -> Void)?
    /// Invoked when the pause/continue button is clicked (stopwatch only).
    var onTogglePause: (() -> Void)?
    /// Invoked when the user clicks the title text (edit item).
    var onEdit: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton()
    private let deleteButton = NSButton()
    private let textStack = NSStackView()
    private let rowStack = NSStackView()

    private var isStopwatch = false

    private static let rowWidth: CGFloat = 280
    private static let horizontalInset: CGFloat = 14

    /// Creates a row for the given item.
    init(item: TimerItem, now: Date = Date()) {
        self.itemID = item.id
        super.init(frame: NSRect(x: 0, y: 0, width: Self.rowWidth, height: 44))
        setupSubviews(initialState: item.state)
        update(with: item, now: now)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupSubviews(initialState: ItemState) {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        timeLabel.alignment = .right
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Stopwatch action button (pause/continue) — NOT added to any stack
        // yet. It is inserted/removed dynamically in update(with:now:).
        actionButton.bezelStyle = .shadowlessSquare
        actionButton.isBordered = false
        actionButton.imagePosition = .imageOnly
        actionButton.contentTintColor = .secondaryLabelColor
        actionButton.target = self
        actionButton.action = #selector(actionTapped)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.sendAction(on: .leftMouseDown)

        deleteButton.bezelStyle = .shadowlessSquare
        deleteButton.isBordered = false
        deleteButton.imagePosition = .imageOnly
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)
        // Ensure the button is clickable inside NSMenuItem.customView
        deleteButton.sendAction(on: .leftMouseDown)
        // A finished item is "cleared" rather than "deleted"; reflect that in
        // the glyph and tooltip while keeping the click behaviour identical.
        configureDeleteButton(for: initialState)

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.addView(titleLabel, in: .leading)
        textStack.addView(subtitleLabel, in: .leading)

        // Row stack: [textStack, timeLabel, deleteButton]
        // For stopwatches, actionButton is inserted between timeLabel and
        // deleteButton by update(with:now:).
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.setHuggingPriority(.defaultLow, for: .horizontal)
        rowStack.addView(textStack, in: .leading)
        rowStack.addView(timeLabel, in: .trailing)
        rowStack.addView(deleteButton, in: .trailing)
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.rowWidth),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
        ])

        // Pointing-hand cursor over the title label.
        addTrackingArea(NSTrackingArea(
            rect: titleLabel.frame,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    // MARK: - Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove old and recreate so the tracking rect tracks layout changes.
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: titleLabel.frame,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    // MARK: - Updating

    /// Refreshes the row's labels for the given item and reference time.
    /// Called both on initial build and on every tick (time label only changes).
    func update(with item: TimerItem, now: Date) {
        let wasStopwatch = isStopwatch
        isStopwatch = item.kind == .stopwatch

        titleLabel.stringValue = item.title
        subtitleLabel.stringValue = Self.subtitle(for: item)
        configureDeleteButton(for: item.state)

        // Insert actionButton for stopwatches, remove it for timers/alarms.
        // This avoids the NSStackView hidden-view spacing bug where a hidden
        // view's surrounding spacings persist, creating double gaps.
        if isStopwatch, !wasStopwatch {
            // Transitioning to stopwatch: insert after timeLabel.
            let timeIndex = rowStack.arrangedSubviews.firstIndex(of: timeLabel) ?? 0
            rowStack.insertArrangedSubview(actionButton, at: timeIndex + 1)
            configureActionButton(for: item.state)
        } else if !isStopwatch, wasStopwatch {
            // Transitioning back (shouldn't happen in practice, but be safe).
            rowStack.removeArrangedSubview(actionButton)
            actionButton.removeFromSuperview()
        }

        if item.state == .finished {
            timeLabel.stringValue = "Done"
            timeLabel.textColor = .systemGreen
        } else if isStopwatch {
            timeLabel.stringValue = TimeFormatting.elapsed(item.elapsed(at: now))
            timeLabel.textColor = .labelColor
            configureActionButton(for: item.state)
        } else {
            timeLabel.stringValue = TimeFormatting.countdown(item.remaining(at: now))
            timeLabel.textColor = .labelColor
        }
    }

    /// Updates the pause/continue button for the stopwatch state.
    private func configureActionButton(for state: ItemState) {
        let isPaused = state == .paused
        let symbol = isPaused ? "play.fill" : "pause.fill"
        let label = isPaused ? "Continue" : "Pause"
        actionButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        actionButton.toolTip = label
    }

    /// Updates the trailing button's glyph and tooltip for the item's state.
    /// Finished items show a checkmark ("Clear"); running items show a trash
    /// ("Delete"). The click action is identical in both cases.
    private func configureDeleteButton(for state: ItemState) {
        let isFinished = state == .finished
        let symbol = isFinished ? "checkmark.circle" : "trash"
        let label = isFinished ? "Clear" : "Delete"
        deleteButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        deleteButton.toolTip = label
    }

    private static func subtitle(for item: TimerItem) -> String {
        let repeatSuffix: String
        if item.isRepeating {
            repeatSuffix = " · \(TimeFormatting.repeatLabel(item))"
        } else {
            repeatSuffix = ""
        }

        switch item.kind {
        case .timer:
            if let duration = item.configuredDuration {
                return "Timer · \(TimeFormatting.durationLabel(duration))\(repeatSuffix)"
            }
            return "Timer\(repeatSuffix)"
        case .alarm:
            return "Alarm · \(TimeFormatting.alarmLabel(item.fireDate))\(repeatSuffix)"
        case .pomodoro:
            let work = item.configuredDuration ?? 1500
            let phase = item.isBreakPhase ? "Break" : "Work"
            let cycleInfo: String
            if let cycles = item.remainingCycles {
                cycleInfo = " · Cycle \(cycles)"
            } else {
                cycleInfo = ""
            }
            return "\(phase) \(TimeFormatting.durationLabel(work))\(cycleInfo)"
        case .stopwatch:
            return item.state == .paused ? "Stopwatch · Paused" : "Stopwatch"
        }
    }

    // MARK: - Actions

    @objc private func actionTapped() {
        onTogglePause?()
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    // MARK: - Mouse forwarding

    /// Ensure mouse clicks on the buttons work inside NSMenuItem.
    /// Clicks on the title label trigger edit instead.
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Clic en el título → editar item
        if titleLabel.frame.contains(location) {
            onEdit?()
            return
        }

        if !actionButton.isHidden, actionButton.frame.contains(location) {
            actionButton.mouseDown(with: event)
        } else if deleteButton.frame.contains(location) {
            deleteButton.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}