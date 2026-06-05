//
//  AppDelegate.swift
//  MenuTimer
//
//  Phase 0 bootstrap: stand up an NSStatusItem with a minimal menu so the app
//  launches and lives in the menu bar. This file is expanded in later phases to
//  wire up the store, tick engine, notifications and reconciliation.
//

import AppKit

/// Application delegate for the MenuTimer agent app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
    }

    // MARK: - Phase 0 menu-bar bootstrap

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Menu Timer")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Menu Timer", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Menu Timer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu

        statusItem = item
    }
}
