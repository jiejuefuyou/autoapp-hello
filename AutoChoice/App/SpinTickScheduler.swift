import SwiftUI
import AudioToolbox
import QuartzCore

/// CADisplayLink-based tick scheduler for the 3.5-second spin animation.
/// Produces an accelerating-then-decelerating tick cadence (80 ms → 300 ms)
/// that mirrors the spring-damping wheel animation so the audio sequence
/// feels coupled to the visual deceleration.
///
/// Swift 6 concurrency note: CADisplayLink callbacks arrive on the main run
/// loop, but the @objc selector context is nonisolated. We bridge via
/// Task { @MainActor in … } so `handleTick` stays purely MainActor-isolated
/// without requiring `nonisolated(unsafe)` or `MainActor.assumeIsolated`.
@MainActor
final class SpinTickScheduler {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var lastTickTime: CFTimeInterval = 0
    private let duration: Double = 3.5
    private let onTick: () -> Void
    private let onComplete: () -> Void

    init(onTick: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.onTick = onTick
        self.onComplete = onComplete
    }

    func start() {
        stop()
        startTime = CACurrentMediaTime()
        lastTickTime = startTime
        let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc nonisolated private func displayLinkFired() {
        Task { @MainActor [weak self] in
            self?.handleTick()
        }
    }

    private func handleTick() {
        let now = CACurrentMediaTime()
        let elapsed = now - startTime
        guard elapsed < duration else {
            stop()
            onComplete()
            return
        }
        // Tick interval: 80 ms at start, 300 ms at end (ease-out deceleration
        // matches the spring(response:3.5, dampingFraction:0.85) wheel animation).
        let progress = elapsed / duration
        let interval = 0.08 + (0.30 - 0.08) * progress * progress
        if (now - lastTickTime) >= interval {
            lastTickTime = now
            onTick()
        }
    }
}
