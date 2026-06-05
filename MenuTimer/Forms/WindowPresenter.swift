//
//  WindowPresenter.swift
//  MenuTimer
//
//  Presents the SwiftUI forms and the About window in lightweight, centered,
//  non-resizable NSWindows hosted via NSHostingController. Each window is a
//  singleton: re-invoking simply brings the existing one forward.
//

import AppKit
import SwiftUI

/// Owns and presents the app's auxiliary windows.
@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {

    private let store: TimerStore

    private var addTimerWindow: NSWindow?
    private var addAlarmWindow: NSWindow?
    private var aboutWindow: NSWindow?

    init(store: TimerStore) {
        self.store = store
    }

    // MARK: - Add Timer

    func showAddTimer() {
        if let existing = addTimerWindow {
            bringToFront(existing)
            return
        }
        let view = AddTimerView(
            onSubmit: { [weak self] duration, title in
                self?.store.addTimer(title: title, duration: duration)
                self?.addTimerWindow?.close()
            },
            onCancel: { [weak self] in self?.addTimerWindow?.close() }
        )
        let window = makeWindow(title: "Add Timer", root: view)
        addTimerWindow = window
        bringToFront(window)
    }

    // MARK: - Add Alarm

    func showAddAlarm() {
        if let existing = addAlarmWindow {
            bringToFront(existing)
            return
        }
        let view = AddAlarmView(
            onSubmit: { [weak self] fireDate, title in
                self?.store.addAlarm(title: title, fireDate: fireDate)
                self?.addAlarmWindow?.close()
            },
            onCancel: { [weak self] in self?.addAlarmWindow?.close() }
        )
        let window = makeWindow(title: "Add Alarm", root: view)
        addAlarmWindow = window
        bringToFront(window)
    }

    // MARK: - About

    func showAbout() {
        if let existing = aboutWindow {
            bringToFront(existing)
            return
        }
        let window = makeWindow(title: "About \(AppInfo.name)", root: AboutView())
        aboutWindow = window
        bringToFront(window)
    }

    // MARK: - Window plumbing

    private func makeWindow<Content: View>(title: String, root: Content) -> NSWindow {
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(hosting.view.fittingSize)
        window.center()
        return window
    }

    private func bringToFront(_ window: NSWindow) {
        // LSUIElement apps are not active by default; activate so the window
        // accepts keyboard focus and comes to the foreground.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === addTimerWindow {
            addTimerWindow = nil
        } else if closing === addAlarmWindow {
            addAlarmWindow = nil
        } else if closing === aboutWindow {
            aboutWindow = nil
        }
    }
}
