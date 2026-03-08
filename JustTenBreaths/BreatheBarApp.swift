import SwiftUI

@main
struct BreatheBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes. This is a menu-bar-only app; the status item
        // and settings window are managed directly via AppKit.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?
    private var onboardingWindowController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let onboarding = OnboardingWindowController(appState: appState)
        onboardingWindowController = onboarding
        statusItemController = StatusItemController(appState: appState, onboardingWindowController: onboarding)
        onboarding.showIfNeeded()
        setupObservation()
    }

    private func setupObservation() {
        withObservationTracking {
            _ = appState.isBreathingTime
            _ = appState.isPrimed
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.statusItemController?.update()
                self?.setupObservation()
            }
        }
    }
}
