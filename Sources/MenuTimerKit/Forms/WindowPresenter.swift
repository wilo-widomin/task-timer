import AppKit
import SwiftUI

/// Owns and presents auxiliary SwiftUI windows for MenuTimer forms.
///
/// Each caller identifies its window with a stable string id. Re-presenting the
/// same id brings the existing window to the front instead of creating a new
/// one. Windows are retained by this presenter for the entirety of their visible
/// lifetime, and released only after `windowWillClose` fires.
///
/// This retention discipline is load-bearing: presenting an `NSWindow` from a
/// SwiftUI view without a strong owner, while `isReleasedWhenClosed` is at its
/// default of `true`, leads to crashes in `_NSWindowTransformAnimation dealloc`
/// during CoreAnimation commits.
@MainActor
public final class WindowPresenter: NSObject, NSWindowDelegate {

    private var windows: [String: NSWindow] = [:]

    public override init() {
        super.init()
    }

    /// Presents (or brings to front) a window identified by `id`.
    /// - Parameters:
    ///   - id: Stable identifier used for singleton behaviour.
    ///   - title: Window title.
    ///   - root: SwiftUI root view.
    public func present<Content: View>(id: String, title: String, root: Content) {
        if let existing = windows[id] {
            bringToFront(existing)
            return
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.setContentSize(hosting.view.fittingSize)
        window.center()
        windows[id] = window
        bringToFront(window)
    }

    /// Closes the window identified by `id`, if present.
    public func close(id: String) {
        windows[id]?.close()
    }

    /// Closes every currently open window presented by this instance.
    public func closeAll() {
        for window in windows.values {
            window.close()
        }
    }

    private func bringToFront(_ window: NSWindow) {
        // LSUIElement apps are not active by default; activate so the window
        // accepts keyboard focus and comes to the foreground.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              let id = closing.identifier?.rawValue else { return }
        windows.removeValue(forKey: id)
    }
}
