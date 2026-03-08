import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    /// Shows the onboarding window if it hasn't been completed yet. No-op otherwise.
    func showIfNeeded() {
        guard !appState.settings.hasCompletedOnboarding else { return }

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        show()
    }
    func show()
    {
        let view = OnboardingView(appState: appState) { [weak self] in
            self?.complete()
        }
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to just ten breaths"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(hostingController.view.fittingSize)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - NSWindowDelegate

    /// Closing via the × button also marks onboarding complete so it doesn't re-appear.
    func windowWillClose(_ notification: Notification) {
        complete()
    }

    // MARK: - Private

    private func complete() {
        appState.settings.hasCompletedOnboarding = true  // auto-saves via settings.didSet
        let w = window
        window = nil      // nil first so windowWillClose re-entry is a no-op
        w?.close()
    }
}
