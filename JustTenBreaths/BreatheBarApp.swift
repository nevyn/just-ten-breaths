import SwiftUI
import SwiftData
import Sparkle

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
    let appState: AppState
    private var statusItemController: StatusItemController?
    private var onboardingWindowController: OnboardingWindowController?
    /// Sparkle auto-updater; checks the appcast on its default schedule from launch.
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    override init() {
        // SwiftData container for breathing-session history. Failure here is unrecoverable
        // (no disk, schema mismatch we can't migrate, etc.) — fail fast per the project's rules.
        let container: ModelContainer
        do {
            container = try ModelContainer(for: BreathingSession.self)
        } catch {
            fatalError("Failed to set up ModelContainer for BreathingSession: \(error)")
        }
        self.appState = AppState(modelContainer: container)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let onboarding = OnboardingWindowController(appState: appState)
        onboardingWindowController = onboarding
        statusItemController = StatusItemController(appState: appState, onboardingWindowController: onboarding, updaterController: updaterController)
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
