//
//  BlockMenuItem.swift
//  MenuTimer
//
//  An NSMenuItem that runs a closure when selected, removing the need for
//  scattered @objc target/action plumbing.
//

import AppKit

/// An `NSMenuItem` whose selection invokes a stored closure.
@MainActor
final class BlockMenuItem: NSMenuItem {

    private let handler: () -> Void

    /// Creates an item that runs `handler` when chosen.
    /// - Parameters:
    ///   - title: The menu item title.
    ///   - keyEquivalent: Optional key equivalent (default none).
    ///   - handler: Closure run on selection.
    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: keyEquivalent)
        self.target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}
