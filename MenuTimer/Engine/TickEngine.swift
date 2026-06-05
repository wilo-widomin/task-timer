//
//  TickEngine.swift
//  MenuTimer
//
//  A single 1 Hz heartbeat for the whole app. Rather than one timer per item,
//  one repeating timer fires every second and the handler refreshes everything.
//  This keeps CPU/energy use minimal and state coherent.
//

import Foundation

/// Drives the app's once-per-second update.
@MainActor
public final class TickEngine {

    /// Handler invoked on each tick with the current time.
    public typealias TickHandler = (Date) -> Void

    private var timer: Timer?
    private let interval: TimeInterval
    private let tolerance: TimeInterval
    private let handler: TickHandler

    /// Creates a tick engine.
    /// - Parameters:
    ///   - interval: Seconds between ticks (default `1`).
    ///   - tolerance: Allowed timer slack to save energy (default `0.1`).
    ///   - handler: Called on every tick.
    public init(
        interval: TimeInterval = 1.0,
        tolerance: TimeInterval = 0.1,
        handler: @escaping TickHandler
    ) {
        self.interval = interval
        self.tolerance = tolerance
        self.handler = handler
    }

    /// Whether the engine is currently scheduled.
    public var isRunning: Bool { timer != nil }

    /// Starts ticking. Fires once immediately so UI reflects the present state
    /// without waiting a full interval. No-op if already running.
    public func start() {
        guard timer == nil else { return }

        handler(Date())

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // Timer callbacks are delivered on the main run loop; hop back onto
            // the main actor to satisfy isolation.
            MainActor.assumeIsolated {
                self?.handler(Date())
            }
        }
        timer.tolerance = tolerance
        // Add in `.common` modes so the timer keeps firing while a menu is being
        // tracked (menu tracking runs the run loop in event-tracking mode).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops ticking. No-op if not running.
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
