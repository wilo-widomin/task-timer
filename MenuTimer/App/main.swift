//
//  main.swift
//  MenuTimer
//
//  Programmatic entry point for the menu-bar agent app.
//
//  We use an explicit `main.swift` instead of `@main` because MenuTimer is an
//  AppKit-driven agent (no Dock icon, no main window). This gives us full
//  control over the `NSApplication` lifecycle and activation policy before the
//  delegate takes over.
//

import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate

// Reinforce LSUIElement=YES at runtime: run as an accessory (menu-bar) app with
// no Dock presence and no application menu in the menu bar.
application.setActivationPolicy(.accessory)

application.run()
