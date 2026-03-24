import AppKit
import SwiftUI

@MainActor
final class BreathingWindowController {
    private var panel: NSPanel?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var isDismissing = false
    private var isFullscreen = false
    /// Saved frame to restore when exiting fullscreen.
    private var popoverFrame: NSRect?

    /// Called after the window finishes dismissing (fade-out complete).
    var onDismiss: (() -> Void)?

    /// Called when the user taps "Done breathing". Receives the session start date
    /// so the caller can compute duration for HealthKit logging.
    var onSessionDone: ((Date) -> Void)?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Show

    func show(below statusItemButton: NSStatusBarButton?, cadence: Double, appearanceStyle: BreathingSettings.AppearanceStyle = .dark, isFullscreen: Bool = false, onCadenceChanged: ((Double) -> Void)? = nil, onFullscreenChanged: ((Bool) -> Void)? = nil) {
        // Clean up any leftover panel (creates fresh animation each time)
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }
        removeMonitors()
        isDismissing = false

        // Build the SwiftUI view with a fresh start time
        let sessionStart = Date()
        let breathingView = BreathingSessionView(startDate: sessionStart, cadence: cadence, isFullscreen: isFullscreen, onDone: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onSessionDone?(sessionStart)
                self.dismiss()
            }
        }, onCadenceChanged: onCadenceChanged, onToggleFullscreen: { [weak self] fullscreen in
            Task { @MainActor [weak self] in
                self?.setFullscreen(fullscreen)
                onFullscreenChanged?(fullscreen)
            }
        })
        let hostingView = NSHostingView(rootView: breathingView)
        let size = hostingView.fittingSize

        // Create the panel
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .transient]
        let appearanceName: NSAppearance.Name = {
            switch appearanceStyle {
            case .dark:
                return .darkAqua
            case .light:
                return .aqua
            case .system:
                let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? .darkAqua : .aqua
            case .inverseSystem:
                let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark ? .aqua : .darkAqua
            }
        }()
        panel.appearance = NSAppearance(named: appearanceName)

        // Calculate final position below the status item, centered horizontally
        var finalOrigin: NSPoint
        if let buttonWindow = statusItemButton?.window {
            let buttonFrame = buttonWindow.frame
            let x = buttonFrame.midX - size.width / 2
            let y = buttonFrame.minY - size.height - 2
            finalOrigin = NSPoint(x: x, y: y)
        } else if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.midX - size.width / 2
            let y = visibleFrame.maxY - size.height - 8
            finalOrigin = NSPoint(x: x, y: y)
        } else {
            finalOrigin = .zero
        }

        self.panel = panel

        if isFullscreen {
            // Open directly in fullscreen — no popover animation
            popoverFrame = NSRect(origin: finalOrigin, size: size)
            guard let screen = panel.screen ?? NSScreen.main else { return }
            panel.setFrame(screen.frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            self.isFullscreen = true

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.3
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            NSAnimationContext.endGrouping()
        } else {
            // Start above final position, transparent -- then slide down and fade in
            panel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y + 8))
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.3
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.animator().setFrameOrigin(finalOrigin)
            NSAnimationContext.endGrouping()
        }

        // Click outside → dismiss (skip in fullscreen)
        if !isFullscreen {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }
        }

        // Escape key → dismiss
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
                return nil
            }
            return event
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        guard !isDismissing, let panel, panel.isVisible else { return }
        isDismissing = true

        removeMonitors()

        // Slide up and fade out
        var dismissOrigin = panel.frame.origin
        dismissOrigin.y += 6

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.2
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeIn)
        NSAnimationContext.current.completionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishDismiss()
            }
        }
        panel.animator().alphaValue = 0
        panel.animator().setFrameOrigin(dismissOrigin)
        NSAnimationContext.endGrouping()
    }

    // MARK: - Fullscreen

    private func setFullscreen(_ fullscreen: Bool) {
        guard let panel, fullscreen != isFullscreen else { return }
        isFullscreen = fullscreen

        if fullscreen {
            popoverFrame = panel.frame

            // Remove click-outside monitor — fullscreen shouldn't dismiss on stray clicks
            if let monitor = globalClickMonitor {
                NSEvent.removeMonitor(monitor)
                globalClickMonitor = nil
            }

            guard let screen = panel.screen ?? NSScreen.main else { return }
            let screenFrame = screen.frame

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.35
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(screenFrame, display: true)
            NSAnimationContext.endGrouping()
        } else {
            guard let savedFrame = popoverFrame else { return }

            // Restore click-outside monitor
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.dismiss()
                }
            }

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.35
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(savedFrame, display: true)
            NSAnimationContext.endGrouping()
        }
    }

    // MARK: - Private

    private func finishDismiss() {
        panel?.orderOut(nil)
        panel = nil
        isDismissing = false
        isFullscreen = false
        popoverFrame = nil
        onDismiss?()
    }

    private func removeMonitors() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
